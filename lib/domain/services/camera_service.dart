import '../entities/camera_info.dart';
import '../entities/scan_page.dart';

enum CameraFailure { permissionDenied, unavailable, failed }

class CameraAccessException implements Exception {
  const CameraAccessException(this.failure, [this.details]);

  final CameraFailure failure;
  final String? details;

  @override
  String toString() => 'CameraAccessException($failure, $details)';
}

abstract interface class CameraService {
  Future<List<CameraInfo>> listCameras();

  Future<CameraSession> open(CameraInfo camera);
}

abstract interface class CameraSession {
  CameraInfo get info;

  double get previewAspectRatio;

  ZoomRange get zoomRange;

  Stream<GrayFrame> get frames;

  Future<void> startFrames();

  Future<void> stopFrames();

  Future<void> setZoom(double zoom);

  Future<void> setFlash(FlashSetting flash);

  Future<void> setTorch(bool enabled);

  Future<String> takePicture();

  Future<void> dispose();
}
