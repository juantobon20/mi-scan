import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/scan_page.dart';
import 'package:mi_scan/presentation/review/review_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_helpers.dart';

void main() {
  late Directory dir;
  late FakeImageProcessor processor;
  late InMemoryDocumentRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('review_test_');
    processor = FakeImageProcessor();
    repo = InMemoryDocumentRepository();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<dynamic> pumpReview(WidgetTester tester, int pages) async {
    final session = buildSession(dir, processor: processor, repo: repo);
    for (var i = 0; i < pages; i++) {
      final f = File('${dir.path}/p$i.jpg')..writeAsBytesSync(kTinyPng);
      session.add(ScanPage(f.path, 800, 1000));
    }
    await pumpApp(tester, ReviewScreen(session: session));
    await tester.pump();
    return session;
  }

  testWidgets('shows the counter and one row per page', (tester) async {
    await pumpReview(tester, 3);
    expect(find.text('3 page(s)'), findsOneWidget);
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Page 3'), findsOneWidget);
  });

  testWidgets('deleting a page updates the list', (tester) async {
    final session = await pumpReview(tester, 2);
    await tester.tap(find.byTooltip('Delete').first);
    await tester.pump();
    expect(session.pages, hasLength(1));
    expect(find.text('1 page(s)'), findsOneWidget);
  });

  testWidgets('deleting the last page closes the screen', (tester) async {
    await pumpReview(tester, 1);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsNothing);
  });

  testWidgets('rotate delegates to the processor', (tester) async {
    await pumpReview(tester, 1);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Rotate'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(processor.calls, contains('rotate'));
  });

  testWidgets('Create PDF asks for a name, saves and closes returning the document', (tester) async {
    await pumpReview(tester, 2);
    await tester.tap(find.text('Create PDF'));
    await tester.pumpAndSettle();
    expect(find.text('PDF name'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'My scan');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.docs.single.name, 'My scan');
    expect(find.byType(ReviewScreen), findsNothing);
  });

  testWidgets('cancelling the name does not create the PDF', (tester) async {
    await pumpReview(tester, 1);
    await tester.tap(find.text('Create PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.docs, isEmpty);
    expect(find.byType(ReviewScreen), findsOneWidget);
  });

  testWidgets('"Add" returns to the camera without creating a PDF', (tester) async {
    await pumpReview(tester, 1);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsNothing);
    expect(repo.docs, isEmpty);
  });
}
