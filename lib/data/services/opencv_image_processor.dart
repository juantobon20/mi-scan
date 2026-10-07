import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../domain/entities/quad.dart';
import '../../domain/entities/scan_filter.dart';
import '../../domain/entities/scan_page.dart';
import '../../domain/services/image_processor.dart';

class OpenCvImageProcessor implements ImageProcessor {
  @override
  Future<Quad?> detectInFrame(GrayFrame f) async {
    final flat = await compute(_detectLive, <Object>[f.bytes, f.width, f.height, f.rotation]);
    return flat == null ? null : Quad.fromFlat(flat);
  }

  @override
  Future<Quad?> detectInFile(String path) async {
    final flat = await compute(_detectFile, path);
    return flat == null ? null : Quad.fromFlat(flat);
  }

  @override
  Future<ImageSize> normalize(String src, String dst) async {
    final s = await compute(_normalize, [src, dst]);
    return ImageSize(s[0], s[1]);
  }

  @override
  Future<void> crop(String src, String dst, Quad quad, ScanFilter filter) =>
      compute(_crop, {'src': src, 'dst': dst, 'quad': quad.toFlat(), 'filter': filter.index});

  @override
  Future<void> applyFilter(String src, String dst, ScanFilter filter, {int maxSide = 1600}) =>
      compute(_preview, {'src': src, 'dst': dst, 'filter': filter.index, 'maxSide': maxSide});

  @override
  Future<ImageSize> rotate(String path) async {
    final s = await compute(_rotate, path);
    return ImageSize(s[0], s[1]);
  }
}

List<double>? _findQuad(cv.Mat gray) {
  final scale = 400 / math.max(gray.cols, gray.rows);
  final small = scale < 1 ? cv.resize(gray, ((gray.cols * scale).round(), (gray.rows * scale).round())) : gray;
  final blur = cv.gaussianBlur(small, (5, 5), 0);
  final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
  final total = small.cols * small.rows;
  Quad? best;
  var bestArea = 0.0;

  for (final t in const [(50.0, 150.0), (20.0, 70.0)]) {
    final edges = cv.canny(blur, t.$1, t.$2);
    final dilated = cv.dilate(edges, kernel);
    final (contours, _) = cv.findContours(dilated, cv.RETR_LIST, cv.CHAIN_APPROX_SIMPLE);
    for (var i = 0; i < contours.length; i++) {
      final c = contours[i];
      final area = cv.contourArea(c);
      if (area < total * 0.12 || area > total * 0.97 || area <= bestArea) continue;
      final approx = cv.approxPolyDP(c, 0.02 * cv.arcLength(c, true), true);
      if (approx.length != 4) continue;
      final pts = [for (var k = 0; k < 4; k++) math.Point(approx[k].x, approx[k].y)];
      if (!isConvexQuad(pts)) continue;
      bestArea = area;
      best = Quad.ordered([
        for (final p in pts) math.Point(p.x / small.cols, p.y / small.rows),
      ]);
    }
    edges.dispose();
    dilated.dispose();
    if (best != null) break;
  }
  blur.dispose();
  kernel.dispose();
  if (!identical(small, gray)) small.dispose();
  return best?.toFlat();
}

List<double>? _detectLive(List<Object> msg) {
  final bytes = msg[0] as Uint8List;
  final w = msg[1] as int, h = msg[2] as int, rot = msg[3] as int;
  var mat = cv.Mat.fromList(h, w, cv.MatType.CV_8UC1, bytes);
  final code = switch (rot) {
    90 => cv.ROTATE_90_CLOCKWISE,
    180 => cv.ROTATE_180,
    270 => cv.ROTATE_90_COUNTERCLOCKWISE,
    _ => null,
  };
  if (code != null) {
    final r = cv.rotate(mat, code);
    mat.dispose();
    mat = r;
  }
  try {
    return _findQuad(mat);
  } finally {
    mat.dispose();
  }
}

List<double>? _detectFile(String path) {
  final gray = cv.imread(path, flags: cv.IMREAD_GRAYSCALE);
  try {
    return gray.isEmpty ? null : _findQuad(gray);
  } finally {
    gray.dispose();
  }
}

List<int> _normalize(List<String> a) {
  var img = cv.imread(a[0]);
  final m = math.max(img.cols, img.rows);
  if (m > 3000) {
    final s = 3000 / m;
    final r = cv.resize(img, ((img.cols * s).round(), (img.rows * s).round()), interpolation: cv.INTER_AREA);
    img.dispose();
    img = r;
  }
  _write(a[1], img);
  final size = [img.cols, img.rows];
  img.dispose();
  return size;
}

void _write(String path, cv.Mat img) {
  cv.imwrite(path, img, params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 88]));
}

cv.Mat _filtered(cv.Mat input, ScanFilter filter, {double scale = 1}) {
  switch (filter) {
    case ScanFilter.original:
      return input;
    case ScanFilter.enhanced:
      final out = cv.convertScaleAbs(input, alpha: 1.25, beta: 12);
      input.dispose();
      return out;
    case ScanFilter.grayscale:
      final out = cv.cvtColor(input, cv.COLOR_BGR2GRAY);
      input.dispose();
      return out;
    case ScanFilter.blackAndWhite:
      final gray = cv.cvtColor(input, cv.COLOR_BGR2GRAY);
      input.dispose();
      var block = (31 * scale).round();
      if (block.isEven) block++;
      final out = cv.adaptiveThreshold(
        gray,
        255,
        cv.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv.THRESH_BINARY,
        math.max(block, 3),
        15,
      );
      gray.dispose();
      return out;
  }
}

void _preview(Map<String, Object> a) {
  var img = cv.imread(a['src'] as String);
  final maxSide = a['maxSide'] as int;
  final longest = math.max(img.cols, img.rows);
  var scale = 1.0;
  if (longest > maxSide) {
    scale = maxSide / longest;
    final resized = cv.resize(img, ((img.cols * scale).round(), (img.rows * scale).round()), interpolation: cv.INTER_AREA);
    img.dispose();
    img = resized;
  }
  final out = _filtered(img, ScanFilter.values[a['filter'] as int], scale: scale);
  _write(a['dst'] as String, out);
  out.dispose();
}

void _crop(Map<String, Object> a) {
  final img = cv.imread(a['src'] as String);
  final q = a['quad'] as List<double>;
  final p = [
    for (var i = 0; i < 4; i++) [q[i * 2] * img.cols, q[i * 2 + 1] * img.rows],
  ];
  double d(List<double> u, List<double> v) => math.sqrt(math.pow(u[0] - v[0], 2) + math.pow(u[1] - v[1], 2));
  final w = math.max(d(p[0], p[1]), d(p[3], p[2])).round().clamp(32, 4000);
  final h = math.max(d(p[0], p[3]), d(p[1], p[2])).round().clamp(32, 4000);

  final srcPts = cv.VecPoint.fromList([for (final v in p) cv.Point(v[0].round(), v[1].round())]);
  final dstPts = cv.VecPoint.fromList([
    cv.Point(0, 0),
    cv.Point(w - 1, 0),
    cv.Point(w - 1, h - 1),
    cv.Point(0, h - 1),
  ]);
  final m = cv.getPerspectiveTransform(srcPts, dstPts);
  var out = cv.warpPerspective(img, m, (w, h), flags: cv.INTER_CUBIC);
  img.dispose();

  out = _filtered(out, ScanFilter.values[a['filter'] as int]);
  _write(a['dst'] as String, out);
  out.dispose();
  m.dispose();
}

List<int> _rotate(String path) {
  final img = cv.imread(path);
  final r = cv.rotate(img, cv.ROTATE_90_CLOCKWISE);
  _write(path, r);
  final size = [r.cols, r.rows];
  img.dispose();
  r.dispose();
  return size;
}
