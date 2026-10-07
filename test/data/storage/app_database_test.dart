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

  group('migrations', () {
    Future<void> createVersion1(String path) async {
      final db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT NOT NULL, name_key TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE documents (id TEXT PRIMARY KEY, name TEXT NOT NULL, search_name TEXT NOT NULL, pdf_path TEXT NOT NULL UNIQUE, thumb_path TEXT, size_bytes INTEGER NOT NULL, page_count INTEGER NOT NULL, created_at INTEGER NOT NULL, modified_at INTEGER NOT NULL, folder_id TEXT REFERENCES folders(id) ON DELETE SET NULL)',
            );
            await db.insert('folders', {'id': 'f1', 'name': 'Work', 'name_key': 'work', 'created_at': 1});
            await db.insert('documents', {
              'id': 'd1',
              'name': 'Old invoice',
              'search_name': 'old invoice',
              'pdf_path': '/docs/Old invoice.pdf',
              'size_bytes': 100,
              'page_count': 2,
              'created_at': 5,
              'modified_at': 6,
              'folder_id': 'f1',
            });
          },
        ),
      );
      await db.close();
    }

    test('upgrading from version 1 adds the text columns and keeps every row', () async {
      await createVersion1('${dir.path}/app.db');
      final db = await database.database;
      expect(await db.getVersion(), AppDatabase.schemaVersion);
      final columns = (await db.rawQuery('PRAGMA table_info(documents)')).map((c) => c['name']);
      expect(columns, containsAll(['content_text', 'search_content']));
      final doc = (await db.query('documents')).single;
      expect(doc['name'], 'Old invoice');
      expect(doc['folder_id'], 'f1');
      expect(doc['content_text'], isNull);
      expect(doc['search_content'], '');
      expect(await db.query('folders'), hasLength(1));
    });

    test('rows migrated from version 1 can receive text afterwards', () async {
      await createVersion1('${dir.path}/app.db');
      final db = await database.database;
      await db.update('documents', {'content_text': 'hello', 'search_content': 'hello'});
      expect((await db.query('documents')).single['content_text'], 'hello');
    });

    test('a new database is created directly at the latest version', () async {
      final db = await database.database;
      expect(await db.getVersion(), 2);
      final columns = (await db.rawQuery('PRAGMA table_info(documents)')).map((c) => c['name']);
      expect(columns, containsAll(['id', 'name', 'search_name', 'content_text', 'search_content', 'folder_id']));
    });

    test('opening an up to date database does not migrate again', () async {
      final db = await database.database;
      await db.insert('folders', {'id': 'f', 'name': 'A', 'name_key': 'a', 'created_at': 1});
      await database.close();
      final reopened = await database.database;
      expect(await reopened.query('folders'), hasLength(1));
      expect(await reopened.getVersion(), 2);
    });
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
