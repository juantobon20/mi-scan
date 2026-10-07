import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/gallery_image.dart';
import '../../domain/services/gallery_service.dart';

enum GalleryStatus { loading, denied, ready }

class GalleryController extends ChangeNotifier {
  GalleryController({required this._service, required this.directory, this.pageSize = 90});

  final GalleryService _service;
  final String directory;
  final int pageSize;

  final List<GalleryImage> _images = [];
  final List<GalleryImage> _selected = [];
  final Map<GalleryImage, Future<Uint8List?>> _thumbnails = {};
  GalleryStatus _status = GalleryStatus.loading;
  bool _hasMore = true;
  bool _loadingPage = false;
  bool _working = false;
  bool _disposed = false;
  int _page = 0;

  List<GalleryImage> get images => List.unmodifiable(_images);
  List<GalleryImage> get selected => List.unmodifiable(_selected);
  GalleryStatus get status => _status;
  bool get working => _working;
  int get selectedCount => _selected.length;

  Future<void> initialize() async {
    _images.clear();
    _selected.clear();
    _thumbnails.clear();
    _page = 0;
    _hasMore = true;
    _status = GalleryStatus.loading;
    _notify();
    final access = await _service.requestAccess();
    if (access == GalleryAccess.denied) {
      _status = GalleryStatus.denied;
      _notify();
      return;
    }
    await loadMore();
    _status = GalleryStatus.ready;
    _notify();
  }

  Future<void> loadMore() async {
    if (_loadingPage || !_hasMore) return;
    _loadingPage = true;
    try {
      final next = await _service.loadPage(page: _page, size: pageSize);
      _images.addAll(next);
      _page++;
      _hasMore = next.length == pageSize;
    } finally {
      _loadingPage = false;
    }
    _notify();
  }

  int selectionIndex(GalleryImage image) => _selected.indexOf(image);

  void toggle(GalleryImage image) {
    if (!_selected.remove(image)) _selected.add(image);
    _notify();
  }

  Future<Uint8List?> thumbnail(GalleryImage image) =>
      _thumbnails.putIfAbsent(image, () => _service.thumbnail(image, size: 300));

  Future<List<String>> confirm() async {
    _working = true;
    _notify();
    final paths = <String>[];
    try {
      for (final image in _selected) {
        final path = p.join(directory, 'gal_${DateTime.now().microsecondsSinceEpoch}.jpg');
        if (await _service.exportJpeg(image, path)) paths.add(path);
      }
    } finally {
      _working = false;
      _notify();
    }
    return paths;
  }

  Future<void> openSettings() => _service.openSettings();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
