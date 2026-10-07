import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/entities/camera_info.dart';
import '../../../domain/entities/scan_page.dart';
import '../../../domain/services/camera_service.dart';
import 'camera_mappers.dart';
import 'frame_converter.dart';

class PluginCameraService implements CameraService {
  PluginCameraService({Future<List<CameraDescription>> Function()? loadCameras, bool? isIOS})
      : _load = loadCameras ?? availableCameras,
        _isIOS = isIOS ?? Platform.isIOS;

  final Future<List<CameraDescription>> Function() _load;
  final bool _isIOS;
  List<CameraDescription> _descriptions = const [];

  @override
  Future<List<CameraInfo>> listCameras() async {
    try {
      _descriptions = await _load();
    } on CameraException catch (e) {
      throw _translate(e);
    }
    return [for (final d in _descriptions) infoFrom(d)];
  }

  @override
  Future<CameraSession> open(CameraInfo camera) async {
    final description = _descriptions.firstWhere(
      (d) => d.name == camera.id,
      orElse: () => throw const CameraAccessException(CameraFailure.unavailable),
    );
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: _isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    try {
      await controller.initialize();
      final min = await controller.getMinZoomLevel();
      final max = await controller.getMaxZoomLevel();
      return PluginCameraSession(controller, camera, ZoomRange(min, max), isIOS: _isIOS);
    } on CameraException catch (e) {
      await controller.dispose();
      throw _translate(e);
    }
  }

  CameraAccessException _translate(CameraException e) => CameraAccessException(
        e.code.contains('Denied') ? CameraFailure.permissionDenied : CameraFailure.failed,
        e.description ?? e.code,
      );
}

class PluginCameraSession implements CameraSession {
  PluginCameraSession(this.controller, this.info, this.zoomRange, {required this.isIOS});

  final CameraController controller;
  final bool isIOS;
  final _frames = StreamController<GrayFrame>.broadcast();
  FlashSetting _flash = FlashSetting.off;
  bool _torch = false;
  int _lastFrameAt = 0;

  @override
  final CameraInfo info;

  @override
  final ZoomRange zoomRange;

  @override
  double get previewAspectRatio => 1 / controller.value.aspectRatio;

  @override
  Stream<GrayFrame> get frames => _frames.stream;

  @override
  Future<void> startFrames() async {
    if (controller.value.isStreamingImages) return;
    await controller.startImageStream(_onImage);
  }

  @override
  Future<void> stopFrames() async {
    if (controller.value.isStreamingImages) await controller.stopImageStream();
  }

  void _onImage(CameraImage image) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFrameAt < 200 || !_frames.hasListener) return;
    _lastFrameAt = now;
    final plane = image.planes[0];
    _frames.add(downsampleToGray(
      data: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      bgra: isIOS,
      rotation: info.sensorOrientation,
    ));
  }

  @override
  Future<void> setZoom(double zoom) => controller.setZoomLevel(zoomRange.clamp(zoom));

  @override
  Future<void> setFlash(FlashSetting flash) {
    _flash = flash;
    return controller.setFlashMode(flashModeFor(_flash, torch: _torch));
  }

  @override
  Future<void> setTorch(bool enabled) {
    _torch = enabled;
    return controller.setFlashMode(flashModeFor(_flash, torch: _torch));
  }

  @override
  Future<String> takePicture() async => (await controller.takePicture()).path;

  @override
  Future<void> dispose() async {
    await _frames.close();
    await controller.dispose();
  }
}

Widget buildCameraPreview(CameraSession session) {
  if (session is PluginCameraSession) return CameraPreview(session.controller);
  return const SizedBox.shrink();
}
