import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/formatters.dart';
import '../../domain/entities/quad.dart';
import '../../domain/entities/scan_filter.dart';
import '../../domain/entities/scan_page.dart';
import '../../domain/entities/scanned_document.dart';
import '../../domain/services/image_processor.dart';
import '../../domain/usecases/document_usecases.dart';

typedef ScanSessionFactory = Future<ScanSession> Function();

class ScanSession extends ChangeNotifier {
  ScanSession({
    required this.dir,
    required ImageProcessor imageProcessor,
    required this._createDocument,
  }) : _processor = imageProcessor;

  final String dir;
  final ImageProcessor _processor;
  final CreateDocument _createDocument;
  final List<ScanPage> _pages = [];
  final List<String> _shots = [];

  List<ScanPage> get pages => List.unmodifiable(_pages);

  List<String> get shots => List.unmodifiable(_shots);

  int get pendingCount => _pages.length + _shots.length;

  void add(ScanPage page) {
    _pages.add(page);
    notifyListeners();
  }

  void removeAt(int i) {
    silentDelete(_pages.removeAt(i).path);
    notifyListeners();
  }

  void move(int from, int to) {
    _pages.insert(to, _pages.removeAt(from));
    notifyListeners();
  }

  Future<void> rotate(int i) async {
    final size = await _processor.rotate(_pages[i].path);
    _pages[i] = _pages[i].copyWith(width: size.width, height: size.height);
    await FileImage(File(_pages[i].path)).evict();
    notifyListeners();
  }

  Future<Quad?> detectLive(GrayFrame frame) => _processor.detectInFrame(frame);

  Future<Quad?> detectInFile(String path) => _processor.detectInFile(path);

  Future<String> importSource(String sourcePath) async {
    final tmp = p.join(dir, 'src_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await _processor.normalize(sourcePath, tmp);
    return tmp;
  }

  Future<ScanPage> cropPage(String src, Quad quad, ScanFilter filter) async {
    final dst = p.join(dir, 'page_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await _processor.crop(src, dst, quad, filter);
    final size = await _processor.normalize(dst, dst);
    return ScanPage(dst, size.width, size.height);
  }

  Future<String> addShot(String photoPath) async {
    final stored = await importSource(photoPath);
    _shots.add(stored);
    notifyListeners();
    return stored;
  }

  List<String> takeShots() {
    final taken = List<String>.of(_shots);
    _shots.clear();
    notifyListeners();
    return taken;
  }

  Future<ScannedDocument> saveAsPdf(String name) => _createDocument(_pages, name);

  void disposeFiles() {
    try {
      Directory(dir).deleteSync(recursive: true);
    } catch (_) {}
  }
}
