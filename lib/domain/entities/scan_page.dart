import 'dart:typed_data';

class ScanPage {
  const ScanPage(this.path, this.width, this.height);
  final String path;
  final int width;
  final int height;

  bool get isLandscape => width > height;

  ScanPage copyWith({int? width, int? height}) => ScanPage(path, width ?? this.width, height ?? this.height);
}

class ImageSize {
  const ImageSize(this.width, this.height);
  final int width;
  final int height;

  @override
  bool operator ==(Object other) => other is ImageSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

class GrayFrame {
  const GrayFrame(this.bytes, this.width, this.height, this.rotation);
  final Uint8List bytes;
  final int width;
  final int height;

  final int rotation;
}
