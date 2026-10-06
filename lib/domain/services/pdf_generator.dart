import 'dart:typed_data';

import '../entities/scan_page.dart';

abstract interface class PdfGenerator {
  Future<Uint8List> generate(List<ScanPage> pages);
}

abstract interface class ThumbnailGenerator {
  Future<Uint8List> generate(String imagePath);
}
