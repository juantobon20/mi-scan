import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/document_query.dart';
import 'package:mi_scan/domain/entities/scan_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/sqlite_helpers.dart';

void main() {
  sqfliteFfiInit();

  late StorageHarness h;
  const pages = [ScanPage('/tmp/p1.jpg', 100, 200), ScanPage('/tmp/p2.jpg', 300, 200)];

  setUp(() => h = StorageHarness.create());
  tearDown(() => h.dispose());

  test('starts empty', () async {
    expect(await h.documents.list(), isEmpty);
  });

  group('create', () {
    test('writes the PDF, the thumbnail and a row with its metadata', () async {
      final doc = await h.documents.createFromPages(pages, 'Invoice');
      expect(doc.name, 'Invoice');
      expect(File(doc.pdfPath).readAsStringSync(), '%PDF-fake');
      expect(doc.thumbPath, '${doc.pdfPath}.jpg');
      expect(File(doc.thumbPath!).existsSync(), isTrue);
      expect(doc.pageCount, 2);
      expect(doc.sizeBytes, 9);
      expect(doc.folderId, isNull);
      expect(doc.createdAt, doc.modified);
    });

    test('stores the document in a folder when asked', () async {
      final folder = await h.folders.create('Work');
      final doc = await h.documents.createFromPages(pages, 'Invoice', folderId: folder.id);
      expect(doc.folderId, folder.id);
      expect((await h.documents.list()).single.folderId, folder.id);
    });

    test('sanitizes the name', () async {
      expect((await h.documents.createFromPages(pages, 'a/b:c')).name, 'a_b_c');
    });

    test('avoids overwriting a document with the same name', () async {
      final names = [
        for (var i = 0; i < 3; i++) (await h.documents.createFromPages(pages, 'Doc')).name,
      ];
      expect(names, ['Doc', 'Doc (2)', 'Doc (3)']);
    });

    test('removes the files when the row cannot be saved', () async {
      await expectLater(h.documents.createFromPages(pages, 'Broken', folderId: 'missing-folder'), throwsA(anything));
      expect(h.pdfDir.listSync(), isEmpty);
    });

    test('survives closing and reopening the database', () async {
      await h.documents.createFromPages(pages, 'Persistent');
      await h.reopen();
      expect((await h.documents.list()).single.name, 'Persistent');
    });
  });

  group('list', () {
    test('returns the most recent first', () async {
      await h.documents.createFromPages(pages, 'First');
      await h.documents.createFromPages(pages, 'Second');
      await h.documents.createFromPages(pages, 'Third');
      expect((await h.documents.list()).map((d) => d.name), ['Third', 'Second', 'First']);
    });

    test('does not list thumbnails as documents', () async {
      await h.documents.createFromPages(pages, 'One');
      expect(await h.documents.list(), hasLength(1));
    });

    test('reports no thumbnail when the file disappeared', () async {
      final doc = await h.documents.createFromPages(pages, 'NoThumb');
      File(doc.thumbPath!).deleteSync();
      expect((await h.documents.list()).single.thumbPath, isNull);
    });
  });

  group('search', () {
    setUp(() async {
      for (final name in ['Invoice March', 'Contract 2026', 'Declaraci\u00f3n de renta', '100% done', 'a_b file']) {
        await h.documents.createFromPages(pages, name);
      }
    });

    Future<List<String>> find(String text, {String? folderId}) async =>
        (await h.documents.list(query: DocumentQuery(text: text, folderId: folderId))).map((d) => d.name).toList();

    test('matches part of the name', () async {
      expect(await find('contr'), ['Contract 2026']);
    });

    test('ignores case', () async {
      expect(await find('INVOICE'), ['Invoice March']);
    });

    test('ignores accents in the query and in the name', () async {
      expect(await find('declaracion'), ['Declaraci\u00f3n de renta']);
      expect(await find('DECLARACI\u00d3N'), ['Declaraci\u00f3n de renta']);
    });

    test('requires every word', () async {
      expect(await find('invoice march'), ['Invoice March']);
      expect(await find('invoice 2026'), isEmpty);
    });

    test('words can appear in any order', () async {
      expect(await find('march invoice'), ['Invoice March']);
    });

    test('percent signs are literal, not wildcards', () async {
      expect(await find('100%'), ['100% done']);
      expect(await find('%'), ['100% done']);
    });

    test('underscores are literal, not wildcards', () async {
      expect(await find('a_b'), ['a_b file']);
      expect(await find('_'), ['a_b file']);
    });

    test('a quote in the query does not break the statement', () async {
      expect(await find("o'brien"), isEmpty);
    });

    test('blank text returns everything', () async {
      expect(await find('   '), hasLength(5));
    });

    test('no match returns an empty list', () async {
      expect(await find('zzz'), isEmpty);
    });

    test('combines with the folder filter', () async {
      final folder = await h.folders.create('Work');
      final docs = await h.documents.list();
      await h.documents.move(docs.firstWhere((d) => d.name == 'Contract 2026'), folder.id);
      expect(await find('contr', folderId: folder.id), ['Contract 2026']);
      expect(await find('invoice', folderId: folder.id), isEmpty);
    });
  });

  group('folders', () {
    test('lists only the documents of a folder', () async {
      final work = await h.folders.create('Work');
      await h.documents.createFromPages(pages, 'In work', folderId: work.id);
      await h.documents.createFromPages(pages, 'Loose');
      expect((await h.documents.list(query: DocumentQuery(folderId: work.id))).map((d) => d.name), ['In work']);
      expect(await h.documents.list(), hasLength(2));
    });

    test('moving a document changes its folder and back', () async {
      final work = await h.folders.create('Work');
      final doc = await h.documents.createFromPages(pages, 'Doc');
      expect((await h.documents.move(doc, work.id)).folderId, work.id);
      expect((await h.documents.list()).single.folderId, work.id);
      await h.documents.move(doc, null);
      expect((await h.documents.list()).single.folderId, isNull);
    });

    test('moving to a folder that does not exist fails', () async {
      final doc = await h.documents.createFromPages(pages, 'Doc');
      await expectLater(h.documents.move(doc, 'ghost'), throwsA(anything));
    });

    test('deleting a folder keeps its documents unfiled', () async {
      final work = await h.folders.create('Work');
      await h.documents.createFromPages(pages, 'Keep me', folderId: work.id);
      await h.folders.delete(work);
      final docs = await h.documents.list();
      expect(docs.single.name, 'Keep me');
      expect(docs.single.folderId, isNull);
    });
  });

  group('rename', () {
    test('moves the files and updates the row, keeping the folder', () async {
      final work = await h.folders.create('Work');
      final doc = await h.documents.createFromPages(pages, 'Before', folderId: work.id);
      final renamed = await h.documents.rename(doc, 'After');
      expect(renamed.name, 'After');
      expect(File(doc.pdfPath).existsSync(), isFalse);
      expect(File(renamed.pdfPath).existsSync(), isTrue);
      expect(File(renamed.thumbPath!).existsSync(), isTrue);
      final stored = (await h.documents.list()).single;
      expect(stored.name, 'After');
      expect(stored.folderId, work.id);
      expect(stored.id, doc.id);
    });

    test('search finds the new name and not the old one', () async {
      final doc = await h.documents.createFromPages(pages, 'Before');
      await h.documents.rename(doc, 'After');
      expect(await h.documents.list(query: const DocumentQuery(text: 'after')), hasLength(1));
      expect(await h.documents.list(query: const DocumentQuery(text: 'before')), isEmpty);
    });

    test('renaming to the same name adds no suffix', () async {
      final doc = await h.documents.createFromPages(pages, 'Same');
      expect((await h.documents.rename(doc, 'Same')).name, 'Same');
    });

    test('a name used by another document gets a suffix', () async {
      await h.documents.createFromPages(pages, 'Taken');
      final other = await h.documents.createFromPages(pages, 'Other');
      expect((await h.documents.rename(other, 'Taken')).name, 'Taken (2)');
    });

    test('a document without thumbnail can be renamed', () async {
      final doc = await h.documents.createFromPages(pages, 'NoThumb');
      File(doc.thumbPath!).deleteSync();
      expect((await h.documents.rename(doc, 'Renamed')).thumbPath, isNull);
    });
  });

  group('delete', () {
    test('removes the row and both files', () async {
      final doc = await h.documents.createFromPages(pages, 'Gone');
      await h.documents.delete(doc);
      expect(await h.documents.list(), isEmpty);
      expect(File(doc.pdfPath).existsSync(), isFalse);
      expect(File('${doc.pdfPath}.jpg').existsSync(), isFalse);
    });

    test('is idempotent', () async {
      final doc = await h.documents.createFromPages(pages, 'Gone');
      await h.documents.delete(doc);
      await h.documents.delete(doc);
    });
  });

  group('importing documents that already exist on disk', () {
    test('adds PDFs saved by older versions of the app, with their size and date', () async {
      final legacy = File('${h.pdfDir.path}/Legacy.pdf')..writeAsBytesSync(List.filled(1500, 65));
      File('${legacy.path}.jpg').writeAsBytesSync([1, 2, 3]);
      legacy.setLastModifiedSync(DateTime(2025, 5, 6, 7, 8));
      final doc = (await h.documents.list()).single;
      expect(doc.name, 'Legacy');
      expect(doc.sizeBytes, 1500);
      expect(doc.modified, DateTime(2025, 5, 6, 7, 8));
      expect(doc.thumbPath, '${legacy.path}.jpg');
      expect(doc.folderId, isNull);
    });

    test('counts the pages of an imported PDF', () async {
      File('${h.pdfDir.path}/Three.pdf').writeAsStringSync(
        '%PDF-1.4 /Type /Pages /Kids [1 2 3] /Type /Page 1 /Type /Page 2 /Type/Page 3',
      );
      expect((await h.documents.list()).single.pageCount, 3);
    });

    test('imported documents can be searched', () async {
      File('${h.pdfDir.path}/Old receipt.pdf').writeAsStringSync('x');
      expect(await h.documents.list(query: const DocumentQuery(text: 'receipt')), hasLength(1));
    });

    test('drops the rows whose PDF was deleted outside the app', () async {
      final doc = await h.documents.createFromPages(pages, 'Vanished');
      File(doc.pdfPath).deleteSync();
      await h.reopen();
      expect(await h.documents.list(), isEmpty);
    });

    test('a restart picks up files added meanwhile and does not duplicate known ones', () async {
      await h.documents.createFromPages(pages, 'Known');
      File('${h.pdfDir.path}/Added later.pdf').writeAsStringSync('x');
      await h.reopen();
      expect((await h.documents.list()).map((d) => d.name), unorderedEquals(['Known', 'Added later']));
      await h.reopen();
      expect(await h.documents.list(), hasLength(2));
    });

    test('files that are not PDFs are ignored', () async {
      File('${h.pdfDir.path}/notes.txt').writeAsStringSync('x');
      expect(await h.documents.list(), isEmpty);
    });
  });
}
