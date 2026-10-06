import 'dart:math' as math;

class Quad {
  Quad(List<math.Point<double>> points)
      : assert(points.length == 4, 'Un Quad necesita exactamente 4 puntos'),
        points = List.unmodifiable(points);

  factory Quad.fromFlat(List<double> v) {
    assert(v.length == 8);
    return Quad([for (var i = 0; i < 4; i++) math.Point(v[i * 2], v[i * 2 + 1])]);
  }

  factory Quad.inset(double m) => Quad([
        math.Point(m, m),
        math.Point(1 - m, m),
        math.Point(1 - m, 1 - m),
        math.Point(m, 1 - m),
      ]);

  factory Quad.ordered(List<math.Point<num>> corners) {
    assert(corners.length == 4);
    final pts = [for (final c in corners) math.Point<double>(c.x.toDouble(), c.y.toDouble())]
      ..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    final tl = pts.first, br = pts.last;
    final mid = [pts[1], pts[2]]..sort((a, b) => (a.y - a.x).compareTo(b.y - b.x));
    return Quad([tl, mid.first, br, mid.last]);
  }

  final List<math.Point<double>> points;

  List<double> toFlat() => [for (final p in points) ...[p.x, p.y]];

  Quad smoothedTo(Quad next, {double maxJump = 0.15, double factor = 0.5}) {
    var moved = 0.0;
    for (var i = 0; i < 4; i++) {
      moved = math.max(moved, points[i].distanceTo(next.points[i]));
    }
    if (moved > maxJump) return next;
    return Quad([
      for (var i = 0; i < 4; i++)
        math.Point(
          points[i].x + (next.points[i].x - points[i].x) * factor,
          points[i].y + (next.points[i].y - points[i].y) * factor,
        ),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Quad) return false;
    for (var i = 0; i < 4; i++) {
      if (points[i] != other.points[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(points);
}

bool isConvexQuad(List<math.Point<num>> p) {
  if (p.length != 4) return false;
  var sign = 0;
  for (var i = 0; i < 4; i++) {
    final a = p[i], b = p[(i + 1) % 4], c = p[(i + 2) % 4];
    final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
    if (cross == 0) return false;
    final s = cross > 0 ? 1 : -1;
    if (sign == 0) sign = s;
    if (s != sign) return false;
  }
  return true;
}
