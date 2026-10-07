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
  const unknownBack = CameraInfo(id: 'extra', facing: CameraFacing.back);

  late Directory dir;
  late File photo;
  late FakeImageProcessor processor;
  late InMemoryDocumentRepository repo;
  late ScanSession session;
  late FakeCameraService camera;
  ScannedDocument? result;

  Future<void> open(WidgetTester tester, {FakeCameraService? service, Locale locale = const Locale('en')}) async {
    usePhoneScreen(tester);
    camera = service ?? FakeCameraService(cameras: [wide, ultra, tele, front, unknownBack], photoPath: photo.path);
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
    testWidgets('offers every camera of the phone', (tester) async {
      await open(tester);
      for (final id in ['wide', 'ultra', 'tele', 'front', 'extra']) {
        expect(find.byKey(Key('lens_$id')), findsOneWidget, reason: id);
      }
      expect(find.text('Wide'), findsOneWidget);
      expect(find.text('Ultra wide'), findsOneWidget);
      expect(find.text('Telephoto'), findsOneWidget);
      expect(find.text('Front'), findsOneWidget);
      expect(find.text('Camera 5'), findsOneWidget);
    });

    testWidgets('hides the selector when the phone has a single camera', (tester) async {
      await open(tester, service: FakeCameraService(cameras: const [wide]));
      expect(find.byKey(const Key('lens_wide')), findsNothing);
    });

    testWidgets('tapping a lens switches the camera', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('lens_ultra')));
      await tester.pumpAndSettle();
      expect(camera.opened.last.info, ultra);
      expect(camera.opened.first.disposed, isTrue);
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
      expect(camera.opened.single.zoom, 8);
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
      expect(camera.opened.single.zoom, greaterThan(1));
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
    testWidgets('captures several pages without opening the crop editor', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('mode_batch')));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('shutter')));
        await tester.pumpAndSettle();
      }
      expect(session.pages, hasLength(3));
      expect(find.byType(CropScreen), findsNothing);
      expect(find.byKey(const Key('batch_done')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('the camera keeps working after each shot', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('mode_batch')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('shutter')));
      await tester.pumpAndSettle();
      expect(camera.opened.single.streaming, isTrue);
    });

    testWidgets('Done asks for a name, saves the PDF and closes the scanner', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('mode_batch')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('shutter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('batch_done')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Batch scan');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.docs.single.name, 'Batch scan');
      expect(result?.name, 'Batch scan');
      expect(find.byType(ScannerScreen), findsNothing);
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
