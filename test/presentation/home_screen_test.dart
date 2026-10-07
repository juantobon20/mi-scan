import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/folder.dart';
import 'package:mi_scan/presentation/home/home_controller.dart';
import 'package:mi_scan/presentation/home/home_screen.dart';
import 'package:mi_scan/presentation/scanner/scan_session.dart';
import 'package:mi_scan/presentation/scanner/scanner_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_helpers.dart';

void main() {
  late InMemoryDocumentRepository docs;
  late InMemoryFolderRepository folders;
  late FakeShareService share;
  late HomeController ctrl;
  var sessionsStarted = 0;

  Future<ScanSession> startSession() async {
    sessionsStarted++;
    return buildSession(Directory.systemTemp.createTempSync('home_test_'));
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    List<dynamic> documents = const [],
    List<Folder> existingFolders = const [],
    Locale locale = const Locale('en'),
  }) async {
    usePhoneScreen(tester);
    docs = InMemoryDocumentRepository([for (final d in documents) d]);
    folders = InMemoryFolderRepository(docs, existingFolders);
    share = FakeShareService();
    ctrl = makeHomeController(documents: docs, folders: folders, share: share);
    await pumpApp(
      tester,
      HomeScreen(controller: ctrl, startSession: startSession, factory: fakeScreenFactory()),
      locale: locale,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  final work = Folder(id: 'work', name: 'Work', createdAt: DateTime(2026, 1, 1));

  setUp(() => sessionsStarted = 0);

  group('list', () {
    testWidgets('shows the title and the empty state', (tester) async {
      await pumpHome(tester);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.textContaining('You have no documents yet'), findsOneWidget);
      expect(find.byKey(const Key('scan_fab')), findsOneWidget);
    });

    testWidgets('shows an indicator while loading', (tester) async {
      usePhoneScreen(tester);
      ctrl = makeHomeController();
      await pumpApp(tester, HomeScreen(controller: ctrl, startSession: startSession, factory: fakeScreenFactory()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('lists documents with name, date, size and number of pages', (tester) async {
      await pumpHome(tester, documents: [
        sampleDoc('Contract', pageCount: 3),
        sampleDoc('Receipt', sizeBytes: 5 * 1024 * 1024, pageCount: 1),
        sampleDoc('Legacy'),
      ]);
      expect(find.text('3/5/2026 09:07 \u00b7 2 KB \u00b7 3 pages'), findsOneWidget);
      expect(find.text('3/5/2026 09:07 \u00b7 5.0 MB \u00b7 1 page'), findsOneWidget);
      expect(find.text('3/5/2026 09:07 \u00b7 2 KB'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsNWidgets(3));
    });

    testWidgets('tapping a document shares it', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Contract')]);
      await tester.tap(find.text('Contract'));
      await tester.pump();
      expect(share.shared, ['/mem/Contract.pdf']);
    });

    testWidgets('shows an error with a retry option', (tester) async {
      usePhoneScreen(tester);
      docs = InMemoryDocumentRepository([sampleDoc('Recovered')])..listError = Exception('disk unavailable');
      ctrl = makeHomeController(documents: docs);
      await pumpApp(tester, HomeScreen(controller: ctrl, startSession: startSession, factory: fakeScreenFactory()));
      await tester.pumpAndSettle();
      expect(find.text('Could not load documents'), findsOneWidget);
      docs.listError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Recovered'), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('menu \u2192 Share', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Contract')]);
      await openMenu(tester, 'Share');
      expect(share.shared, hasLength(1));
    });

    testWidgets('menu \u2192 Rename updates the list', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Old')]);
      await openMenu(tester, 'Rename');
      expect(find.widgetWithText(TextField, 'Old'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'New');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Old'), findsNothing);
    });

    testWidgets('renaming and cancelling changes nothing', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Old')]);
      await openMenu(tester, 'Rename');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Old'), findsOneWidget);
    });

    testWidgets('menu \u2192 Delete asks for confirmation and deletes', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('DeleteMe')]);
      await openMenu(tester, 'Delete');
      expect(find.text('Delete document?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('DeleteMe'), findsNothing);
      expect(find.textContaining('You have no documents yet'), findsOneWidget);
    });

    testWidgets('cancelling the deletion keeps the document', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Safe')]);
      await openMenu(tester, 'Delete');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Safe'), findsOneWidget);
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
      expect(find.byType(ScannerScreen), findsOneWidget);
    });
  });

  group('search', () {
    final all = [sampleDoc('Invoice March'), sampleDoc('Contract'), sampleDoc('Receipt')];

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const Key('search_field')), text);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    }

    testWidgets('the search button reveals the search field', (tester) async {
      await pumpHome(tester, documents: all);
      expect(find.byKey(const Key('search_field')), findsNothing);
      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search_field')), findsOneWidget);
      expect(find.text('Search documents'), findsOneWidget);
    });

    testWidgets('typing filters the list', (tester) async {
      await pumpHome(tester, documents: all);
      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();
      await type(tester, 'contr');
      expect(find.text('Contract'), findsOneWidget);
      expect(find.text('Invoice March'), findsNothing);
      expect(find.text('Receipt'), findsNothing);
    });

    testWidgets('shows a message with the text when nothing matches', (tester) async {
      await pumpHome(tester, documents: all);
      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();
      await type(tester, 'zzz');
      expect(find.text('No documents match "zzz".'), findsOneWidget);
      expect(find.textContaining('You have no documents yet'), findsNothing);
    });

    testWidgets('closing the search restores the full list', (tester) async {
      await pumpHome(tester, documents: all);
      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();
      await type(tester, 'contr');
      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search_field')), findsNothing);
      expect(find.text('Invoice March'), findsOneWidget);
      expect(find.text('Receipt'), findsOneWidget);
    });

    testWidgets('searching ignores accents', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Declaraci\u00f3n de renta'), sampleDoc('Other')]);
      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();
      await type(tester, 'declaracion');
      expect(find.text('Declaraci\u00f3n de renta'), findsOneWidget);
      expect(find.text('Other'), findsNothing);
    });
  });

  group('folders', () {
    testWidgets('shows All plus every folder with its document count', (tester) async {
      await pumpHome(
        tester,
        documents: [sampleDoc('A', folderId: 'work'), sampleDoc('B', folderId: 'work'), sampleDoc('C')],
        existingFolders: [work],
      );
      expect(find.byKey(const Key('folder_all')), findsOneWidget);
      expect(find.text('Work (2)'), findsOneWidget);
      expect(find.byKey(const Key('folder_new')), findsOneWidget);
    });

    testWidgets('selecting a folder shows only its documents', (tester) async {
      await pumpHome(
        tester,
        documents: [sampleDoc('In work', folderId: 'work'), sampleDoc('Loose')],
        existingFolders: [work],
      );
      await tester.tap(find.byKey(const Key('folder_work')));
      await tester.pumpAndSettle();
      expect(find.text('In work'), findsOneWidget);
      expect(find.text('Loose'), findsNothing);
      await tester.tap(find.byKey(const Key('folder_all')));
      await tester.pumpAndSettle();
      expect(find.text('Loose'), findsOneWidget);
    });

    testWidgets('an empty folder explains what to do', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Loose')], existingFolders: [work]);
      await tester.tap(find.byKey(const Key('folder_work')));
      await tester.pumpAndSettle();
      expect(find.textContaining('This folder is empty'), findsOneWidget);
    });

    testWidgets('New folder asks for a name, creates it and opens it', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Loose')]);
      await tester.tap(find.byKey(const Key('folder_new')));
      await tester.pumpAndSettle();
      expect(find.text('Folder name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Taxes');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Taxes (0)'), findsOneWidget);
      expect(ctrl.selectedFolder?.name, 'Taxes');
      expect(find.text('Loose'), findsNothing);
    });

    testWidgets('a blank folder name creates nothing', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('folder_new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(folders.folders, isEmpty);
    });

    testWidgets('cancelling the folder name creates nothing', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('folder_new')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(folders.folders, isEmpty);
    });

    testWidgets('a failure creating a folder is reported', (tester) async {
      await pumpHome(tester);
      folders.createError = StateError('disk full');
      await tester.tap(find.byKey(const Key('folder_new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Taxes');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });

    testWidgets('long press \u2192 Rename folder', (tester) async {
      await pumpHome(tester, existingFolders: [work]);
      await tester.longPress(find.byKey(const Key('folder_work')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folder_rename')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Work'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Office');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Office (0)'), findsOneWidget);
    });

    testWidgets('long press \u2192 Delete folder keeps the documents', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Keep me', folderId: 'work')], existingFolders: [work]);
      await tester.tap(find.byKey(const Key('folder_work')));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const Key('folder_work')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folder_delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete folder?'), findsOneWidget);
      expect(find.textContaining('"Work" will be deleted'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folder_work')), findsNothing);
      expect(find.text('Keep me'), findsOneWidget);
    });

    testWidgets('cancelling the folder deletion keeps it', (tester) async {
      await pumpHome(tester, existingFolders: [work]);
      await tester.longPress(find.byKey(const Key('folder_work')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folder_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folder_work')), findsOneWidget);
    });
  });

  group('moving documents', () {
    testWidgets('menu \u2192 Move to folder lists the folders and the no-folder option', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Doc')], existingFolders: [work]);
      await openMenu(tester, 'Move to folder');
      expect(find.text('Move to'), findsOneWidget);
      expect(find.byKey(const Key('move_none')), findsOneWidget);
      expect(find.byKey(const Key('move_work')), findsOneWidget);
    });

    testWidgets('choosing a folder moves the document and updates the counts', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Doc')], existingFolders: [work]);
      await openMenu(tester, 'Move to folder');
      await tester.tap(find.byKey(const Key('move_work')));
      await tester.pumpAndSettle();
      expect(find.text('Work (1)'), findsOneWidget);
      expect(docs.docs.single.folderId, 'work');
    });

    testWidgets('choosing No folder takes the document out', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Doc', folderId: 'work')], existingFolders: [work]);
      await openMenu(tester, 'Move to folder');
      await tester.tap(find.byKey(const Key('move_none')));
      await tester.pumpAndSettle();
      expect(find.text('Work (0)'), findsOneWidget);
      expect(docs.docs.single.folderId, isNull);
    });

    testWidgets('the current folder is marked', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Doc', folderId: 'work')], existingFolders: [work]);
      await openMenu(tester, 'Move to folder');
      expect(find.descendant(of: find.byKey(const Key('move_work')), matching: find.byIcon(Icons.check)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('move_none')), matching: find.byIcon(Icons.check)), findsNothing);
    });

    testWidgets('dismissing the dialog moves nothing', (tester) async {
      await pumpHome(tester, documents: [sampleDoc('Doc')], existingFolders: [work]);
      await openMenu(tester, 'Move to folder');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(docs.docs.single.folderId, isNull);
    });
  });

  testWidgets('texts follow the device language', (tester) async {
    await pumpHome(tester, locale: const Locale('es'));
    expect(find.text('Recientes'), findsOneWidget);
    expect(find.byKey(const Key('folder_all')), findsOneWidget);
    expect(find.text('All'), findsNothing);
  });
}
