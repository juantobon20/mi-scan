import '../entities/document_query.dart';
import '../entities/scan_page.dart';
import '../entities/scanned_document.dart';
import '../repositories/document_repository.dart';
import '../services/text_recognizer.dart';

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

class OcrOutcome {
  const OcrOutcome({required this.recognizedPages, required this.failedPages, required this.hasText});

  final int recognizedPages;
  final int failedPages;
  final bool hasText;
}

class RecognizeDocumentText {
  RecognizeDocumentText(this._recognizer, this._repo);
  final TextRecognizer _recognizer;
  final DocumentRepository _repo;

  Future<OcrOutcome> call(ScannedDocument doc, List<ScanPage> pages) async {
    final texts = <String>[];
    var failed = 0;
    for (final page in pages) {
      try {
        final result = await _recognizer.recognize(page.path);
        if (!result.isEmpty) texts.add(result.text.trim());
      } catch (_) {
        failed++;
      }
    }
    final text = texts.join('\n\n');
    if (text.isNotEmpty) await _repo.saveText(doc.id, text);
    return OcrOutcome(recognizedPages: pages.length - failed, failedPages: failed, hasText: text.isNotEmpty);
  }
}

class GetDocumentText {
  GetDocumentText(this._repo);
  final DocumentRepository _repo;
  Future<String?> call(ScannedDocument doc) => _repo.getText(doc.id);
}
