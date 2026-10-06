import 'dart:typed_data';

import '../../domain/entities/scan_page.dart';

GrayFrame downsampleToGray({
  required Uint8List data,
  required int width,
  required int height,
  required int bytesPerRow,
  required bool bgra,
  required int rotation,
  int targetWidth = 320,
}) {
  final step = (width / targetWidth).ceil().clamp(1, 8);
  final w = width ~/ step, h = height ~/ step;
  final bpp = bgra ? 4 : 1;
  final gray = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final row = y * step * bytesPerRow;
    for (var x = 0; x < w; x++) {
      final i = row + x * step * bpp;
      gray[y * w + x] = bgra ? ((data[i] + 2 * data[i + 1] + data[i + 2]) >> 2) : data[i];
    }
  }
  return GrayFrame(gray, w, h, rotation);
}
