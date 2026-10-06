import '../entities/scan_page.dart';
import '../entities/scanned_document.dart';
import '../repositories/document_repository.dart';

class ListDocuments {
  ListDocuments(this._repo);
  final DocumentRepository _repo;
  Future<List<ScannedDocument>> call() => _repo.list();
}

class CreateDocument {
  CreateDocument(this._repo);
  final DocumentRepository _repo;

  Future<ScannedDocument> call(List<ScanPage> pages, String name) {
    if (pages.isEmpty) throw ArgumentError('At least one page is required');
    return _repo.createFromPages(pages, name);
  }
}

class RenameDocument {
  RenameDocument(this._repo);
  final DocumentRepository _repo;
  Future<ScannedDocument> call(ScannedDocument doc, String name) => _repo.rename(doc, name);
}

class DeleteDocument {
  DeleteDocument(this._repo);
  final DocumentRepository _repo;
  Future<void> call(ScannedDocument doc) => _repo.delete(doc);
}
