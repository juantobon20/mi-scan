import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/camera_info.dart';
import '../../domain/entities/quad.dart';
import '../../domain/entities/scan_page.dart';
import '../../domain/services/camera_service.dart';
import 'scan_session.dart';

enum ScanMode { single, batch }

class ScannerController extends ChangeNotifier {
  ScannerController({required this._cameraService, required this._session});

  final CameraService _cameraService;
  final ScanSession _session;

  List<CameraInfo> _cameras = const [];
  CameraInfo? _selected;
  CameraSession? _camera;
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
  CameraSession? get camera => _camera;
  CameraAccessException? get problem => _problem;
  Quad? get quad => _quad;
  double get zoom => _zoom;
  FlashSetting get flash => _flash;
  bool get torch => _torch;
  bool get capturing => _capturing;
  ScanMode get mode => _mode;
  bool get isReady => _camera != null && _problem == null;
  ZoomRange get zoomRange => _camera?.zoomRange ?? const ZoomRange(1, 1);

  Future<void> initialize() async {
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
    await _open(_defaultCamera());
  }

  CameraInfo _defaultCamera() {
    final back = _cameras.where((c) => c.facing == CameraFacing.back);
    return back.firstWhere((c) => c.lens == CameraLens.wide, orElse: () => back.isEmpty ? _cameras.first : back.first);
  }

  Future<void> selectCamera(CameraInfo camera) async {
    if (camera == _selected && _camera != null) return;
    await _open(camera);
  }

  Future<void> _open(CameraInfo info) async {
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
      _zoom = opened.zoomRange.clamp(1);
      await opened.setZoom(_zoom);
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
    final camera = _camera;
    if (camera == null) return;
    final clamped = camera.zoomRange.clamp(zoom);
    if (clamped == _zoom) return;
    _zoom = clamped;
    _notify();
    await camera.setZoom(clamped);
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

  Future<void> suspend() => _release().then((_) => _notify());

  Future<void> resume() async {
    final info = _selected;
    if (info == null) return initialize();
    if (_camera == null) await _open(info);
  }

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
