import '../entities/document_query.dart';
import '../entities/scan_page.dart';
import '../entities/scanned_document.dart';
import '../repositories/document_repository.dart';

class ListDocuments {
  ListDocuments(this._repo);
  final DocumentRepository _repo;
  Future<List<ScannedDocument>> call({DocumentQuery query = const DocumentQuery()}) => _repo.list(query: query);
}

class CreateDocument {
  CreateDocument(this._repo);
  final DocumentRepository _repo;

  Future<ScannedDocument> call(List<ScanPage> pages, String name, {String? folderId}) {
    if (pages.isEmpty) throw ArgumentError('At least one page is required');
    return _repo.createFromPages(pages, name, folderId: folderId);
  }
}

class RenameDocument {
  RenameDocument(this._repo);
  final DocumentRepository _repo;
  Future<ScannedDocument> call(ScannedDocument doc, String name) => _repo.rename(doc, name);
}

class MoveDocument {
  MoveDocument(this._repo);
  final DocumentRepository _repo;
  Future<ScannedDocument> call(ScannedDocument doc, String? folderId) =>
      doc.folderId == folderId ? Future.value(doc) : _repo.move(doc, folderId);
}

class DeleteDocument {
  DeleteDocument(this._repo);
  final DocumentRepository _repo;
  Future<void> call(ScannedDocument doc) => _repo.delete(doc);
}
