import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mi_scan/data/services/opencv_image_processor.dart';
import 'package:mi_scan/domain/entities/quad.dart';
import 'package:mi_scan/domain/entities/scan_filter.dart';

Future<File> _makeDocument(Directory dir, {int width = 800, int height = 600}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFB4C8DC),
  );
  for (var i = 0; i < 12; i++) {
    canvas.drawRect(
      ui.Rect.fromLTWH(60, 50.0 + i * 40, 500.0 - (i % 3) * 90, 14),
      ui.Paint()..color = const ui.Color(0xFF202830),
    );
  }
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  return File('${dir.path}/document.png')..writeAsBytesSync(bytes);
}

Future<({Uint8List rgba, int width, int height})> _decode(File file) async {
  final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData())!.buffer.asUint8List();
  return (rgba: data, width: image.width, height: image.height);
}

double _meanLuma(Uint8List rgba) {
  var sum = 0.0;
  for (var i = 0; i < rgba.length; i += 4) {
    sum += 0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
  }
  return sum / (rgba.length / 4);
}

/// Runs the real OpenCV pipeline of the app on a device or simulator.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File source;
  final processor = OpenCvImageProcessor();

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('opencv_filters_');
    source = await _makeDocument(dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('grayscale produces equal color channels', (tester) async {
    final out = File('${dir.path}/gray.jpg');
    await processor.applyFilter(source.path, out.path, ScanFilter.grayscale);
    final d = await _decode(out.existsSync() ? out : source);
    var colored = 0;
    for (var i = 0; i < d.rgba.length; i += 4) {
      if ((d.rgba[i] - d.rgba[i + 1]).abs() > 3 || (d.rgba[i + 1] - d.rgba[i + 2]).abs() > 3) colored++;
    }
    expect(colored / (d.rgba.length / 4), lessThan(0.01));
  });

  testWidgets('black and white produces only black and white pixels', (tester) async {
    final out = File('${dir.path}/bw.jpg');
    await processor.applyFilter(source.path, out.path, ScanFilter.blackAndWhite);
    final d = await _decode(out);
    var pure = 0;
    for (var i = 0; i < d.rgba.length; i += 4) {
      final v = d.rgba[i];
      if (v < 40 || v > 215) pure++;
    }
    expect(pure / (d.rgba.length / 4), greaterThan(0.97));
    final dark = [for (var i = 0; i < d.rgba.length; i += 4) d.rgba[i]].where((v) => v < 40).length;
    expect(dark, greaterThan(0));
  });

  testWidgets('enhanced is brighter than the original', (tester) async {
    final out = File('${dir.path}/enhanced.jpg');
    await processor.applyFilter(source.path, out.path, ScanFilter.enhanced);
    final original = await _decode(source);
    final enhanced = await _decode(out);
    expect(_meanLuma(enhanced.rgba), greaterThan(_meanLuma(original.rgba)));
  });

  testWidgets('the preview is reduced to maxSide keeping the aspect ratio', (tester) async {
    final out = File('${dir.path}/small.jpg');
    await processor.applyFilter(source.path, out.path, ScanFilter.grayscale, maxSide: 200);
    final d = await _decode(out);
    expect(d.width, 200);
    expect(d.height, 150);
  });

  testWidgets('small images are not enlarged', (tester) async {
    final out = File('${dir.path}/same.jpg');
    await processor.applyFilter(source.path, out.path, ScanFilter.enhanced, maxSide: 4000);
    final d = await _decode(out);
    expect(d.width, 800);
    expect(d.height, 600);
  });

  testWidgets('the saved crop applies the same filter as the preview', (tester) async {
    final preview = File('${dir.path}/preview.jpg');
    final cropped = File('${dir.path}/cropped.jpg');
    await processor.applyFilter(source.path, preview.path, ScanFilter.blackAndWhite);
    await processor.crop(source.path, cropped.path, Quad.inset(0.0), ScanFilter.blackAndWhite);
    final a = await _decode(preview);
    final b = await _decode(cropped);
    var darkA = 0, darkB = 0;
    for (var i = 0; i < a.rgba.length; i += 4) {
      if (a.rgba[i] < 128) darkA++;
    }
    for (var i = 0; i < b.rgba.length; i += 4) {
      if (b.rgba[i] < 128) darkB++;
    }
    final shareA = darkA / (a.rgba.length / 4);
    final shareB = darkB / (b.rgba.length / 4);
    expect((shareA - shareB).abs(), lessThan(0.05));
  });
}
