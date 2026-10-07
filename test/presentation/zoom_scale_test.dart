import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/camera_info.dart';
import 'package:mi_scan/presentation/scanner/zoom_scale.dart';

void main() {
  const range = ZoomRange(0.6, 10);

  test('the slider ends map to the ends of the zoom range', () {
    expect(sliderValueToZoom(0, range), closeTo(0.6, 1e-9));
    expect(sliderValueToZoom(1, range), closeTo(10, 1e-9));
    expect(zoomToSliderValue(0.6, range), closeTo(0, 1e-9));
    expect(zoomToSliderValue(10, range), closeTo(1, 1e-9));
  });

  test('the scale is logarithmic: equal slider steps multiply the zoom by the same factor', () {
    final a = sliderValueToZoom(0.25, range) / sliderValueToZoom(0, range);
    final b = sliderValueToZoom(0.5, range) / sliderValueToZoom(0.25, range);
    final c = sliderValueToZoom(0.75, range) / sliderValueToZoom(0.5, range);
    expect(b, closeTo(a, 1e-9));
    expect(c, closeTo(a, 1e-9));
  });

  test('1x sits near the lower end instead of being squeezed against it', () {
    final t = zoomToSliderValue(1, range);
    expect(t, closeTo(0.181, 0.001));
    expect(t, greaterThan((1 - 0.6) / (10 - 0.6)));
  });

  test('zoom and slider value are inverse of each other', () {
    for (final zoom in [0.6, 0.8, 1, 2, 3.5, 7, 10]) {
      expect(sliderValueToZoom(zoomToSliderValue(zoom.toDouble(), range), range), closeTo(zoom, 1e-9));
    }
  });

  test('values outside the range are clamped', () {
    expect(zoomToSliderValue(50, range), 1);
    expect(zoomToSliderValue(0.1, range), 0);
    expect(sliderValueToZoom(2, range), closeTo(10, 1e-9));
    expect(sliderValueToZoom(-1, range), closeTo(0.6, 1e-9));
  });

  test('a camera that cannot zoom maps everything to its minimum', () {
    const fixed = ZoomRange(1, 1);
    expect(zoomToSliderValue(1, fixed), 0);
    expect(sliderValueToZoom(0.7, fixed), 1);
  });
}
