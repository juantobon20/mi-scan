import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mi_scan/app.dart';
import 'package:mi_scan/core/di/service_locator.dart';
import 'package:mi_scan/domain/repositories/document_repository.dart';
import 'package:mi_scan/domain/services/image_processor.dart';
import 'package:mi_scan/domain/services/share_service.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:mi_scan/presentation/home/home_controller.dart';
import 'package:mi_scan/presentation/scanner/scan_session.dart';

import '../test/helpers/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryDocumentRepository repo;
  late FakeShareService share;

  setUp(() async {
    await sl.reset();
    repo = InMemoryDocumentRepository([sampleDoc('Contract')]);
    share = FakeShareService();
    final processor = FakeImageProcessor();
    sl
      ..registerSingleton<DocumentRepository>(repo)
      ..registerSingleton<ShareService>(share)
      ..registerSingleton<ImageProcessor>(processor)
      ..registerSingleton(ListDocuments(repo))
      ..registerSingleton(RenameDocument(repo))
      ..registerSingleton(DeleteDocument(repo))
      ..registerSingleton(CreateDocument(repo))
      ..registerFactory(() => HomeController(
            listDocuments: sl(),
            renameDocument: sl(),
            deleteDocument: sl(),
            shareService: sl(),
          ))
      ..registerSingleton<ScanSessionFactory>(() async => ScanSession(
            dir: Directory.systemTemp.createTempSync('it_').path,
            imageProcessor: processor,
            createDocument: sl(),
          ));
  });

  tearDown(sl.reset);

  testWidgets('list, rename, share and delete a document', (tester) async {
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
}
