import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/quad.dart';
import 'package:mi_scan/presentation/widgets/quad_painter.dart';

void main() {
  final quad = Quad.inset(0.1).offsets;

  test('offsets/toQuad son inversos', () {
    expect(quad.toQuad(), Quad.inset(0.1));
  });

  test('shouldRepaint reacts to quad and mode changes', () {
    final a = QuadPainter(quad);
    expect(a.shouldRepaint(QuadPainter(quad)), isFalse);
    expect(a.shouldRepaint(QuadPainter(Quad.inset(0.2).offsets)), isTrue);
    expect(a.shouldRepaint(QuadPainter(quad, dimOutside: true)), isTrue);
  });

  for (final dim in [false, true]) {
    test('paints without errors (dimOutside=$dim)', () {
      final recorder = PictureRecorder();
      QuadPainter(quad, dimOutside: dim).paint(Canvas(recorder), const Size(100, 200));
      expect(recorder.endRecording, returnsNormally);
    });
  }

  test('paints nothing unless there are 4 points', () {
    final recorder = PictureRecorder();
    QuadPainter(const []).paint(Canvas(recorder), const Size(100, 100));
    recorder.endRecording();
  });
}
