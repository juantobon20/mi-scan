import 'dart:typed_data';

import '../entities/gallery_image.dart';

abstract interface class GalleryService {
  Future<GalleryAccess> requestAccess();

  Future<List<GalleryImage>> loadPage({required int page, required int size});

  Future<Uint8List?> thumbnail(GalleryImage image, {required int size});

  Future<bool> exportJpeg(GalleryImage image, String destinationPath);

  Future<void> openSettings();
}
