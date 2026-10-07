import 'dart:async';
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

  group('previewFilter', () {
    test('returns the original image for the Original filter without processing', () async {
      final src = makePage('src');
      expect(await session.previewFilter(src.path, ScanFilter.original), src.path);
      expect(processor.calls, isEmpty);
    });

    test('creates a filtered copy inside the session directory', () async {
      final src = makePage('src');
      final preview = await session.previewFilter(src.path, ScanFilter.grayscale);
      expect(preview, isNot(src.path));
      expect(preview.startsWith(dir.path), isTrue);
      expect(File(preview).existsSync(), isTrue);
      expect(processor.calls, ['preview:grayscale']);
    });

    test('computes each filter only once and reuses the cached file', () async {
      final src = makePage('src');
      final first = await session.previewFilter(src.path, ScanFilter.enhanced);
      final second = await session.previewFilter(src.path, ScanFilter.enhanced);
      expect(second, first);
      expect(processor.calls, ['preview:enhanced']);
    });

    test('concurrent requests for the same filter share one computation', () async {
      final src = makePage('src');
      processor.previewGate = Completer<void>();
      final a = session.previewFilter(src.path, ScanFilter.blackAndWhite);
      final b = session.previewFilter(src.path, ScanFilter.blackAndWhite);
      processor.previewGate!.complete();
      expect(await a, await b);
      expect(processor.calls, ['preview:blackAndWhite']);
    });

    test('keeps a separate preview per filter and per source image', () async {
      final a = makePage('a'), b = makePage('b');
      final results = {
        await session.previewFilter(a.path, ScanFilter.grayscale),
        await session.previewFilter(a.path, ScanFilter.enhanced),
        await session.previewFilter(b.path, ScanFilter.grayscale),
      };
      expect(results, hasLength(3));
    });

    test('a failed computation is not cached and can be retried', () async {
      final src = makePage('src');
      processor.previewError = StateError('boom');
      await expectLater(session.previewFilter(src.path, ScanFilter.grayscale), throwsStateError);
      processor.previewError = null;
      expect(File(await session.previewFilter(src.path, ScanFilter.grayscale)).existsSync(), isTrue);
    });

    test('discardPreviews deletes the previews of that image only', () async {
      final a = makePage('a'), b = makePage('b');
      final previewA = await session.previewFilter(a.path, ScanFilter.grayscale);
      final previewB = await session.previewFilter(b.path, ScanFilter.grayscale);
      session.discardPreviews(a.path);
      expect(File(previewA).existsSync(), isFalse);
      expect(File(previewB).existsSync(), isTrue);
      await session.previewFilter(a.path, ScanFilter.grayscale);
      expect(processor.calls.where((c) => c == 'preview:grayscale'), hasLength(3));
    });
  });

  group('batch shots', () {
    test('addShot stores a normalized copy inside the session and notifies', () async {
      final stored = await session.addShot(makePage('shot').path);
      expect(stored.startsWith(dir.path), isTrue);
      expect(File(stored).existsSync(), isTrue);
      expect(session.shots, [stored]);
      expect(session.pages, isEmpty);
      expect(notifications, 1);
    });

    test('pendingCount adds the pages and the shots', () async {
      session.add(ScanPage(makePage('a').path, 10, 20));
      await session.addShot(makePage('b').path);
      await session.addShot(makePage('c').path);
      expect(session.pendingCount, 3);
    });

    test('takeShots returns them in order and empties the queue', () async {
      final first = await session.addShot(makePage('one').path);
      final second = await session.addShot(makePage('two').path);
      expect(session.takeShots(), [first, second]);
      expect(session.shots, isEmpty);
    });

    test('shots are not editable from outside', () async {
      await session.addShot(makePage('one').path);
      expect(() => session.shots.add('x'), throwsUnsupportedError);
    });
  });

  test('detectInFile and detectLive delegate to the processor', () async {
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
