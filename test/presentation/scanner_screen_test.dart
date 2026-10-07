import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/core/l10n/l10n.dart';
import 'package:mi_scan/domain/entities/camera_info.dart';
import 'package:mi_scan/domain/entities/scanned_document.dart';
import 'package:mi_scan/domain/services/camera_service.dart';
import 'package:mi_scan/presentation/crop/crop_screen.dart';
import 'package:mi_scan/presentation/scanner/scan_session.dart';
import 'package:mi_scan/presentation/scanner/scanner_controller.dart';
import 'package:mi_scan/presentation/scanner/scanner_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_helpers.dart';

void main() {
  const wide = CameraInfo(id: 'wide', facing: CameraFacing.back, lens: CameraLens.wide);
  const ultra = CameraInfo(id: 'ultra', facing: CameraFacing.back, lens: CameraLens.ultraWide);
  const tele = CameraInfo(id: 'tele', facing: CameraFacing.back, lens: CameraLens.telephoto);
  const front = CameraInfo(id: 'front', facing: CameraFacing.front);

  late Directory dir;
  late File photo;
  late FakeImageProcessor processor;
  late InMemoryDocumentRepository repo;
  late ScanSession session;
  late FakeCameraService camera;
  ScannedDocument? result;

  Future<void> open(WidgetTester tester, {FakeCameraService? service, Locale locale = const Locale('en')}) async {
    usePhoneScreen(tester);
    camera = service ?? FakeCameraService(cameras: [wide, ultra, tele, front], photoPath: photo.path);
    final factory = fakeScreenFactory(camera: camera);
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.push<ScannedDocument>(
              context,
              MaterialPageRoute(
                builder: (_) => ScannerScreen(
                  session: session,
                  controller: factory.scannerController(session),
                  factory: factory,
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
    dir = Directory.systemTemp.createTempSync('scanner_screen_test_');
    photo = File('${dir.path}/photo.png')..writeAsBytesSync(kTinyPng);
    processor = FakeImageProcessor();
    repo = InMemoryDocumentRepository();
    session = buildSession(dir, processor: processor, repo: repo);
    result = null;
  });

  tearDown(() => dir.deleteSync(recursive: true));

  group('camera states', () {
    testWidgets('shows the preview once the camera is ready', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('preview')), findsOneWidget);
      expect(find.byKey(const Key('shutter')), findsOneWidget);
    });

    testWidgets('explains a denied permission', (tester) async {
      await open(
        tester,
        service: FakeCameraService(listError: const CameraAccessException(CameraFailure.permissionDenied)),
      );
      expect(find.text('Camera permission denied. Enable it in Settings to scan.'), findsOneWidget);
    });

    testWidgets('explains that no camera could be opened', (tester) async {
      await open(tester, service: FakeCameraService(cameras: const []));
      expect(find.text('Could not open the camera'), findsOneWidget);
    });

    testWidgets('shows the plugin error details', (tester) async {
      await open(
        tester,
        service: FakeCameraService(openError: const CameraAccessException(CameraFailure.failed, 'busy')),
      );
      expect(find.text('Camera error: busy'), findsOneWidget);
    });

    testWidgets('texts follow the device language', (tester) async {
      final es = await AppLocalizations.delegate.load(const Locale('es'));
      await open(tester, locale: const Locale('es'));
      expect(find.text(es.modeSingle), findsOneWidget);
      expect(find.text(es.modeBatch), findsOneWidget);
      expect(find.text(es.galleryButton), findsOneWidget);
    });
  });

  group('lenses', () {
    testWidgets('shows no lens buttons and never the front camera', (tester) async {
      await open(tester);
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      for (final id in ['wide', 'ultra', 'tele', 'front']) {
        expect(find.byKey(Key('lens_$id')), findsNothing, reason: id);
      }
      expect(camera.opened.map((s) => s.info.facing), everyElement(CameraFacing.back));
    });

    testWidgets('zooming out switches to the ultra wide lens by itself', (tester) async {
      await open(tester);
      await tester.drag(find.byKey(const Key('zoom_slider')), const Offset(-5000, 0));
      await tester.pumpAndSettle();
      expect(camera.opened.last.info, ultra);
      expect(find.text('0.5x'), findsOneWidget);
    });

    testWidgets('zooming in switches to the telephoto lens by itself', (tester) async {
      await open(tester);
      await tester.drag(find.byKey(const Key('zoom_slider')), const Offset(5000, 0));
      await tester.pumpAndSettle();
      expect(camera.opened.last.info, tele);
      expect(find.text('8.0x'), findsOneWidget);
    });

    testWidgets('keeps a single camera when the phone merges its lenses', (tester) async {
      await open(
        tester,
        service: FakeCameraService(
          cameras: [wide, ultra, tele, front],
          zoomRanges: {'wide': const ZoomRange(0.6, 10)},
          photoPath: photo.path,
        ),
      );
      await tester.drag(find.byKey(const Key('zoom_slider')), const Offset(-5000, 0));
      await tester.pumpAndSettle();
      expect(camera.opened, hasLength(1));
      expect(find.text('0.6x'), findsOneWidget);
    });
  });

  group('zoom', () {
    testWidgets('starts at 1.0x', (tester) async {
      await open(tester);
      expect(find.text('1.0x'), findsOneWidget);
    });

    testWidgets('the slider changes the zoom of the camera', (tester) async {
      await open(tester);
      await tester.drag(find.byKey(const Key('zoom_slider')), const Offset(5000, 0));
      await tester.pumpAndSettle();
      expect(camera.opened.last.zoom, 4);
      expect(find.text('8.0x'), findsOneWidget);
    });

    testWidgets('pinching the preview zooms in', (tester) async {
      await open(tester);
      final center = tester.getCenter(find.byKey(const Key('preview')));
      final first = await tester.startGesture(center - const Offset(20, 0));
      final second = await tester.startGesture(center + const Offset(20, 0));
      await first.moveBy(const Offset(-60, 0));
      await second.moveBy(const Offset(60, 0));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(camera.opened.last.zoom, greaterThan(1));
    });
  });

  group('flash and torch', () {
    testWidgets('the flash button cycles the flash mode', (tester) async {
      await open(tester);
      expect(find.byIcon(Icons.flash_off), findsOneWidget);
      await tester.tap(find.byKey(const Key('flash_button')));
      await tester.pump();
      expect(find.byIcon(Icons.flash_auto), findsOneWidget);
      expect(camera.opened.single.flash, FlashSetting.auto);
      await tester.tap(find.byKey(const Key('flash_button')));
      await tester.pump();
      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });

    testWidgets('the torch button turns the flashlight on and off', (tester) async {
      await open(tester);
      expect(find.byIcon(Icons.flashlight_off), findsOneWidget);
      await tester.tap(find.byKey(const Key('torch_button')));
      await tester.pump();
      expect(find.byIcon(Icons.flashlight_on), findsOneWidget);
      expect(camera.opened.single.torch, isTrue);
      await tester.tap(find.byKey(const Key('torch_button')));
      await tester.pump();
      expect(camera.opened.single.torch, isFalse);
    });

    testWidgets('both controls are disabled without a camera', (tester) async {
      await open(tester, service: FakeCameraService(cameras: const []));
      expect(tester.widget<IconButton>(find.byKey(const Key('torch_button'))).onPressed, isNull);
      expect(tester.widget<IconButton>(find.byKey(const Key('flash_button'))).onPressed, isNull);
    });
  });

  group('batch mode', () {
    Future<void> settleCrop(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shoot(WidgetTester tester, int count) async {
      await tester.tap(find.byKey(const Key('mode_batch')));
      await tester.pump();
      for (var i = 0; i < count; i++) {
        await tester.tap(find.byKey(const Key('shutter')));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('captures several photos without opening the crop editor', (tester) async {
      await open(tester);
      await shoot(tester, 3);
      expect(session.shots, hasLength(3));
      expect(session.pages, isEmpty);
      expect(find.byType(CropScreen), findsNothing);
      expect(find.byKey(const Key('batch_done')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('the camera keeps working after each shot', (tester) async {
      await open(tester);
      await shoot(tester, 1);
      expect(camera.opened.single.streaming, isTrue);
    });

    testWidgets('Done opens the crop editor for every photo, in order', (tester) async {
      await open(tester);
      await shoot(tester, 3);
      await tester.tap(find.byKey(const Key('batch_done')));
      await settleCrop(tester);
      expect(find.byType(CropScreen), findsOneWidget);
      expect(find.text('Adjust edges (1/3)'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(session.shots, isEmpty);
    });

    testWidgets('each photo can be adjusted and saved like in single mode', (tester) async {
      await open(tester);
      await shoot(tester, 2);
      await tester.tap(find.byKey(const Key('batch_done')));
      await settleCrop(tester);

      await tester.runAsync(() async {
        await tester.tap(find.text('Next'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await settleCrop(tester);
      expect(find.text('Adjust edges (2/2)'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await settleCrop(tester);
      await tester.enterText(find.byType(TextField), 'Batch scan');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(processor.calls.where((c) => c.startsWith('crop')), hasLength(2));
      expect(repo.docs.single.name, 'Batch scan');
      expect(result?.name, 'Batch scan');
      expect(find.byType(ScannerScreen), findsNothing);
    });

    testWidgets('skipping every photo leaves the scanner ready for more', (tester) async {
      await open(tester);
      await shoot(tester, 2);
      await tester.tap(find.byKey(const Key('batch_done')));
      await settleCrop(tester);
      await tester.tap(find.text('Skip'));
      await settleCrop(tester);
      await tester.tap(find.text('Skip'));
      await settleCrop(tester);
      expect(find.byType(ScannerScreen), findsOneWidget);
      expect(find.byType(CropScreen), findsNothing);
      expect(session.pages, isEmpty);
      expect(camera.opened.single.streaming, isTrue);
    });

    testWidgets('Add keeps the page and Done then saves the PDF directly', (tester) async {
      await open(tester);
      await shoot(tester, 1);
      await tester.tap(find.byKey(const Key('batch_done')));
      await settleCrop(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Add'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await settleCrop(tester);
      expect(session.pages, hasLength(1));
      expect(find.byType(CropScreen), findsNothing);

      await tester.tap(find.byKey(const Key('batch_done')));
      await tester.pumpAndSettle();
      expect(find.text('PDF name'), findsOneWidget);
    });

    testWidgets('does not show Done in single mode', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('batch_done')), findsNothing);
    });
  });

  group('single mode', () {
    testWidgets('a capture opens the crop editor', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('shutter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CropScreen), findsOneWidget);
    });

    testWidgets('shows an error when the photo cannot be taken', (tester) async {
      await open(tester);
      camera.opened.single.takePictureError = StateError('no photo');
      await tester.tap(find.byKey(const Key('shutter')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not take the photo'), findsOneWidget);
      expect(camera.opened.single.streaming, isTrue);
    });
  });

  group('closing', () {
    testWidgets('closes right away when there are no pages', (tester) async {
      await open(tester);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(ScannerScreen), findsNothing);
    });

    testWidgets('asks before discarding captured pages', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('mode_batch')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('shutter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Discard this scan?'), findsOneWidget);
      expect(find.text('1 unsaved page will be lost.'), findsOneWidget);

      await tester.tap(find.text('Keep scanning'));
      await tester.pumpAndSettle();
      expect(find.byType(ScannerScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(ScannerScreen), findsNothing);
    });
  });

  testWidgets('releases the camera when the screen is closed', (tester) async {
    await open(tester);
    final opened = camera.opened.single;
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.pump();
    expect(opened.disposed, isTrue);
  });

  test('ScanMode exposes both modes', () {
    expect(ScanMode.values, [ScanMode.single, ScanMode.batch]);
  });
}
