import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({required this._factory, required this._path});

  static const schemaVersion = 1;

  final DatabaseFactory _factory;
  final Future<String> Function() _path;
  Future<Database>? _database;

  Future<Database> get database => _database ??= _open();

  Future<Database> _open() async {
    final path = await _path();
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE folders (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              name_key TEXT NOT NULL UNIQUE,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE documents (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              search_name TEXT NOT NULL,
              pdf_path TEXT NOT NULL UNIQUE,
              thumb_path TEXT,
              size_bytes INTEGER NOT NULL,
              page_count INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              modified_at INTEGER NOT NULL,
              folder_id TEXT REFERENCES folders(id) ON DELETE SET NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_documents_folder ON documents(folder_id)');
          await db.execute('CREATE INDEX idx_documents_modified ON documents(modified_at DESC)');
        },
      ),
    );
  }

  Future<void> close() async {
    final pending = _database;
    _database = null;
    if (pending != null) await (await pending).close();
  }
}
