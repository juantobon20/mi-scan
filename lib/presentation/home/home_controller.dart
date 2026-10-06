import 'package:flutter/foundation.dart';

import '../../domain/entities/scanned_document.dart';
import '../../domain/services/share_service.dart';
import '../../domain/usecases/document_usecases.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    required ListDocuments listDocuments,
    required RenameDocument renameDocument,
    required DeleteDocument deleteDocument,
    required ShareService shareService,
  })  : _list = listDocuments,
        _rename = renameDocument,
        _delete = deleteDocument,
        _share = shareService;

  final ListDocuments _list;
  final RenameDocument _rename;
  final DeleteDocument _delete;
  final ShareService _share;

  List<ScannedDocument>? _documents;
  Object? _error;
  bool _disposed = false;

  List<ScannedDocument>? get documents => _documents;
  Object? get error => _error;

  Future<void> load() async {
    try {
      _documents = await _list();
      _error = null;
    } catch (e) {
      _error = e;
      _documents ??= const [];
    }
    _notify();
  }

  Future<void> rename(ScannedDocument doc, String name) async {
    await _rename(doc, name);
    await load();
  }

  Future<void> delete(ScannedDocument doc) async {
    await _delete(doc);
    await load();
  }

  Future<void> share(ScannedDocument doc) => _share.sharePdf(doc.pdfPath, subject: doc.name);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
