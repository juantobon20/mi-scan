import 'dart:io';

import 'package:mi_scan/data/repositories/sqlite_document_repository.dart';
import 'package:mi_scan/data/repositories/sqlite_folder_repository.dart';
import 'package:mi_scan/data/storage/app_database.dart';
import 'package:mi_scan/data/storage/document_files.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';

class StorageHarness {
  StorageHarness._(this.root, this.pdf, this.factory) {
    open();
  }

  factory StorageHarness.create({DatabaseFactory? factory}) => StorageHarness._(
        Directory.systemTemp.createTempSync('storage_test_'),
        FakePdfGenerator(),
        factory ?? databaseFactoryFfi,
      );

  final DatabaseFactory factory;

  final Directory root;
  final FakePdfGenerator pdf;
  late AppDatabase database;
  late DocumentFiles files;
  late SqliteDocumentRepository documents;
  late SqliteFolderRepository folders;
  var _tick = 0;
  var _id = 0;

  Directory get pdfDir => Directory('${root.path}/docs/pdfs')..createSync(recursive: true);

  String get dbPath => '${root.path}/test.db';

  DateTime _clock() => DateTime(2026, 1, 1).add(Duration(minutes: _tick++));

  String _ids() => 'id${_id++}';

  void open() {
    database = AppDatabase(factory: factory, path: () async => dbPath);
    files = DocumentFiles(
      directories: FakeAppDirectories(root),
      pdfGenerator: pdf,
      thumbnailGenerator: FakeThumbnailGenerator(),
    );
    documents = SqliteDocumentRepository(database: database, files: files, ids: _ids, clock: _clock);
    folders = SqliteFolderRepository(database: database, ids: _ids, clock: _clock);
  }

  Future<void> reopen() async {
    await database.close();
    open();
  }

  Future<void> dispose() async {
    await database.close();
    root.deleteSync(recursive: true);
  }
}
