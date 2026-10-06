import 'dart:io';
import 'dart:typed_data';

import 'package:mi_scan/data/services/app_directories.dart';
import 'package:mi_scan/domain/entities/quad.dart';
import 'package:mi_scan/domain/entities/scan_filter.dart';
import 'package:mi_scan/domain/entities/scan_page.dart';
import 'package:mi_scan/domain/entities/scanned_document.dart';
import 'package:mi_scan/domain/repositories/document_repository.dart';
import 'package:mi_scan/domain/services/image_processor.dart';
import 'package:mi_scan/domain/services/pdf_generator.dart';
import 'package:mi_scan/domain/services/share_service.dart';

final Uint8List kTinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class FakeAppDirectories implements AppDirectories {
  FakeAppDirectories(this.root);
  final Directory root;

  @override
  Future<Directory> documents() async => Directory('${root.path}/docs')..createSync(recursive: true);

  @override
  Future<Directory> temp() async => Directory('${root.path}/tmp')..createSync(recursive: true);
}

class FakePdfGenerator implements PdfGenerator {
  List<ScanPage>? lastPages;

  @override
  Future<Uint8List> generate(List<ScanPage> pages) async {
    lastPages = pages;
    return Uint8List.fromList('%PDF-fake'.codeUnits);
  }
}

class FakeThumbnailGenerator implements ThumbnailGenerator {
  @override
  Future<Uint8List> generate(String imagePath) async => Uint8List.fromList([1, 2, 3]);
}

class FakeShareService implements ShareService {
  final shared = <String>[];

  @override
  Future<void> sharePdf(String path, {String? subject}) async => shared.add(path);
}

class FakeImageProcessor implements ImageProcessor {
  Quad? detected;
  ImageSize size = const ImageSize(800, 1000);
  final calls = <String>[];

  @override
  Future<Quad?> detectInFrame(GrayFrame frame) async => detected;

  @override
  Future<Quad?> detectInFile(String path) async => detected;

  @override
  Future<ImageSize> normalize(String src, String dst) async {
    calls.add('normalize');
    if (src != dst) File(src).copySync(dst);
    return size;
  }

  @override
  Future<void> crop(String src, String dst, Quad quad, ScanFilter filter) async {
    calls.add('crop:${filter.name}');
    File(src).copySync(dst);
  }

  @override
  Future<ImageSize> rotate(String path) async {
    calls.add('rotate');
    return ImageSize(size.height, size.width);
  }
}

class InMemoryDocumentRepository implements DocumentRepository {
  InMemoryDocumentRepository([List<ScannedDocument> initial = const []]) : docs = [...initial];
  final List<ScannedDocument> docs;

  @override
  Future<List<ScannedDocument>> list() async => [...docs];

  @override
  Future<ScannedDocument> createFromPages(List<ScanPage> pages, String name) async {
    final d = ScannedDocument(pdfPath: '/mem/$name.pdf', name: name, modified: DateTime(2026, 1, 1), sizeBytes: 2048);
    docs.insert(0, d);
    return d;
  }

  @override
  Future<ScannedDocument> rename(ScannedDocument doc, String newName) async {
    final i = docs.indexOf(doc);
    final d = ScannedDocument(
        pdfPath: '/mem/$newName.pdf', name: newName, modified: doc.modified, sizeBytes: doc.sizeBytes);
    docs[i] = d;
    return d;
  }

  @override
  Future<void> delete(ScannedDocument doc) async => docs.remove(doc);
}

ScannedDocument sampleDoc(String name, {int sizeBytes = 2048, DateTime? modified}) => ScannedDocument(
      pdfPath: '/mem/$name.pdf',
      name: name,
      modified: modified ?? DateTime(2026, 3, 5, 9, 7),
      sizeBytes: sizeBytes,
    );
