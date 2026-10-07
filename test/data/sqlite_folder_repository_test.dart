import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/scan_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/sqlite_helpers.dart';

void main() {
  sqfliteFfiInit();

  late StorageHarness h;
  const pages = [ScanPage('/tmp/p1.jpg', 100, 200)];

  setUp(() => h = StorageHarness.create());
  tearDown(() => h.dispose());

  test('starts empty', () async {
    expect(await h.folders.list(), isEmpty);
  });

  test('creates a folder with a trimmed name', () async {
    final folder = await h.folders.create('  Work  ');
    expect(folder.name, 'Work');
    expect((await h.folders.list()).single.folder, folder);
  });

  test('lists folders alphabetically ignoring case and accents', () async {
    for (final name in ['beta', '\u00c1lamo', 'alpha', 'Zeta']) {
      await h.folders.create(name);
    }
    expect((await h.folders.list()).map((s) => s.folder.name), ['\u00c1lamo', 'alpha', 'beta', 'Zeta']);
  });

  test('counts the documents of each folder', () async {
    final a = await h.folders.create('A');
    await h.folders.create('B');
    await h.documents.createFromPages(pages, 'One', folderId: a.id);
    await h.documents.createFromPages(pages, 'Two', folderId: a.id);
    await h.documents.createFromPages(pages, 'Loose');
    final counts = {for (final s in await h.folders.list()) s.folder.name: s.documentCount};
    expect(counts, {'A': 2, 'B': 0});
  });

  group('unique names', () {
    test('a repeated name gets a numeric suffix', () async {
      final names = [for (var i = 0; i < 3; i++) (await h.folders.create('Work')).name];
      expect(names, ['Work', 'Work (2)', 'Work (3)']);
    });

    test('the comparison ignores case and accents', () async {
      await h.folders.create('Facturaci\u00f3n');
      expect((await h.folders.create('FACTURACION')).name, 'FACTURACION (2)');
    });

    test('renaming to the same name keeps it', () async {
      final folder = await h.folders.create('Work');
      expect((await h.folders.rename(folder, 'Work')).name, 'Work');
    });

    test('renaming to a name used by another folder adds a suffix', () async {
      await h.folders.create('Work');
      final other = await h.folders.create('Home');
      expect((await h.folders.rename(other, 'work')).name, 'work (2)');
    });

    test('renaming only changes the case of its own name', () async {
      final folder = await h.folders.create('work');
      expect((await h.folders.rename(folder, 'Work')).name, 'Work');
    });
  });

  test('rename persists and keeps the documents', () async {
    final folder = await h.folders.create('Old');
    await h.documents.createFromPages(pages, 'Doc', folderId: folder.id);
    await h.folders.rename(folder, 'New');
    final summary = (await h.folders.list()).single;
    expect(summary.folder.name, 'New');
    expect(summary.documentCount, 1);
  });

  test('delete removes the folder and unfiles its documents', () async {
    final folder = await h.folders.create('Temp');
    await h.documents.createFromPages(pages, 'Doc', folderId: folder.id);
    await h.folders.delete(folder);
    expect(await h.folders.list(), isEmpty);
    expect((await h.documents.list()).single.folderId, isNull);
  });

  test('folders survive closing and reopening the database', () async {
    await h.folders.create('Persistent');
    await h.reopen();
    expect((await h.folders.list()).single.folder.name, 'Persistent');
  });

  test('every folder gets its own id', () async {
    final a = await h.folders.create('A');
    final b = await h.folders.create('B');
    expect(a.id, isNot(b.id));
  });
}
