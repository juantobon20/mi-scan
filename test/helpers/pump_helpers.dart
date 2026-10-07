import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/core/l10n/l10n.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:mi_scan/presentation/gallery/gallery_controller.dart';
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
