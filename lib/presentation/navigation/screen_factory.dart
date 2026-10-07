import 'package:flutter/widgets.dart';

import '../../domain/services/camera_service.dart';
import '../gallery/gallery_controller.dart';
import '../scanner/scan_session.dart';
import '../scanner/scanner_controller.dart';

typedef CameraPreviewBuilder = Widget Function(CameraSession session);

class ScreenFactory {
  const ScreenFactory({
    required this.scannerController,
    required this.galleryController,
    required this.previewBuilder,
  });

  final ScannerController Function(ScanSession session) scannerController;
  final GalleryController Function(String directory) galleryController;
  final CameraPreviewBuilder previewBuilder;
}
