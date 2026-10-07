import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mi_scan/data/services/ml_kit_text_recognizer.dart';
import 'package:mi_scan/domain/entities/document_query.dart';
import 'package:mi_scan/domain/entities/scan_page.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:sqflite/sqflite.dart';

import '../test/helpers/sqlite_helpers.dart';

Future<File> _imageWithText(Directory dir, String name, List<String> lines) async {
  const width = 900.0, height = 500.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, width, height), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  for (var i = 0; i < lines.length; i++) {
    final paragraph = (ui.ParagraphBuilder(ui.ParagraphStyle())
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF000000), fontSize: 64, fontWeight: FontWeight.w600))
          ..addText(lines[i]))
        .build()
      ..layout(const ui.ParagraphConstraints(width: width - 80));
    canvas.drawParagraph(paragraph, ui.Offset(40, 40.0 + i * 120));
  }
  final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  return File('${dir.path}/$name.png')..writeAsBytesSync(bytes);
}

/// Runs the real ML Kit text recognizer and the real database on a device or simulator.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late MlKitTextRecognizer recognizer;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ocr_test_');
    recognizer = MlKitTextRecognizer();
  });

  tearDown(() async {
    await recognizer.dispose();
    dir.deleteSync(recursive: true);
  });

  testWidgets('reads the printed words of an image', (tester) async {
    final image = await _imageWithText(dir, 'invoice', ['INVOICE 2026', 'Total 120']);
    final result = await recognizer.recognize(image.path);
    final text = result.text.toLowerCase();
    expect(text, contains('invoice'));
    expect(text, contains('total'));
    expect(text, contains('120'));
  });

  testWidgets('an image without text gives an empty result', (tester) async {
    final image = await _imageWithText(dir, 'blank', const []);
    expect((await recognizer.recognize(image.path)).isEmpty, isTrue);
  });

  testWidgets('the recognizer can be used again after being disposed', (tester) async {
    final image = await _imageWithText(dir, 'again', ['HELLO WORLD']);
    expect((await recognizer.recognize(image.path)).text.toLowerCase(), contains('hello'));
    await recognizer.dispose();
    expect((await recognizer.recognize(image.path)).text.toLowerCase(), contains('world'));
  });

  testWidgets('a scanned document becomes searchable by its content', (tester) async {
    final h = StorageHarness.create(factory: databaseFactory);
    addTearDown(h.dispose);
    final image = await _imageWithText(dir, 'page', ['MORTGAGE PAYMENT', 'Receipt 42']);
    final pages = [ScanPage(image.path, 900, 500)];
    final doc = await h.documents.createFromPages(pages, 'Scan 1');
    await h.documents.createFromPages(pages, 'Scan 2');

    final outcome = await RecognizeDocumentText(recognizer, h.documents)(doc, pages);
    expect(outcome.hasText, isTrue);

    final found = await h.documents.list(query: const DocumentQuery(text: 'mortgage'));
    expect(found.map((d) => d.name), ['Scan 1']);
    expect(found.single.hasText, isTrue);
    expect(await h.documents.getText(doc.id), contains('MORTGAGE'));
  });
}
