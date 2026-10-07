import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/document_query.dart';
import '../../domain/entities/folder.dart';
import '../../domain/entities/scan_page.dart';
import '../../domain/entities/scanned_document.dart';
import '../../domain/services/share_service.dart';
import '../../domain/usecases/document_usecases.dart';
import '../../domain/usecases/folder_usecases.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    required ListDocuments listDocuments,
    required RenameDocument renameDocument,
    required MoveDocument moveDocument,
    required DeleteDocument deleteDocument,
    required this._listFolders,
    required this._createFolder,
    required this._renameFolder,
    required this._deleteFolder,
    required this._recognizeText,
    required this._getText,
    required ShareService shareService,
    this.searchDebounce = const Duration(milliseconds: 250),
  })  : _list = listDocuments,
        _rename = renameDocument,
        _move = moveDocument,
        _delete = deleteDocument,
        _share = shareService;

  final Duration searchDebounce;
  final ListDocuments _list;
  final RenameDocument _rename;
  final MoveDocument _move;
  final DeleteDocument _delete;
  final ListFolders _listFolders;
  final CreateFolder _createFolder;
  final RenameFolder _renameFolder;
  final DeleteFolder _deleteFolder;
  final RecognizeDocumentText _recognizeText;
  final GetDocumentText _getText;
  final ShareService _share;

  List<ScannedDocument>? _documents;
  List<FolderSummary> _folders = const [];
  DocumentQuery _query = const DocumentQuery();
  Object? _error;
  final Set<String> _recognizing = {};
  Timer? _debounce;
  int _request = 0;
  bool _disposed = false;

  List<ScannedDocument>? get documents => _documents;
  List<FolderSummary> get folders => List.unmodifiable(_folders);
  DocumentQuery get query => _query;
  String? get selectedFolderId => _query.folderId;
  String get searchText => _query.text;
  bool get isSearching => _query.hasText;
  Object? get error => _error;
  Set<String> get recognizingIds => Set.unmodifiable(_recognizing);
  bool isRecognizing(ScannedDocument doc) => _recognizing.contains(doc.id);

  Folder? get selectedFolder {
    final id = _query.folderId;
    if (id == null) return null;
    for (final summary in _folders) {
      if (summary.folder.id == id) return summary.folder;
    }
    return null;
  }

  Future<void> load() async {
    final request = ++_request;
    try {
      final results = await Future.wait([_listFolders(), _list(query: _query)]);
      if (request != _request) return;
      _folders = results[0] as List<FolderSummary>;
      _documents = results[1] as List<ScannedDocument>;
      _error = null;
      if (_query.folderId != null && selectedFolder == null) {
        _query = _query.copyWith(clearFolder: true);
        _documents = await _list(query: _query);
        if (request != _request) return;
      }
    } catch (e) {
      if (request != _request) return;
      _error = e;
      _documents ??= const [];
    }
    _notify();
  }

  Future<void> selectFolder(String? folderId) {
    _query = folderId == null ? _query.copyWith(clearFolder: true) : _query.copyWith(folderId: folderId);
    _notify();
    return load();
  }

  void setSearchText(String text) {
    if (text == _query.text) return;
    _query = _query.copyWith(text: text);
    _notify();
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, load);
  }

  Future<void> clearSearch() {
    _debounce?.cancel();
    if (_query.text.isEmpty) return Future.value();
    _query = _query.copyWith(text: '');
    _notify();
    return load();
  }

  Future<Folder> createFolder(String name) async {
    final folder = await _createFolder(name);
    await load();
    return folder;
  }

  Future<void> renameFolder(Folder folder, String name) async {
    await _renameFolder(folder, name);
    await load();
  }

  Future<void> deleteFolder(Folder folder) async {
    await _deleteFolder(folder);
    if (_query.folderId == folder.id) _query = _query.copyWith(clearFolder: true);
    await load();
  }

  Future<void> rename(ScannedDocument doc, String name) async {
    await _rename(doc, name);
    await load();
  }

  Future<void> moveDocument(ScannedDocument doc, String? folderId) async {
    await _move(doc, folderId);
    await load();
  }

  Future<void> delete(ScannedDocument doc) async {
    await _delete(doc);
    await load();
  }

  Future<ScannedDocument> onDocumentScanned(ScannedDocument doc) async {
    final folderId = _query.folderId;
    final stored = folderId == null ? doc : await _move(doc, folderId);
    await load();
    return stored;
  }

  Future<OcrOutcome> recognizeText(ScannedDocument doc, List<ScanPage> pages) async {
    _recognizing.add(doc.id);
    _notify();
    try {
      return await _recognizeText(doc, pages);
    } catch (_) {
      return OcrOutcome(recognizedPages: 0, failedPages: pages.length, hasText: false);
    } finally {
      _recognizing.remove(doc.id);
      await load();
    }
  }

  Future<String?> loadText(ScannedDocument doc) => _getText(doc);

  Future<void> share(ScannedDocument doc) => _share.sharePdf(doc.pdfPath, subject: doc.name);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
