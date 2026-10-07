import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../core/utils/id_generator.dart';
import '../../core/utils/search_text.dart';
import '../../domain/entities/document_query.dart';
import '../../domain/entities/scan_page.dart';
import '../../domain/entities/scanned_document.dart';
import '../../domain/repositories/document_repository.dart';
import '../storage/app_database.dart';
import '../storage/document_files.dart';

class SqliteDocumentRepository implements DocumentRepository {
  SqliteDocumentRepository({
    required this._database,
    required this._files,
    IdGenerator? ids,
    DateTime Function()? clock,
  })  : _ids = ids ?? generateId,
        _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final DocumentFiles _files;
  final IdGenerator _ids;
  final DateTime Function() _clock;
  Future<void>? _sync;

  static const _listColumns = [
    'id',
    'name',
    'pdf_path',
    'thumb_path',
    'size_bytes',
    'page_count',
    'created_at',
    'modified_at',
    'folder_id',
    '(content_text IS NOT NULL AND length(content_text) > 0) AS has_text',
  ];

  Future<Database> _ready() async {
    final db = await _database.database;
    await (_sync ??= _reconcile(db));
    return db;
  }

  Future<void> _reconcile(Database db) async {
    final rows = await db.query('documents', columns: ['id', 'pdf_path']);
    final known = {for (final r in rows) r['pdf_path']! as String};
    final onDisk = await _files.listPdfs();
    final onDiskPaths = {for (final f in onDisk) f.path};

    await db.transaction((txn) async {
      for (final row in rows) {
        if (!onDiskPaths.contains(row['pdf_path'])) {
          await txn.delete('documents', where: 'id = ?', whereArgs: [row['id']]);
        }
      }
      for (final file in onDisk.where((f) => !known.contains(f.path))) {
        final stored = _files.inspect(file);
        await txn.insert('documents', {
          'id': _ids(),
          'name': stored.name,
          'search_name': normalizeSearchText(stored.name),
          'pdf_path': stored.pdfPath,
          'thumb_path': stored.thumbPath,
          'size_bytes': stored.sizeBytes,
          'page_count': stored.pageCount,
          'created_at': stored.modified.millisecondsSinceEpoch,
          'modified_at': stored.modified.millisecondsSinceEpoch,
        });
      }
    });
  }

  @override
  Future<List<ScannedDocument>> list({DocumentQuery query = const DocumentQuery()}) async {
    final db = await _ready();
    final where = <String>[];
    final args = <Object?>[];
    if (query.folderId != null) {
      where.add('folder_id = ?');
      args.add(query.folderId);
    }
    for (final token in searchTokens(query.text)) {
      where.add("(search_name LIKE ? ESCAPE '\\' OR search_content LIKE ? ESCAPE '\\')");
      final pattern = '%${_escapeLike(token)}%';
      args.addAll([pattern, pattern]);
    }
    final rows = await db.query(
      'documents',
      columns: _listColumns,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'modified_at DESC, name COLLATE NOCASE',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<ScannedDocument> createFromPages(List<ScanPage> pages, String name, {String? folderId}) async {
    final db = await _ready();
    final stored = await _files.write(name, pages);
    final now = _clock();
    final id = _ids();
    try {
      await db.insert('documents', {
        'id': id,
        'name': stored.name,
        'search_name': normalizeSearchText(stored.name),
        'pdf_path': stored.pdfPath,
        'thumb_path': stored.thumbPath,
        'size_bytes': stored.sizeBytes,
        'page_count': pages.length,
        'created_at': now.millisecondsSinceEpoch,
        'modified_at': now.millisecondsSinceEpoch,
        'folder_id': folderId,
      });
    } catch (_) {
      await _files.delete(stored.pdfPath);
      rethrow;
    }
    return ScannedDocument(
      id: id,
      pdfPath: stored.pdfPath,
      name: stored.name,
      modified: now,
      createdAt: now,
      sizeBytes: stored.sizeBytes,
      pageCount: pages.length,
      thumbPath: stored.thumbPath,
      folderId: folderId,
    );
  }

  @override
  Future<ScannedDocument> rename(ScannedDocument doc, String newName) async {
    final db = await _ready();
    final stored = await _files.rename(doc.pdfPath, newName);
    await db.update(
      'documents',
      {
        'name': stored.name,
        'search_name': normalizeSearchText(stored.name),
        'pdf_path': stored.pdfPath,
        'thumb_path': stored.thumbPath,
      },
      where: 'id = ?',
      whereArgs: [doc.id],
    );
    return doc.copyWith(
      name: stored.name,
      pdfPath: stored.pdfPath,
      thumbPath: stored.thumbPath,
      clearThumb: stored.thumbPath == null,
    );
  }

  @override
  Future<ScannedDocument> move(ScannedDocument doc, String? folderId) async {
    final db = await _ready();
    await db.update('documents', {'folder_id': folderId}, where: 'id = ?', whereArgs: [doc.id]);
    return doc.movedTo(folderId);
  }

  @override
  Future<void> delete(ScannedDocument doc) async {
    final db = await _ready();
    await db.delete('documents', where: 'id = ?', whereArgs: [doc.id]);
    await _files.delete(doc.pdfPath);
  }

  @override
  Future<void> saveText(String documentId, String text) async {
    final db = await _ready();
    await db.update(
      'documents',
      {'content_text': text, 'search_content': normalizeSearchText(text)},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  @override
  Future<String?> getText(String documentId) async {
    final db = await _ready();
    final rows = await db.query('documents', columns: ['content_text'], where: 'id = ?', whereArgs: [documentId]);
    return rows.isEmpty ? null : rows.first['content_text'] as String?;
  }

  ScannedDocument _fromRow(Map<String, Object?> row) {
    final thumb = row['thumb_path'] as String?;
    return ScannedDocument(
      id: row['id']! as String,
      name: row['name']! as String,
      pdfPath: row['pdf_path']! as String,
      thumbPath: thumb != null && File(thumb).existsSync() ? thumb : null,
      sizeBytes: row['size_bytes']! as int,
      pageCount: row['page_count']! as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      modified: DateTime.fromMillisecondsSinceEpoch(row['modified_at']! as int),
      folderId: row['folder_id'] as String?,
      hasText: row['has_text'] == 1,
    );
  }

  String _escapeLike(String text) =>
      text.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}
