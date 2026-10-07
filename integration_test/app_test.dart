import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mi_scan/app.dart';
import 'package:mi_scan/core/di/service_locator.dart';
import 'package:mi_scan/domain/repositories/document_repository.dart';
import 'package:mi_scan/domain/repositories/folder_repository.dart';
import 'package:mi_scan/domain/services/image_processor.dart';
import 'package:mi_scan/domain/services/share_service.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:mi_scan/domain/usecases/folder_usecases.dart';
import 'package:mi_scan/presentation/home/home_controller.dart';
import 'package:mi_scan/presentation/navigation/screen_factory.dart';
import 'package:mi_scan/presentation/scanner/scan_session.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/pump_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryDocumentRepository repo;
  late InMemoryFolderRepository folderRepo;
  late FakeShareService share;
  late File photo;

  setUp(() async {
    await sl.reset();
    photo = File('${Directory.systemTemp.createTempSync('it_photo_').path}/photo.png')..writeAsBytesSync(kTinyPng);
    repo = InMemoryDocumentRepository([sampleDoc('Contract')]);
    folderRepo = InMemoryFolderRepository(repo);
    share = FakeShareService();
    final processor = FakeImageProcessor();
    sl
      ..registerSingleton<DocumentRepository>(repo)
      ..registerSingleton<ShareService>(share)
      ..registerSingleton<ImageProcessor>(processor)
      ..registerSingleton(ListDocuments(repo))
      ..registerSingleton(RenameDocument(repo))
      ..registerSingleton(MoveDocument(repo))
      ..registerSingleton(DeleteDocument(repo))
      ..registerSingleton(CreateDocument(repo))
      ..registerSingleton<FolderRepository>(folderRepo)
      ..registerSingleton(ListFolders(folderRepo))
      ..registerSingleton(CreateFolder(folderRepo))
      ..registerSingleton(RenameFolder(folderRepo))
      ..registerSingleton(DeleteFolder(folderRepo))
      ..registerFactory(() => HomeController(
            listDocuments: sl(),
            renameDocument: sl(),
            moveDocument: sl(),
            deleteDocument: sl(),
            listFolders: sl(),
            createFolder: sl(),
            renameFolder: sl(),
            deleteFolder: sl(),
            shareService: sl(),
          ))
      ..registerSingleton<ScanSessionFactory>(() async => ScanSession(
            dir: Directory.systemTemp.createTempSync('it_').path,
            imageProcessor: processor,
            createDocument: sl(),
          ))
      ..registerSingleton<ScreenFactory>(fakeScreenFactory(camera: FakeCameraService(photoPath: photo.path)));
  });

  tearDown(sl.reset);

  testWidgets('list, rename, share and delete a document', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const MiScanApp());
    await tester.pumpAndSettle();
    expect(find.text('Contract'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Signed contract');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Signed contract'), findsOneWidget);

    await tester.tap(find.text('Signed contract'));
    await tester.pumpAndSettle();
    expect(share.shared, ['/mem/Signed contract.pdf']);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You have no documents yet'), findsOneWidget);
  });

  testWidgets('open the scanner and discard with the close button', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const MiScanApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('scan_fab')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets('scan several photos in batch mode, adjust each one and save them as a PDF', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const MiScanApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('scan_fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mode_batch')));
    await tester.pump();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const Key('shutter')));
      await tester.pumpAndSettle();
    }
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('batch_done')));
    await tester.pumpAndSettle();
    expect(find.text('Adjust edges (1/2)'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Adjust edges (2/2)'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Batch scan');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.docs.first.name, 'Batch scan');
    expect(share.shared, ['/mem/Batch scan.pdf']);
    expect(find.text('Batch scan'), findsOneWidget);
  });

  testWidgets('organize documents: create a folder, move a document into it and search', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const MiScanApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('folder_new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Work');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Work (0)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('folder_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('move_${folderRepo.folders.single.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Work (1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('search_field')), 'contr');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Contract'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search_field')), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Contract'), findsNothing);
    expect(find.text('No documents match "zzz".'), findsOneWidget);
  });
}
