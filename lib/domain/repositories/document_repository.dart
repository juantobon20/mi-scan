import '../entities/document_query.dart';
import '../entities/scan_page.dart';
import '../entities/scanned_document.dart';

abstract interface class DocumentRepository {
  Future<List<ScannedDocument>> list({DocumentQuery query = const DocumentQuery()});

  Future<ScannedDocument> createFromPages(List<ScanPage> pages, String name, {String? folderId});

  Future<ScannedDocument> rename(ScannedDocument doc, String newName);

  Future<ScannedDocument> move(ScannedDocument doc, String? folderId);

  Future<void> delete(ScannedDocument doc);

  Future<void> saveText(String documentId, String text);

  Future<String?> getText(String documentId);
}
