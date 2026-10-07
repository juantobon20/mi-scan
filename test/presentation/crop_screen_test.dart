import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/quad.dart';
import 'package:mi_scan/presentation/crop/crop_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_helpers.dart';

void main() {
  late Directory dir;
  late FakeImageProcessor processor;
  late File image;
  CropResult? result;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('crop_test_');
    processor = FakeImageProcessor();
    image = File('${dir.path}/src.png')..writeAsBytesSync(kTinyPng);
    result = null;
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> open(WidgetTester tester, {int index = 0, int total = 1}) async {
    final session = buildSession(dir, processor: processor);
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.push<CropResult>(
            context,
            MaterialPageRoute(
              builder: (_) => CropScreen(session: session, imagePath: image.path, index: index, total: total),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('without detection asks to adjust the corners manually', (tester) async {
    await open(tester);
    expect(find.text('Adjust edges'), findsOneWidget);
    expect(find.text('Move the corners to fit the document'), findsOneWidget);
  });

  testWidgets('with detection the hint is hidden', (tester) async {
    processor.detected = Quad.inset(0.2);
    await open(tester);
    expect(find.text('Move the corners to fit the document'), findsNothing);
  });

  testWidgets('offers the 4 filters', (tester) async {
    await open(tester);
    for (final l in ['Original', 'Enhanced', 'Grayscale', 'B&W']) {
      expect(find.text(l), findsOneWidget);
    }
  });

  testWidgets('Save crops with the chosen filter and returns save=true', (tester) async {
    await open(tester);
    await tester.tap(find.text('Grayscale'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(processor.calls, contains('crop:grayscale'));
    expect(result, isNotNull);
    expect(result!.save, isTrue);
    expect(result!.page.width, 800);
  });

  testWidgets('Add returns save=false', (tester) async {
    await open(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Add'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(result!.save, isFalse);
  });

  testWidgets('Cancel returns null', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(CropScreen), findsNothing);
  });

  testWidgets('the action buttons fit on a narrow 360 dp phone even with Skip, Add and Save', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await open(tester, index: 1, total: 2);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('live filter preview', () {
    String shownPath(WidgetTester tester) {
      var provider = tester.widget<Image>(find.byKey(const Key('editor_image'))).image;
      if (provider is ResizeImage) provider = provider.imageProvider;
      return (provider as FileImage).file.path;
    }

    Future<void> pickFilter(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    testWidgets('starts showing the original image', (tester) async {
      await open(tester);
      expect(shownPath(tester), image.path);
      expect(processor.calls.where((c) => c.startsWith('preview')), isEmpty);
    });

    testWidgets('selecting a filter shows the filtered image right away', (tester) async {
      await open(tester);
      await pickFilter(tester, 'Grayscale');
      expect(processor.calls, contains('preview:grayscale'));
      expect(shownPath(tester), isNot(image.path));
      expect(shownPath(tester), contains('grayscale'));
    });

    testWidgets('every filter is previewed with its own image', (tester) async {
      await open(tester);
      final shown = <String>{};
      for (final label in ['Enhanced', 'Grayscale', 'B&W']) {
        await pickFilter(tester, label);
        shown.add(shownPath(tester));
      }
      expect(shown, hasLength(3));
    });

    testWidgets('going back to Original restores the source image', (tester) async {
      await open(tester);
      await pickFilter(tester, 'B&W');
      await pickFilter(tester, 'Original');
      expect(shownPath(tester), image.path);
    });

    testWidgets('a filter already computed is shown again without reprocessing', (tester) async {
      await open(tester);
      await pickFilter(tester, 'Grayscale');
      await pickFilter(tester, 'Original');
      await pickFilter(tester, 'Grayscale');
      expect(processor.calls.where((c) => c == 'preview:grayscale'), hasLength(1));
      expect(shownPath(tester), contains('grayscale'));
    });

    testWidgets('shows a progress indicator while the preview is computed', (tester) async {
      await open(tester);
      processor.previewGate = Completer<void>();
      await tester.tap(find.text('B&W'));
      await tester.pump();
      expect(find.byKey(const Key('preview_loading')), findsOneWidget);
      expect(shownPath(tester), image.path);
      processor.previewGate!.complete();
      await pickFilter(tester, 'B&W');
      expect(find.byKey(const Key('preview_loading')), findsNothing);
    });

    testWidgets('the last filter tapped wins when taps overlap', (tester) async {
      await open(tester);
      processor.previewGate = Completer<void>();
      await tester.tap(find.text('Enhanced'));
      await tester.pump();
      await tester.tap(find.text('Grayscale'));
      await tester.pump();
      processor.previewGate!.complete();
      await pickFilter(tester, 'Grayscale');
      expect(shownPath(tester), contains('grayscale'));
    });

    testWidgets('a failing preview falls back to the original image and tells the user', (tester) async {
      await open(tester);
      processor.previewError = StateError('no memory');
      await pickFilter(tester, 'B&W');
      expect(shownPath(tester), image.path);
      expect(find.textContaining('Could not crop'), findsOneWidget);
    });

    testWidgets('saving uses the selected filter on the full resolution image', (tester) async {
      await open(tester);
      await pickFilter(tester, 'Enhanced');
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(processor.calls, contains('crop:enhanced'));
    });

    testWidgets('previews are deleted when the editor closes', (tester) async {
      await open(tester);
      await pickFilter(tester, 'Grayscale');
      final preview = shownPath(tester);
      expect(File(preview).existsSync(), isTrue);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(File(preview).existsSync(), isFalse);
    });
  });

  testWidgets('with several images shows progress, "Next" and "Skip"', (tester) async {
    await open(tester, index: 0, total: 3);
    expect(find.text('Adjust edges (1/3)'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('"Detect edges" without a result notifies the user', (tester) async {
    await open(tester);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Detect edges'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(find.text('Document not detected'), findsOneWidget);
  });

  testWidgets('dragging a corner moves the point without leaving the image', (tester) async {
    await open(tester);
    final handles = find.byType(Listener);
    expect(handles, findsWidgets);
    final g = await tester.startGesture(tester.getCenter(handles.at(1)));
    await g.moveBy(const Offset(-5000, -5000));
    await g.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
