import 'package:sqflite/sqflite.dart';

import '../../core/utils/id_generator.dart';
import '../../core/utils/search_text.dart';
import '../../domain/entities/folder.dart';
import '../../domain/repositories/folder_repository.dart';
import '../storage/app_database.dart';

class SqliteFolderRepository implements FolderRepository {
  SqliteFolderRepository({required this._database, IdGenerator? ids, DateTime Function()? clock})
      : _ids = ids ?? generateId,
        _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final IdGenerator _ids;
  final DateTime Function() _clock;

  @override
  Future<List<FolderSummary>> list() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT f.id, f.name, f.created_at, COUNT(d.id) AS document_count
      FROM folders f
      LEFT JOIN documents d ON d.folder_id = f.id
      GROUP BY f.id
      ORDER BY f.name_key
    ''');
    return [
      for (final row in rows)
        FolderSummary(
          Folder(
            id: row['id']! as String,
            name: row['name']! as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
          ),
          row['document_count']! as int,
        ),
    ];
  }

  @override
  Future<Folder> create(String name) async {
    final db = await _database.database;
    final unique = await _uniqueName(db, name);
    final folder = Folder(id: _ids(), name: unique, createdAt: _clock());
    await db.insert('folders', {
      'id': folder.id,
      'name': folder.name,
      'name_key': normalizeSearchText(folder.name),
      'created_at': folder.createdAt.millisecondsSinceEpoch,
    });
    return folder;
  }

  @override
  Future<Folder> rename(Folder folder, String newName) async {
    final db = await _database.database;
    final unique = await _uniqueName(db, newName, ignoreId: folder.id);
    await db.update(
      'folders',
      {'name': unique, 'name_key': normalizeSearchText(unique)},
      where: 'id = ?',
      whereArgs: [folder.id],
    );
    return folder.copyWith(name: unique);
  }

  @override
  Future<void> delete(Folder folder) async {
    final db = await _database.database;
    await db.delete('folders', where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<String> _uniqueName(Database db, String name, {String? ignoreId}) async {
    final base = name.trim();
    var candidate = base, i = 2;
    while (await _isTaken(db, candidate, ignoreId)) {
      candidate = '$base ($i)';
      i++;
    }
    return candidate;
  }

  Future<bool> _isTaken(Database db, String name, String? ignoreId) async {
    final rows = await db.query(
      'folders',
      columns: ['id'],
      where: ignoreId == null ? 'name_key = ?' : 'name_key = ? AND id != ?',
      whereArgs: ignoreId == null ? [normalizeSearchText(name)] : [normalizeSearchText(name), ignoreId],
    );
    return rows.isNotEmpty;
  }
}
