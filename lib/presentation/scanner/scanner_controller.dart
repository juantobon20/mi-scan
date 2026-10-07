import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/camera_info.dart';
import '../../domain/entities/quad.dart';
import '../../domain/entities/scan_page.dart';
import '../../domain/services/camera_service.dart';
import 'scan_session.dart';

enum ScanMode { single, batch }

const double ultraWideFactor = 0.5;
const double telephotoFactor = 2.0;

class ScannerController extends ChangeNotifier {
  ScannerController({required this._cameraService, required this._session});

  final CameraService _cameraService;
  final ScanSession _session;

  List<CameraInfo> _cameras = const [];
  CameraInfo? _main;
  CameraInfo? _ultraWide;
  CameraInfo? _telephoto;
  CameraInfo? _selected;
  CameraSession? _camera;
  ZoomRange _mainRange = const ZoomRange(1, 1);
  bool _virtualLenses = false;
  Future<void> _queue = Future<void>.value();
  bool _zoomApplyScheduled = false;
  StreamSubscription<GrayFrame>? _frameSubscription;
  CameraAccessException? _problem;
  Quad? _quad;
  double _zoom = 1;
  FlashSetting _flash = FlashSetting.off;
  bool _torch = false;
  bool _capturing = false;
  bool _detecting = false;
  bool _disposed = false;
  int _misses = 0;
  ScanMode _mode = ScanMode.single;

  List<CameraInfo> get cameras => List.unmodifiable(_cameras);
  CameraInfo? get selectedCamera => _selected;
  bool get usesVirtualLenses => _virtualLenses;
  CameraSession? get camera => _camera;
  CameraAccessException? get problem => _problem;
  Quad? get quad => _quad;
  double get zoom => _zoom;
  FlashSetting get flash => _flash;
  bool get torch => _torch;
  bool get capturing => _capturing;
  ScanMode get mode => _mode;
  bool get isReady => _camera != null && _problem == null;
  ZoomRange get zoomRange {
    if (!_virtualLenses) return _camera?.zoomRange ?? _mainRange;
    return ZoomRange(_ultraWide == null ? _mainRange.min : ultraWideFactor, _mainRange.max);
  }

  Future<void> _serial(Future<void> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> initialize() => _serial(_initialize);

  Future<void> _initialize() async {
    try {
      _cameras = await _cameraService.listCameras();
    } on CameraAccessException catch (e) {
      _fail(e);
      return;
    } catch (e) {
      _fail(CameraAccessException(CameraFailure.failed, '$e'));
      return;
    }
    if (_cameras.isEmpty) {
      _fail(const CameraAccessException(CameraFailure.unavailable));
      return;
    }
    await _openMain();
  }

  Future<void> _openMain() async {
    final back = _cameras.where((c) => c.facing == CameraFacing.back).toList();
    final usable = back.isEmpty ? [_cameras.first] : back;
    final main = usable.firstWhere((c) => c.lens == CameraLens.wide, orElse: () => usable.first);
    _main = main;
    _ultraWide = usable.where((c) => c.lens == CameraLens.ultraWide && c != main).firstOrNull;
    _telephoto = usable.where((c) => c.lens == CameraLens.telephoto && c != main).firstOrNull;
    _virtualLenses = false;
    _zoom = 1;
    await _open(main, zoom: 1);
    if (_camera == null) return;
    _mainRange = _camera!.zoomRange;
    _virtualLenses = _mainRange.min >= 1 && (_ultraWide != null || _telephoto != null);
    _notify();
  }

  Future<void> _open(CameraInfo info, {required double zoom}) async {
    await _release();
    _selected = info;
    _problem = null;
    _quad = null;
    _notify();
    try {
      final opened = await _cameraService.open(info);
      if (_disposed) {
        await opened.dispose();
        return;
      }
      _camera = opened;
      await opened.setZoom(opened.zoomRange.clamp(zoom / _factorOf(info)));
      await opened.setFlash(_flash);
      await opened.setTorch(_torch);
      _frameSubscription = opened.frames.listen(_onFrame);
      await opened.startFrames();
    } on CameraAccessException catch (e) {
      _fail(e);
      return;
    } catch (e) {
      _fail(CameraAccessException(CameraFailure.failed, '$e'));
      return;
    }
    _notify();
  }

  double _factorOf(CameraInfo info) {
    if (!_virtualLenses) return 1;
    if (info == _ultraWide) return ultraWideFactor;
    if (info == _telephoto) return telephotoFactor;
    return 1;
  }

  CameraInfo _lensFor(double zoom) {
    final main = _main!;
    if (!_virtualLenses) return main;
    final current = _selected;
    final ultra = _ultraWide;
    if (ultra != null && (zoom < 0.95 || (current == ultra && zoom < 1.0))) return ultra;
    final tele = _telephoto;
    if (tele != null && (zoom >= telephotoFactor || (current == tele && zoom >= telephotoFactor - 0.1))) return tele;
    return main;
  }

  Future<void> _release() async {
    unawaited(_frameSubscription?.cancel());
    _frameSubscription = null;
    final camera = _camera;
    _camera = null;
    _detecting = false;
    if (camera != null) {
      try {
        await camera.dispose();
      } catch (_) {}
    }
  }

  void _fail(CameraAccessException problem) {
    _problem = problem;
    _camera = null;
    _notify();
  }

  void _onFrame(GrayFrame frame) {
    if (_detecting || _capturing) return;
    _detecting = true;
    _session.detectLive(frame).then((detected) {
      _detecting = false;
      if (_disposed) return;
      if (detected != null) {
        _misses = 0;
        final previous = _quad;
        _quad = previous == null ? detected : previous.smoothedTo(detected);
        _notify();
      } else if (++_misses > 3 && _quad != null) {
        _quad = null;
        _notify();
      }
    }).catchError((Object _) {
      _detecting = false;
    });
  }

  Future<void> setZoom(double zoom) async {
    if (_main == null) return;
    final clamped = zoomRange.clamp(zoom);
    if (clamped == _zoom) return;
    _zoom = clamped;
    _notify();
    if (_zoomApplyScheduled) return;
    _zoomApplyScheduled = true;
    await _serial(() async {
      _zoomApplyScheduled = false;
      await _applyZoom();
    });
  }

  Future<void> _applyZoom() async {
    if (_camera == null) return;
    while (true) {
      final wanted = _lensFor(_zoom);
      if (wanted == _selected) break;
      await _open(wanted, zoom: _zoom);
      if (_camera == null) return;
    }
    final camera = _camera;
    if (camera == null) return;
    await camera.setZoom(camera.zoomRange.clamp(_zoom / _factorOf(_selected!)));
  }

  Future<void> cycleFlash() async {
    _flash = switch (_flash) {
      FlashSetting.off => FlashSetting.auto,
      FlashSetting.auto => FlashSetting.always,
      FlashSetting.always => FlashSetting.off,
    };
    _notify();
    await _camera?.setFlash(_flash);
  }

  Future<void> toggleTorch() async {
    _torch = !_torch;
    _notify();
    await _camera?.setTorch(_torch);
  }

  void setMode(ScanMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _notify();
  }

  Future<String> capture() async {
    final camera = _camera;
    if (camera == null || _capturing) throw StateError('The camera is not ready');
    _capturing = true;
    _notify();
    try {
      await camera.stopFrames();
      return await camera.takePicture();
    } catch (_) {
      await finishCapture();
      rethrow;
    }
  }

  Future<void> finishCapture() async {
    _capturing = false;
    _quad = null;
    _notify();
    try {
      await _camera?.startFrames();
    } catch (_) {}
  }

  Future<void> pauseFrames() async {
    try {
      await _camera?.stopFrames();
    } catch (_) {}
  }

  Future<void> resumeFrames() async {
    try {
      await _camera?.startFrames();
    } catch (_) {}
  }

  Future<void> suspend() => _serial(() async {
        await _release();
        _notify();
      });

  Future<void> resume() => _serial(() async {
        final info = _selected;
        if (info == null) return _initialize();
        if (_camera == null) await _open(info, zoom: _zoom);
      });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_release());
    super.dispose();
  }
}
