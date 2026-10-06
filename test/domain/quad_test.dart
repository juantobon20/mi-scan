import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/quad.dart';

void main() {
  group('Quad.ordered', () {
    test('sorts unordered corners into TL, TR, BR, BL', () {
      final q = Quad.ordered(const [Point(10, 10), Point(0, 10), Point(10, 0), Point(0, 0)]);
      expect(q.points, const [Point(0.0, 0.0), Point(10.0, 0.0), Point(10.0, 10.0), Point(0.0, 10.0)]);
    });

    test('works with a perspective quadrilateral', () {
      final q = Quad.ordered(const [Point(90, 95), Point(10, 5), Point(95, 10), Point(5, 90)]);
      expect(q.points.first, const Point(10.0, 5.0));
      expect(q.points[1], const Point(95.0, 10.0));
      expect(q.points[2], const Point(90.0, 95.0));
      expect(q.points[3], const Point(5.0, 90.0));
    });
  });

  group('serialization', () {
    test('toFlat/fromFlat round-trips', () {
      final q = Quad.inset(0.1);
      expect(Quad.fromFlat(q.toFlat()), q);
      expect(q.toFlat(), hasLength(8));
    });

    test('inset leaves the given margin', () {
      expect(Quad.inset(0.04).points[2], const Point(0.96, 0.96));
    });

    test('points is immutable', () {
      expect(() => Quad.inset(0.1).points.add(const Point(0, 0)), throwsUnsupportedError);
    });
  });

  group('smoothedTo', () {
    final a = Quad.inset(0.1);

    test('interpolates when movement is small', () {
      final b = Quad.inset(0.12);
      final s = a.smoothedTo(b);
      expect(s.points.first.x, closeTo(0.11, 1e-9));
    });

    test('adopts the new quad when it jumps more than maxJump', () {
      final far = Quad.inset(0.4);
      expect(a.smoothedTo(far), far);
    });

    test('factor 1 is the same as adopting the new one', () {
      final b = Quad.inset(0.12);
      expect(a.smoothedTo(b, factor: 1), b);
    });
  });

  group('isConvexQuad', () {
    test('rectangle is convex', () {
      expect(isConvexQuad(const [Point(0, 0), Point(4, 0), Point(4, 3), Point(0, 3)]), isTrue);
    });

    test('bow-tie shape (self-intersecting) is not convex', () {
      expect(isConvexQuad(const [Point(0, 0), Point(4, 3), Point(4, 0), Point(0, 3)]), isFalse);
    });

    test('concave shape is not convex', () {
      expect(isConvexQuad(const [Point(0, 0), Point(4, 0), Point(1, 1), Point(0, 4)]), isFalse);
    });

    test('collinear points are not convex', () {
      expect(isConvexQuad(const [Point(0, 0), Point(1, 0), Point(2, 0), Point(3, 0)]), isFalse);
    });

    test('rejects lists that do not have 4 points', () {
      expect(isConvexQuad(const [Point(0, 0), Point(1, 1)]), isFalse);
    });
  });
}
