import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/quad.dart';

extension QuadOffsets on Quad {
  List<Offset> get offsets => [for (final p in points) Offset(p.x, p.y)];
}

extension OffsetsToQuad on List<Offset> {
  Quad toQuad() => Quad.fromFlat([for (final o in this) ...[o.dx, o.dy]]);
}

class QuadPainter extends CustomPainter {
  QuadPainter(this.quad, {this.dimOutside = false, this.fill = true});
  final List<Offset> quad;
  final bool dimOutside;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (quad.length != 4) return;
    final pts = [for (final q in quad) Offset(q.dx * size.width, q.dy * size.height)];
    final path = Path()..addPolygon(pts, true);
    if (dimOutside) {
      final outer = Path()..addRect(Offset.zero & size);
      canvas.drawPath(
        Path.combine(PathOperation.difference, outer, path),
        Paint()..color = Colors.black54,
      );
    } else if (fill) {
      canvas.drawPath(path, Paint()..color = kScanColor.withValues(alpha: 0.18));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = kScanColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(QuadPainter old) => old.quad != quad || old.dimOutside != dimOutside;
}
