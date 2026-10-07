import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mi_scan/domain/entities/document_query.dart';
import 'package:mi_scan/domain/entities/scan_page.dart';
import 'package:sqflite/sqflite.dart';

import '../test/helpers/sqlite_helpers.dart';

/// Runs the real sqflite plugin on a device or simulator.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late StorageHarness h;
  const pages = [ScanPage('/tmp/p1.jpg', 100, 200), ScanPage('/tmp/p2.jpg', 300, 200)];

  setUp(() => h = StorageHarness.create(factory: databaseFactory));
  tearDown(() => h.dispose());

  testWidgets('creates, lists, renames and deletes documents', (tester) async {
    final doc = await h.documents.createFromPages(pages, 'Invoice');
    expect((await h.documents.list()).single.pageCount, 2);
    final renamed = await h.documents.rename(doc, 'Receipt');
    expect((await h.documents.list()).single.name, 'Receipt');
    expect(File(renamed.pdfPath).existsSync(), isTrue);
    await h.documents.delete(renamed);
    expect(await h.documents.list(), isEmpty);
  });

  testWidgets('searches ignoring case and accents, with literal wildcards', (tester) async {
    for (final name in ['Declaraci\u00f3n de renta', '100% done', 'a_b file', 'Plain']) {
      await h.documents.createFromPages(pages, name);
    }
    Future<List<String>> find(String text) async =>
        (await h.documents.list(query: DocumentQuery(text: text))).map((d) => d.name).toList();
    expect(await find('DECLARACION'), ['Declaraci\u00f3n de renta']);
    expect(await find('100%'), ['100% done']);
    expect(await find('a_b'), ['a_b file']);
    expect(await find('nothing'), isEmpty);
  });

  testWidgets('folders keep their documents and unfile them when deleted', (tester) async {
    final work = await h.folders.create('Work');
    final doc = await h.documents.createFromPages(pages, 'Doc', folderId: work.id);
    expect((await h.folders.list()).single.documentCount, 1);
    expect((await h.documents.list(query: DocumentQuery(folderId: work.id))).single.id, doc.id);
    await h.folders.delete(work);
    expect((await h.documents.list()).single.folderId, isNull);
  });

  testWidgets('foreign keys are enforced by the native database', (tester) async {
    final doc = await h.documents.createFromPages(pages, 'Doc');
    await expectLater(h.documents.move(doc, 'missing'), throwsA(anything));
  });

  testWidgets('the data survives closing and reopening the database', (tester) async {
    final work = await h.folders.create('Work');
    await h.documents.createFromPages(pages, 'Persistent', folderId: work.id);
    await h.reopen();
    final stored = (await h.documents.list()).single;
    expect(stored.name, 'Persistent');
    expect(stored.folderId, work.id);
    expect((await h.folders.list()).single.folder.name, 'Work');
  });

  testWidgets('imports PDFs that older versions saved without a database', (tester) async {
    File('${h.pdfDir.path}/Legacy.pdf').writeAsStringSync('/Type /Page /Type /Page');
    final doc = (await h.documents.list()).single;
    expect(doc.name, 'Legacy');
    expect(doc.pageCount, 2);
  });

  testWidgets('upgrades a version 1 database keeping its data', (tester) async {
    final old = await databaseFactory.openDatabase(
      h.dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT NOT NULL, name_key TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE documents (id TEXT PRIMARY KEY, name TEXT NOT NULL, search_name TEXT NOT NULL, pdf_path TEXT NOT NULL UNIQUE, thumb_path TEXT, size_bytes INTEGER NOT NULL, page_count INTEGER NOT NULL, created_at INTEGER NOT NULL, modified_at INTEGER NOT NULL, folder_id TEXT REFERENCES folders(id) ON DELETE SET NULL)',
          );
          await db.insert('documents', {
            'id': 'old1',
            'name': 'Old invoice',
            'search_name': 'old invoice',
            'pdf_path': '${h.pdfDir.path}/Old invoice.pdf',
            'size_bytes': 10,
            'page_count': 1,
            'created_at': 1,
            'modified_at': 2,
          });
        },
      ),
    );
    await old.close();
    File('${h.pdfDir.path}/Old invoice.pdf').writeAsStringSync('/Type /Page');
    await h.reopen();

    final doc = (await h.documents.list()).single;
    expect(doc.id, 'old1');
    expect(doc.hasText, isFalse);
    await h.documents.saveText(doc.id, 'migrated text');
    expect((await h.documents.list(query: const DocumentQuery(text: 'migrated'))).single.id, 'old1');
  });

  testWidgets('searches inside the recognized text', (tester) async {
    final doc = await h.documents.createFromPages(pages, 'Scan');
    await h.documents.saveText(doc.id, 'Declaraci\u00f3n de la renta');
    expect((await h.documents.list(query: const DocumentQuery(text: 'declaracion'))).single.hasText, isTrue);
    expect(await h.documents.list(query: const DocumentQuery(text: 'zebra')), isEmpty);
  });
}
