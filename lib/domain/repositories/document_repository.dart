import '../entities/scan_page.dart';
import '../entities/scanned_document.dart';

abstract interface class DocumentRepository {
  Future<List<ScannedDocument>> list();

  Future<ScannedDocument> createFromPages(List<ScanPage> pages, String name);

  Future<ScannedDocument> rename(ScannedDocument doc, String newName);

  Future<void> delete(ScannedDocument doc);
}
