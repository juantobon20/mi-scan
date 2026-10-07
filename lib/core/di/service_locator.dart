import 'package:get_it/get_it.dart';

import '../../data/repositories/file_document_repository.dart';
import '../../data/services/app_directories.dart';
import '../../data/services/camera/plugin_camera_service.dart';
import '../../data/services/file_session_storage.dart';
import '../../data/services/opencv_image_processor.dart';
import '../../data/services/pdf_services.dart';
import '../../data/services/photo_manager_gallery_service.dart';
import '../../data/services/share_plus_service.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/services/camera_service.dart';
import '../../domain/services/gallery_service.dart';
import '../../domain/services/image_processor.dart';
import '../../domain/services/pdf_generator.dart';
import '../../domain/services/share_service.dart';
import '../../domain/usecases/document_usecases.dart';
import '../../presentation/gallery/gallery_controller.dart';
import '../../presentation/home/home_controller.dart';
import '../../presentation/navigation/screen_factory.dart';
import '../../presentation/scanner/scan_session.dart';
import '../../presentation/scanner/scanner_controller.dart';

final GetIt sl = GetIt.instance;

void configureDependencies() {
  sl
    ..registerLazySingleton<AppDirectories>(PathProviderDirectories.new)
    ..registerLazySingleton<ImageProcessor>(OpenCvImageProcessor.new)
    ..registerLazySingleton<PdfGenerator>(PdfPackageGenerator.new)
    ..registerLazySingleton<ThumbnailGenerator>(UiThumbnailGenerator.new)
    ..registerLazySingleton<ShareService>(SharePlusService.new)
    ..registerLazySingleton<CameraService>(PluginCameraService.new)
    ..registerFactory<GalleryService>(PhotoManagerGalleryService.new)
    ..registerLazySingleton<SessionStorage>(() => FileSessionStorage(sl()))
    ..registerLazySingleton<DocumentRepository>(
      () => FileDocumentRepository(directories: sl(), pdfGenerator: sl(), thumbnailGenerator: sl()),
    )
    ..registerLazySingleton(() => ListDocuments(sl()))
    ..registerLazySingleton(() => CreateDocument(sl()))
    ..registerLazySingleton(() => RenameDocument(sl()))
    ..registerLazySingleton(() => DeleteDocument(sl()))
    ..registerFactory(
      () => HomeController(
        listDocuments: sl(),
        renameDocument: sl(),
        deleteDocument: sl(),
        shareService: sl(),
      ),
    )
    ..registerLazySingleton<ScanSessionFactory>(
      () => () async => ScanSession(
            dir: await sl<SessionStorage>().createSessionDir(),
            imageProcessor: sl(),
            createDocument: sl(),
          ),
    )
    ..registerLazySingleton<ScreenFactory>(
      () => ScreenFactory(
        scannerController: (session) => ScannerController(cameraService: sl(), session: session),
        galleryController: (directory) => GalleryController(service: sl(), directory: directory),
        previewBuilder: buildCameraPreview,
      ),
    );
}
