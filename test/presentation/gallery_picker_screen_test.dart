import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/core/l10n/l10n.dart';
import 'package:mi_scan/domain/entities/gallery_image.dart';
import 'package:mi_scan/presentation/gallery/gallery_controller.dart';
import 'package:mi_scan/presentation/gallery/gallery_picker_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_helpers.dart';

void main() {
  late Directory dir;
  late FakeGalleryService service;
  List<String>? result;

  Future<void> open(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.push<List<String>>(
              context,
              MaterialPageRoute(
                builder: (_) => GalleryPickerScreen(
                  controller: GalleryController(service: service, directory: dir.path),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gallery_screen_test_');
    service = FakeGalleryService(count: 4);
    result = null;
  });

  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('shows a grid with every image', (tester) async {
    await open(tester);
    expect(find.text('Choose images'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(Key('gallery_img$i')), findsOneWidget);
    }
  });

  testWidgets('shows the empty state', (tester) async {
    service = FakeGalleryService(count: 0);
    await open(tester);
    expect(find.text('No images'), findsOneWidget);
  });

  testWidgets('explains denied access and opens the settings', (tester) async {
    service = FakeGalleryService(access: GalleryAccess.denied);
    await open(tester);
    expect(find.text('No permission to access photos.'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    expect(service.settingsOpened, 1);
  });

  testWidgets('numbers the selection in the order of the taps', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('gallery_img2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gallery_img0')));
    await tester.pump();
    expect(find.descendant(of: find.byKey(const Key('gallery_img2')), matching: find.text('1')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('gallery_img0')), matching: find.text('2')), findsOneWidget);
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Add (2)'), findsOneWidget);
  });

  testWidgets('tapping a selected image unselects it', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('gallery_img1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gallery_img1')));
    await tester.pump();
    expect(find.byKey(const Key('gallery_confirm')), findsNothing);
    expect(find.text('Choose images'), findsOneWidget);
  });

  testWidgets('confirming returns the exported paths and closes', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('gallery_img3')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('gallery_confirm')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(result, hasLength(1));
    expect(result!.single.startsWith(dir.path), isTrue);
    expect(service.exported, ['img3']);
    expect(find.byType(GalleryPickerScreen), findsNothing);
  });

  testWidgets('texts follow the device language', (tester) async {
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    await open(tester, locale: const Locale('es'));
    expect(find.text(es.galleryTitle), findsOneWidget);
  });
}
