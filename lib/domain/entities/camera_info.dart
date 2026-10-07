enum CameraFacing { back, front, external }

enum CameraLens { wide, ultraWide, telephoto, unknown }

enum FlashSetting { off, auto, always }

class CameraInfo {
  const CameraInfo({
    required this.id,
    required this.facing,
    this.lens = CameraLens.unknown,
    this.sensorOrientation = 90,
  });

  final String id;
  final CameraFacing facing;
  final CameraLens lens;
  final int sensorOrientation;

  @override
  bool operator ==(Object other) =>
      other is CameraInfo &&
      other.id == id &&
      other.facing == facing &&
      other.lens == lens &&
      other.sensorOrientation == sensorOrientation;

  @override
  int get hashCode => Object.hash(id, facing, lens, sensorOrientation);

  @override
  String toString() => 'CameraInfo($id, ${facing.name}, ${lens.name})';
}

class ZoomRange {
  const ZoomRange(this.min, this.max);

  final double min;
  final double max;

  bool get isZoomable => max > min;

  double clamp(double value) => value.clamp(min, max).toDouble();
}
