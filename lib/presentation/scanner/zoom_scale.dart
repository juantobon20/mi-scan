import 'dart:math' as math;

import '../../domain/entities/camera_info.dart';

double zoomToSliderValue(double zoom, ZoomRange range) {
  if (!range.isZoomable || range.min <= 0) return 0;
  return (math.log(zoom / range.min) / math.log(range.max / range.min)).clamp(0.0, 1.0);
}

double sliderValueToZoom(double value, ZoomRange range) {
  if (!range.isZoomable || range.min <= 0) return range.min;
  return range.min * math.pow(range.max / range.min, value.clamp(0.0, 1.0)).toDouble();
}
