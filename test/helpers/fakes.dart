import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:mi_scan/core/utils/search_text.dart';
import 'package:mi_scan/data/services/app_directories.dart';
import 'package:mi_scan/domain/entities/camera_info.dart';
import 'package:mi_scan/domain/entities/document_query.dart';
import 'package:mi_scan/domain/entities/folder.dart';
import 'package:mi_scan/domain/entities/gallery_image.dart';
import 'package:mi_scan/domain/entities/quad.dart';
import 'package:mi_scan/domain/entities/scan_filter.dart';
import 'package:mi_scan/domain/entities/scan_page.dart';
import 'package:mi_scan/domain/entities/scanned_document.dart';
import 'package:mi_scan/domain/repositories/document_repository.dart';
import 'package:mi_scan/domain/repositories/folder_repository.dart';
import 'package:mi_scan/domain/services/camera_service.dart';
import 'package:mi_scan/domain/services/gallery_service.dart';
import 'package:mi_scan/domain/services/image_processor.dart';
import 'package:mi_scan/domain/services/pdf_generator.dart';
import 'package:mi_scan/domain/services/share_service.dart';
import 'package:mi_scan/domain/services/text_recognizer.dart';

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

  Completer<void>? previewGate;
  Object? previewError;

  @override
  Future<void> applyFilter(String src, String dst, ScanFilter filter, {int maxSide = 1600}) async {
    calls.add('preview:${filter.name}');
    await previewGate?.future;
    final error = previewError;
    if (error != null) throw error;
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
  final queries = <DocumentQuery>[];
  final texts = <String, String>{};
  Object? listError;
  Object? saveTextError;
  var _next = 0;

  @override
  Future<List<ScannedDocument>> list({DocumentQuery query = const DocumentQuery()}) async {
    queries.add(query);
    final error = listError;
    if (error != null) throw error;
    final tokens = searchTokens(query.text);
    bool matches(ScannedDocument d, String token) =>
        normalizeSearchText(d.name).contains(token) || normalizeSearchText(texts[d.id] ?? '').contains(token);
    return [
      for (final d in docs)
        if ((query.folderId == null || d.folderId == query.folderId) && tokens.every((t) => matches(d, t)))
          d.withText(hasText: (texts[d.id] ?? '').isNotEmpty),
    ];
  }

  @override
  Future<ScannedDocument> createFromPages(List<ScanPage> pages, String name, {String? folderId}) async {
    final d = ScannedDocument(
      id: 'doc${_next++}',
      pdfPath: '/mem/$name.pdf',
      name: name,
      modified: DateTime(2026, 1, 1),
      sizeBytes: 2048,
      pageCount: pages.length,
      folderId: folderId,
    );
    docs.insert(0, d);
    return d;
  }

  @override
  Future<ScannedDocument> rename(ScannedDocument doc, String newName) async {
    final i = docs.indexWhere((d) => d.id == doc.id);
    final renamed = doc.copyWith(name: newName, pdfPath: '/mem/$newName.pdf');
    docs[i] = renamed;
    return renamed;
  }

  @override
  Future<ScannedDocument> move(ScannedDocument doc, String? folderId) async {
    final i = docs.indexWhere((d) => d.id == doc.id);
    final moved = doc.movedTo(folderId);
    docs[i] = moved;
    return moved;
  }

  @override
  Future<void> delete(ScannedDocument doc) async {
    docs.removeWhere((d) => d.id == doc.id);
    texts.remove(doc.id);
  }

  @override
  Future<void> saveText(String documentId, String text) async {
    final error = saveTextError;
    if (error != null) throw error;
    texts[documentId] = text;
  }

  @override
  Future<String?> getText(String documentId) async => texts[documentId];
}

class InMemoryFolderRepository implements FolderRepository {
  InMemoryFolderRepository(this.documents, [List<Folder> initial = const []]) : folders = [...initial];

  final InMemoryDocumentRepository documents;
  final List<Folder> folders;
  Object? createError;
  var _next = 0;

  @override
  Future<List<FolderSummary>> list() async => [
        for (final f in [...folders]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
          FolderSummary(f, documents.docs.where((d) => d.folderId == f.id).length),
      ];

  @override
  Future<Folder> create(String name) async {
    final error = createError;
    if (error != null) throw error;
    final folder = Folder(id: 'folder${_next++}', name: name.trim(), createdAt: DateTime(2026, 1, 1));
    folders.add(folder);
    return folder;
  }

  @override
  Future<Folder> rename(Folder folder, String newName) async {
    final i = folders.indexWhere((f) => f.id == folder.id);
    final renamed = folder.copyWith(name: newName.trim());
    folders[i] = renamed;
    return renamed;
  }

  @override
  Future<void> delete(Folder folder) async {
    folders.removeWhere((f) => f.id == folder.id);
    for (var i = 0; i < documents.docs.length; i++) {
      if (documents.docs[i].folderId == folder.id) documents.docs[i] = documents.docs[i].movedTo(null);
    }
  }
}

ScannedDocument sampleDoc(
  String name, {
  int sizeBytes = 2048,
  DateTime? modified,
  String? id,
  String? folderId,
  int pageCount = 0,
}) =>
    ScannedDocument(
      id: id ?? 'id-$name',
      pdfPath: '/mem/$name.pdf',
      name: name,
      modified: modified ?? DateTime(2026, 3, 5, 9, 7),
      sizeBytes: sizeBytes,
      folderId: folderId,
      pageCount: pageCount,
    );

class FakeCameraSession implements CameraSession {
  FakeCameraSession(this.info, {this.zoomRange = const ZoomRange(1, 8), this.photoPath = ''});

  @override
  final CameraInfo info;

  @override
  final ZoomRange zoomRange;

  final String photoPath;
  void Function()? onDispose;
  final frameController = StreamController<GrayFrame>.broadcast();
  final calls = <String>[];
  double zoom = 1;
  FlashSetting flash = FlashSetting.off;
  bool torch = false;
  bool disposed = false;
  bool streaming = false;
  int shots = 0;
  Object? takePictureError;

  @override
  double get previewAspectRatio => 0.75;

  @override
  Stream<GrayFrame> get frames => frameController.stream;

  @override
  Future<void> startFrames() async {
    streaming = true;
    calls.add('startFrames');
  }

  @override
  Future<void> stopFrames() async {
    streaming = false;
    calls.add('stopFrames');
  }

  @override
  Future<void> setZoom(double value) async {
    zoom = value;
    calls.add('zoom:$value');
  }

  @override
  Future<void> setFlash(FlashSetting value) async {
    flash = value;
    calls.add('flash:${value.name}');
  }

  @override
  Future<void> setTorch(bool enabled) async {
    torch = enabled;
    calls.add('torch:$enabled');
  }

  @override
  Future<String> takePicture() async {
    final error = takePictureError;
    if (error != null) throw error;
    calls.add('takePicture');
    final source = File(photoPath);
    if (!source.existsSync()) return photoPath;
    final copy = File('$photoPath.${++shots}')..writeAsBytesSync(source.readAsBytesSync());
    return copy.path;
  }

  @override
  Future<void> dispose() async {
    if (!disposed) onDispose?.call();
    disposed = true;
    calls.add('dispose');
    unawaited(frameController.close());
  }

  void emitFrame() => frameController.add(GrayFrame(Uint8List(4), 2, 2, 90));
}

class FakeCameraService implements CameraService {
  FakeCameraService({
    List<CameraInfo>? cameras,
    this.photoPath = '',
    this.listError,
    this.openError,
    this.zoomRanges = const {},
  }) : cameras = cameras ?? const [CameraInfo(id: 'back-wide', facing: CameraFacing.back, lens: CameraLens.wide)];

  final List<CameraInfo> cameras;
  final String photoPath;
  final Map<String, ZoomRange> zoomRanges;
  Object? listError;
  Object? openError;
  final opened = <FakeCameraSession>[];
  Completer<void>? openGate;
  int active = 0;
  int maxActive = 0;

  @override
  Future<List<CameraInfo>> listCameras() async {
    final error = listError;
    if (error != null) throw error;
    return cameras;
  }

  @override
  Future<CameraSession> open(CameraInfo camera) async {
    active++;
    if (active > maxActive) maxActive = active;
    await openGate?.future;
    final error = openError;
    if (error != null) {
      active--;
      throw error;
    }
    final session = FakeCameraSession(
      camera,
      zoomRange: zoomRanges[camera.id] ?? const ZoomRange(1, 8),
      photoPath: photoPath,
    );
    session.onDispose = () => active--;
    opened.add(session);
    return session;
  }
}

class FakeGalleryService implements GalleryService {
  FakeGalleryService({this.access = GalleryAccess.granted, int count = 5})
      : images = [for (var i = 0; i < count; i++) GalleryImage('img$i')];

  GalleryAccess access;
  final List<GalleryImage> images;
  final exported = <String>[];
  var settingsOpened = 0;
  var accessRequests = 0;
  Set<String> failExport = {};

  @override
  Future<GalleryAccess> requestAccess() async {
    accessRequests++;
    return access;
  }

  @override
  Future<List<GalleryImage>> loadPage({required int page, required int size}) async {
    final start = page * size;
    if (start >= images.length) return const [];
    return images.sublist(start, (start + size).clamp(0, images.length));
  }

  @override
  Future<Uint8List?> thumbnail(GalleryImage image, {required int size}) async => kTinyPng;

  @override
  Future<bool> exportJpeg(GalleryImage image, String destinationPath) async {
    if (failExport.contains(image.id)) return false;
    File(destinationPath).writeAsBytesSync(kTinyPng);
    exported.add(image.id);
    return true;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

class FakeTextRecognizer implements TextRecognizer {
  FakeTextRecognizer({Map<String, String>? texts, this.defaultText = ''}) : texts = texts ?? {};

  final Map<String, String> texts;
  final String defaultText;
  final recognized = <String>[];
  final failing = <String>{};
  bool failAll = false;
  Completer<void>? gate;
  var disposed = false;

  @override
  Future<RecognizedText> recognize(String imagePath) async {
    recognized.add(imagePath);
    await gate?.future;
    if (failAll || failing.contains(imagePath)) throw StateError('cannot read $imagePath');
    return RecognizedText(texts[imagePath] ?? defaultText);
  }

  @override
  Future<void> dispose() async => disposed = true;
}
