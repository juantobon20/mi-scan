import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/formatters.dart';
import '../../domain/entities/scan_page.dart';
import '../../domain/services/pdf_generator.dart';
import '../services/app_directories.dart';
import 'pdf_page_counter.dart';

class StoredDocument {
  const StoredDocument({
    required this.pdfPath,
    required this.name,
    required this.sizeBytes,
    required this.pageCount,
    required this.modified,
    this.thumbPath,
  });

  final String pdfPath;
  final String name;
  final String? thumbPath;
  final int sizeBytes;
  final int pageCount;
  final DateTime modified;
}

class DocumentFiles {
  DocumentFiles({
    required AppDirectories directories,
    required PdfGenerator pdfGenerator,
    required ThumbnailGenerator thumbnailGenerator,
  })  : _dirs = directories,
        _pdf = pdfGenerator,
        _thumbs = thumbnailGenerator;

  final AppDirectories _dirs;
  final PdfGenerator _pdf;
  final ThumbnailGenerator _thumbs;

  Future<Directory> _dir() async {
    final base = await _dirs.documents();
    return Directory(p.join(base.path, 'pdfs'))..createSync(recursive: true);
  }

  Future<List<File>> listPdfs() async {
    final dir = await _dir();
    return [
      for (final f in dir.listSync().whereType<File>())
        if (f.path.endsWith('.pdf')) f,
    ];
  }

  StoredDocument inspect(File pdf) {
    final stat = pdf.statSync();
    final thumb = File('${pdf.path}.jpg');
    return StoredDocument(
      pdfPath: pdf.path,
      name: p.basenameWithoutExtension(pdf.path),
      sizeBytes: stat.size,
      pageCount: countPdfPages(pdf.readAsBytesSync()),
      modified: stat.modified,
      thumbPath: thumb.existsSync() ? thumb.path : null,
    );
  }

  Future<StoredDocument> write(String name, List<ScanPage> pages) async {
    final dir = await _dir();
    final file = File(p.join(dir.path, '${_uniqueName(dir, name)}.pdf'));
    await file.writeAsBytes(await _pdf.generate(pages));
    await File('${file.path}.jpg').writeAsBytes(await _thumbs.generate(pages.first.path));
    return inspect(file);
  }

  Future<StoredDocument> rename(String pdfPath, String newName) async {
    final dir = await _dir();
    final name = _uniqueName(dir, newName, ignore: pdfPath);
    final pdf = await File(pdfPath).rename(p.join(dir.path, '$name.pdf'));
    final oldThumb = File('$pdfPath.jpg');
    if (oldThumb.existsSync()) await oldThumb.rename('${pdf.path}.jpg');
    return inspect(pdf);
  }

  Future<void> delete(String pdfPath) async {
    for (final path in [pdfPath, '$pdfPath.jpg']) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }
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
