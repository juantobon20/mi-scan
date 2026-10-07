import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/data/storage/app_database.dart';
import 'package:mi_scan/data/storage/pdf_page_counter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory dir;
  late AppDatabase database;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('app_database_test_');
    database = AppDatabase(factory: databaseFactoryFfi, path: () async => '${dir.path}/app.db');
  });

  tearDown(() async {
    await database.close();
    dir.deleteSync(recursive: true);
  });

  test('creates the schema on first use', () async {
    final db = await database.database;
    final tables = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'")).map((r) => r['name']);
    expect(tables, containsAll(['folders', 'documents']));
    expect(await db.getVersion(), AppDatabase.schemaVersion);
  });

  test('creates the indexes used by the queries', () async {
    final db = await database.database;
    final indexes = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'index'")).map((r) => r['name']);
    expect(indexes, containsAll(['idx_documents_folder', 'idx_documents_modified']));
  });

  test('enforces foreign keys', () async {
    final db = await database.database;
    expect((await db.rawQuery('PRAGMA foreign_keys')).single['foreign_keys'], 1);
  });

  test('returns the same connection every time', () async {
    expect(identical(await database.database, await database.database), isTrue);
  });

  test('keeps the data after closing and opening again', () async {
    final db = await database.database;
    await db.insert('folders', {'id': 'f', 'name': 'Work', 'name_key': 'work', 'created_at': 1});
    await database.close();
    final reopened = await database.database;
    expect(await reopened.query('folders'), hasLength(1));
  });

  test('close can be called when the database was never opened', () async {
    await database.close();
  });

  test('a folder name key is unique', () async {
    final db = await database.database;
    await db.insert('folders', {'id': 'a', 'name': 'Work', 'name_key': 'work', 'created_at': 1});
    await expectLater(
      db.insert('folders', {'id': 'b', 'name': 'work', 'name_key': 'work', 'created_at': 2}),
      throwsA(anything),
    );
  });

  group('countPdfPages', () {
    int count(String text) => countPdfPages(Uint8List.fromList(text.codeUnits));

    test('counts page objects and ignores the page tree', () {
      expect(count('/Type /Pages /Type /Page /Type /Page'), 2);
    });

    test('accepts the compact spelling', () {
      expect(count('/Type/Page /Type /Page'), 2);
    });

    test('returns zero for content that is not a PDF', () {
      expect(count('hello'), 0);
    });
  });
}
