import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/scanned_document.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:mi_scan/presentation/home/home_controller.dart';
import 'package:mi_scan/presentation/home/home_screen.dart';
import 'package:mi_scan/presentation/scanner/scan_session.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_helpers.dart';

void main() {
  late InMemoryDocumentRepository repo;
  late FakeShareService share;
  late HomeController ctrl;
  var sessionsStarted = 0;

  Future<ScanSession> startSession() async {
    sessionsStarted++;
    return buildSession(Directory.systemTemp.createTempSync('home_test_'));
  }

  Future<void> pumpHome(WidgetTester tester, [List docs = const []]) async {
    repo = InMemoryDocumentRepository([for (final d in docs) d]);
    share = FakeShareService();
    ctrl = HomeController(
      listDocuments: ListDocuments(repo),
      renameDocument: RenameDocument(repo),
      deleteDocument: DeleteDocument(repo),
      shareService: share,
    );
    await pumpApp(tester, HomeScreen(controller: ctrl, startSession: startSession));
    await tester.pumpAndSettle();
  }

  setUp(() => sessionsStarted = 0);

  testWidgets('shows the title and the empty state', (tester) async {
    await pumpHome(tester);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.textContaining('You have no documents yet'), findsOneWidget);
    expect(find.byKey(const Key('scan_fab')), findsOneWidget);
  });

  testWidgets('shows an indicator while loading', (tester) async {
    repo = InMemoryDocumentRepository();
    ctrl = HomeController(
      listDocuments: ListDocuments(repo),
      renameDocument: RenameDocument(repo),
      deleteDocument: DeleteDocument(repo),
      shareService: FakeShareService(),
    );
    await pumpApp(tester, HomeScreen(controller: ctrl, startSession: startSession));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('lists documents with name, date and size', (tester) async {
    await pumpHome(tester, [sampleDoc('Contract'), sampleDoc('Receipt', sizeBytes: 5 * 1024 * 1024)]);
    expect(find.text('Contract'), findsOneWidget);
    expect(find.text('3/5/2026 09:07 · 2 KB'), findsOneWidget);
    expect(find.text('3/5/2026 09:07 · 5.0 MB'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf), findsNWidgets(2));
  });

  testWidgets('tapping a document shares it', (tester) async {
    await pumpHome(tester, [sampleDoc('Contract')]);
    await tester.tap(find.text('Contract'));
    await tester.pump();
    expect(share.shared, ['/mem/Contract.pdf']);
  });

  testWidgets('menu → Share', (tester) async {
    await pumpHome(tester, [sampleDoc('Contract')]);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(share.shared, hasLength(1));
  });

  testWidgets('menu → Rename updates the list', (tester) async {
    await pumpHome(tester, [sampleDoc('Old')]);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Old'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'New');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New'), findsOneWidget);
    expect(find.text('Old'), findsNothing);
  });

  testWidgets('rename then cancel changes nothing', (tester) async {
    await pumpHome(tester, [sampleDoc('Old')]);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Old'), findsOneWidget);
  });

  testWidgets('menu → Delete asks for confirmation and deletes', (tester) async {
    await pumpHome(tester, [sampleDoc('DeleteMe')]);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete document?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('DeleteMe'), findsNothing);
    expect(find.textContaining('You have no documents yet'), findsOneWidget);
  });

  testWidgets('cancelling the deletion keeps the document', (tester) async {
    await pumpHome(tester, [sampleDoc('Safe')]);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Safe'), findsOneWidget);
  });

  testWidgets('shows an error with a retry option', (tester) async {
    final failing = _FailingOnce();
    ctrl = HomeController(
      listDocuments: ListDocuments(failing),
      renameDocument: RenameDocument(failing),
      deleteDocument: DeleteDocument(failing),
      shareService: FakeShareService(),
    );
    await pumpApp(tester, HomeScreen(controller: ctrl, startSession: startSession));
    await tester.pumpAndSettle();
    expect(find.text('Could not load documents'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
  });

  testWidgets('the FAB starts a session and opens the scanner', (tester) async {
    await pumpHome(tester);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('scan_fab')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sessionsStarted, 1);
    expect(find.text('Could not open the camera'), findsOneWidget);
  });
}

class _FailingOnce extends InMemoryDocumentRepository {
  var _first = true;

  @override
  Future<List<ScannedDocument>> list() async {
    if (_first) {
      _first = false;
      throw Exception('disk unavailable');
    }
    return [sampleDoc('Recovered')];
  }
}
