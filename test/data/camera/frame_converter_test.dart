import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/data/services/camera/frame_converter.dart';

void main() {
  test('YUV: copies the subsampled luminance', () {
    final data = Uint8List.fromList([for (var i = 0; i < 640 * 4; i++) i % 256]);
    final f = downsampleToGray(
        data: data, width: 640, height: 4, bytesPerRow: 640, bgra: false, rotation: 90);
    expect((f.width, f.height, f.rotation), (320, 2, 90));
    expect(f.bytes, hasLength(320 * 2));
    expect(f.bytes[1], data[2]);
    expect(f.bytes[320], data[2 * 640]);
  });

  test('BGRA: luma aproximada (B + 2G + R) / 4', () {
    final data = Uint8List.fromList([100, 200, 40, 255, 0, 0, 0, 255]);
    final f = downsampleToGray(
        data: data, width: 2, height: 1, bytesPerRow: 8, bgra: true, rotation: 0);
    expect(f.width, 2);
    expect(f.bytes[0], (100 + 2 * 200 + 40) >> 2);
    expect(f.bytes[1], 0);
  });

  test('honors bytesPerRow with padding at the end of each row', () {
    final data = Uint8List.fromList([10, 20, 99, 99, 30, 40, 99, 99]);
    final f = downsampleToGray(
        data: data, width: 2, height: 2, bytesPerRow: 4, bgra: false, rotation: 0);
    expect(f.bytes, [10, 20, 30, 40]);
  });

  test('large images are limited to a max step of 8', () {
    final f = downsampleToGray(
        data: Uint8List(4000 * 8), width: 4000, height: 8, bytesPerRow: 4000, bgra: false, rotation: 0);
    expect(f.width, 4000 ~/ 8);
  });
}
