import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/formatters.dart';
import '../../domain/entities/scan_page.dart';
import '../../domain/entities/scanned_document.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/services/pdf_generator.dart';
import '../services/app_directories.dart';

class FileDocumentRepository implements DocumentRepository {
  FileDocumentRepository({
    required AppDirectories directories,
    required PdfGenerator pdfGenerator,
    required ThumbnailGenerator thumbnailGenerator,
  })  : _dirs = directories,
        _pdf = pdfGenerator,
        _thumbs = thumbnailGenerator;

  final AppDirectories _dirs;
  final PdfGenerator _pdf;
  final ThumbnailGenerator _thumbs;

  Future<Directory> _pdfDir() async {
    final base = await _dirs.documents();
    return Directory(p.join(base.path, 'pdfs'))..createSync(recursive: true);
  }

  ScannedDocument _toDoc(File pdf) {
    final thumb = File('${pdf.path}.jpg');
    final stat = pdf.statSync();
    return ScannedDocument(
      pdfPath: pdf.path,
      name: p.basenameWithoutExtension(pdf.path),
      modified: stat.modified,
      sizeBytes: stat.size,
      thumbPath: thumb.existsSync() ? thumb.path : null,
    );
  }

  @override
  Future<List<ScannedDocument>> list() async {
    final dir = await _pdfDir();
    return [
      for (final f in dir.listSync().whereType<File>())
        if (f.path.endsWith('.pdf')) _toDoc(f),
    ]..sort((a, b) => b.modified.compareTo(a.modified));
  }

  @override
  Future<void> delete(ScannedDocument doc) async {
    for (final path in [doc.pdfPath, '${doc.pdfPath}.jpg']) {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    }
  }

  @override
  Future<ScannedDocument> rename(ScannedDocument doc, String newName) async {
    final dir = await _pdfDir();
    final name = _uniqueName(dir, newName, ignore: doc.pdfPath);
    final pdf = await File(doc.pdfPath).rename(p.join(dir.path, '$name.pdf'));
    final oldThumb = File('${doc.pdfPath}.jpg');
    if (oldThumb.existsSync()) await oldThumb.rename('${pdf.path}.jpg');
    return _toDoc(pdf);
  }

  @override
  Future<ScannedDocument> createFromPages(List<ScanPage> pages, String name) async {
    final dir = await _pdfDir();
    final file = File(p.join(dir.path, '${_uniqueName(dir, name)}.pdf'));
    await file.writeAsBytes(await _pdf.generate(pages));
    await File('${file.path}.jpg').writeAsBytes(await _thumbs.generate(pages.first.path));
    return _toDoc(file);
  }

  String _uniqueName(Directory dir, String name, {String? ignore}) {
    final base = sanitizeFileName(name);
    var candidate = base, i = 2;
    bool taken(String c) {
      final path = p.join(dir.path, '$c.pdf');
      return File(path).existsSync() && path != ignore;
    }

    while (taken(candidate)) {
      candidate = '$base ($i)';
      i++;
    }
    return candidate;
  }
}
