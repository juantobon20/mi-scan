import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/quad.dart';
import 'package:mi_scan/domain/entities/scan_filter.dart';
import 'package:mi_scan/domain/entities/scan_page.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:mi_scan/presentation/scanner/scan_session.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late FakeImageProcessor processor;
  late InMemoryDocumentRepository repo;
  late ScanSession session;
  late int notifications;

  File makePage(String name) => File('${dir.path}/$name.jpg')..writeAsBytesSync(kTinyPng);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('session_test_');
    processor = FakeImageProcessor();
    repo = InMemoryDocumentRepository();
    session = ScanSession(dir: dir.path, imageProcessor: processor, createDocument: CreateDocument(repo));
    notifications = 0;
    session.addListener(() => notifications++);
  });

  tearDown(() {
    session.dispose();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('add notifies and exposes the pages', () {
    session.add(ScanPage(makePage('a').path, 10, 20));
    expect(session.pages, hasLength(1));
    expect(notifications, 1);
  });

  test('pages cannot be modified from outside', () {
    expect(() => session.pages.add(const ScanPage('x', 1, 1)), throwsUnsupportedError);
  });

  test('removeAt removes the page and deletes its file', () {
    final f = makePage('a');
    session.add(ScanPage(f.path, 10, 20));
    session.removeAt(0);
    expect(session.pages, isEmpty);
    expect(f.existsSync(), isFalse);
    expect(notifications, 2);
  });

  test('move reorders (ReorderableListView.onReorderItem semantics)', () {
    for (final n in ['a', 'b', 'c']) {
      session.add(ScanPage(n, 1, 1));
    }
    session.move(0, 2);
    expect(session.pages.map((p) => p.path), ['b', 'c', 'a']);
  });

  test('rotate adopts the dimensions returned by the processor', () async {
    session.add(ScanPage(makePage('a').path, 800, 1000));
    await session.rotate(0);
    expect(session.pages.first.width, 1000);
    expect(session.pages.first.height, 800);
    expect(processor.calls, contains('rotate'));
  });

  test('importSource normalizes into a file inside the session', () async {
    final src = makePage('origen');
    final out = await session.importSource(src.path);
    expect(out.startsWith(dir.path), isTrue);
    expect(File(out).existsSync(), isTrue);
  });

  test('cropPage crops, normalizes and does NOT add the page', () async {
    final src = makePage('src');
    final page = await session.cropPage(src.path, Quad.inset(0.1), ScanFilter.grayscale);
    expect(processor.calls, ['crop:grayscale', 'normalize']);
    expect(page.width, 800);
    expect(page.height, 1000);
    expect(session.pages, isEmpty);
  });

  test('detectInFile y detectLive delegate to the processor', () async {
    processor.detected = Quad.inset(0.2);
    expect(await session.detectInFile('x'), processor.detected);
    expect(await session.detectLive(GrayFrame(Uint8List(4), 2, 2, 90)), processor.detected);
  });

  test('saveAsPdf creates the document with the session pages', () async {
    session.add(ScanPage(makePage('a').path, 10, 20));
    final doc = await session.saveAsPdf('My PDF');
    expect(doc.name, 'My PDF');
    expect(repo.docs, hasLength(1));
  });

  test('saveAsPdf without pages fails', () {
    expect(() => session.saveAsPdf('x'), throwsArgumentError);
  });

  test('disposeFiles deletes the session directory', () {
    session.disposeFiles();
    expect(dir.existsSync(), isFalse);
  });
}
