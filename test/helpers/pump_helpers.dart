import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/core/l10n/l10n.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:mi_scan/domain/usecases/folder_usecases.dart';
import 'package:mi_scan/presentation/gallery/gallery_controller.dart';
import 'package:mi_scan/presentation/home/home_controller.dart';
import 'package:mi_scan/presentation/navigation/screen_factory.dart';
import 'package:mi_scan/presentation/scanner/scan_session.dart';
import 'package:mi_scan/presentation/scanner/scanner_controller.dart';

import 'fakes.dart';

Widget localizedApp(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

Future<void> pumpApp(WidgetTester tester, Widget home, {Locale locale = const Locale('en')}) =>
    tester.pumpWidget(localizedApp(home, locale: locale));

ScanSession buildSession(Directory dir, {FakeImageProcessor? processor, InMemoryDocumentRepository? repo}) =>
    ScanSession(
      dir: dir.path,
      imageProcessor: processor ?? FakeImageProcessor(),
      createDocument: CreateDocument(repo ?? InMemoryDocumentRepository()),
    );

ScreenFactory fakeScreenFactory({
  FakeCameraService? camera,
  FakeGalleryService? gallery,
  FakeImageProcessor? processor,
  InMemoryDocumentRepository? repository,
}) {
  final cameraService = camera ?? FakeCameraService();
  final galleryService = gallery ?? FakeGalleryService();
  return ScreenFactory(
    scannerController: (session) => ScannerController(cameraService: cameraService, session: session),
    galleryController: (directory) => GalleryController(service: galleryService, directory: directory),
    previewBuilder: (_) => const ColoredBox(key: Key('preview'), color: Colors.grey),
  );
}

void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

HomeController makeHomeController({
  InMemoryDocumentRepository? documents,
  InMemoryFolderRepository? folders,
  FakeShareService? share,
  FakeTextRecognizer? recognizer,
  Duration searchDebounce = const Duration(milliseconds: 10),
}) {
  final docs = documents ?? InMemoryDocumentRepository();
  final folderRepo = folders ?? InMemoryFolderRepository(docs);
  return HomeController(
    listDocuments: ListDocuments(docs),
    renameDocument: RenameDocument(docs),
    moveDocument: MoveDocument(docs),
    deleteDocument: DeleteDocument(docs),
    listFolders: ListFolders(folderRepo),
    createFolder: CreateFolder(folderRepo),
    renameFolder: RenameFolder(folderRepo),
    deleteFolder: DeleteFolder(folderRepo),
    recognizeText: RecognizeDocumentText(recognizer ?? FakeTextRecognizer(), docs),
    getText: GetDocumentText(docs),
    shareService: share ?? FakeShareService(),
    searchDebounce: searchDebounce,
  );
}
