import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/data/repositories/file_document_repository.dart';
import 'package:mi_scan/domain/entities/scan_page.dart';

import '../helpers/fakes.dart';

void main() {
  late Directory root;
  late FileDocumentRepository repo;
  late FakePdfGenerator pdf;
  const pages = [ScanPage('/tmp/p1.jpg', 100, 200), ScanPage('/tmp/p2.jpg', 300, 200)];

  setUp(() {
    root = Directory.systemTemp.createTempSync('repo_test_');
    pdf = FakePdfGenerator();
    repo = FileDocumentRepository(
      directories: FakeAppDirectories(root),
      pdfGenerator: pdf,
      thumbnailGenerator: FakeThumbnailGenerator(),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('list is empty at start', () async {
    expect(await repo.list(), isEmpty);
  });

  test('createFromPages writes the PDF and the thumbnail', () async {
    final doc = await repo.createFromPages(pages, 'Invoice');
    expect(doc.name, 'Invoice');
    expect(File(doc.pdfPath).readAsStringSync(), '%PDF-fake');
    expect(doc.thumbPath, '${doc.pdfPath}.jpg');
    expect(File(doc.thumbPath!).existsSync(), isTrue);
    expect(doc.sizeBytes, 9);
    expect(pdf.lastPages, pages);
  });

  test('sanitizes the name', () async {
    final doc = await repo.createFromPages(pages, 'a/b:c');
    expect(doc.name, 'a_b_c');
  });

  test('avoids overwriting documents with the same name', () async {
    final a = await repo.createFromPages(pages, 'Doc');
    final b = await repo.createFromPages(pages, 'Doc');
    final c = await repo.createFromPages(pages, 'Doc');
    expect([a.name, b.name, c.name], ['Doc', 'Doc (2)', 'Doc (3)']);
  });

  test('list returns the most recent first', () async {
    final old = await repo.createFromPages(pages, 'Old');
    File(old.pdfPath).setLastModifiedSync(DateTime(2020));
    await repo.createFromPages(pages, 'New');
    expect((await repo.list()).map((d) => d.name), ['New', 'Old']);
  });

  test('list ignores non-PDF files (thumbnails included)', () async {
    await repo.createFromPages(pages, 'One');
    expect(await repo.list(), hasLength(1));
  });

  group('rename', () {
    test('moves the PDF and the thumbnail', () async {
      final doc = await repo.createFromPages(pages, 'Before');
      final renamed = await repo.rename(doc, 'After');
      expect(renamed.name, 'After');
      expect(File(doc.pdfPath).existsSync(), isFalse);
      expect(File('${doc.pdfPath}.jpg').existsSync(), isFalse);
      expect(File(renamed.pdfPath).existsSync(), isTrue);
      expect(renamed.thumbPath, isNotNull);
    });

    test('renaming to the same name adds no suffix', () async {
      final doc = await repo.createFromPages(pages, 'Same');
      expect((await repo.rename(doc, 'Same')).name, 'Same');
    });

    test('adds a suffix if the name belongs to another document', () async {
      await repo.createFromPages(pages, 'Taken');
      final other = await repo.createFromPages(pages, 'Other');
      expect((await repo.rename(other, 'Taken')).name, 'Taken (2)');
    });

    test('without a previous thumbnail, thumbPath is null', () async {
      final doc = await repo.createFromPages(pages, 'NoThumb');
      File(doc.thumbPath!).deleteSync();
      expect((await repo.rename(doc, 'New')).thumbPath, isNull);
    });
  });

  test('delete removes the PDF and the thumbnail', () async {
    final doc = await repo.createFromPages(pages, 'Remove');
    await repo.delete(doc);
    expect(await repo.list(), isEmpty);
    expect(File('${doc.pdfPath}.jpg').existsSync(), isFalse);
  });

  test('delete is idempotent', () async {
    final doc = await repo.createFromPages(pages, 'Remove');
    await repo.delete(doc);
    await repo.delete(doc);
  });
}
