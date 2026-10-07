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
}
