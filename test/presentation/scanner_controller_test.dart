import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/camera_info.dart';
import 'package:mi_scan/domain/entities/quad.dart';
import 'package:mi_scan/domain/services/camera_service.dart';
import 'package:mi_scan/presentation/scanner/scanner_controller.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_helpers.dart';

void main() {
  const front = CameraInfo(id: 'front', facing: CameraFacing.front, lens: CameraLens.wide);
  const ultra = CameraInfo(id: 'ultra', facing: CameraFacing.back, lens: CameraLens.ultraWide);
  const wide = CameraInfo(id: 'wide', facing: CameraFacing.back, lens: CameraLens.wide);
  const tele = CameraInfo(id: 'tele', facing: CameraFacing.back, lens: CameraLens.telephoto);

  late Directory dir;
  late FakeImageProcessor processor;
  late FakeCameraService service;
  late ScannerController controller;

  ScannerController build(FakeCameraService s) =>
      ScannerController(cameraService: s, session: buildSession(dir, processor: processor));

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('scanner_controller_test_');
    processor = FakeImageProcessor();
    service = FakeCameraService(cameras: [front, ultra, wide, tele], photoPath: '${dir.path}/shot.jpg');
    controller = build(service);
  });

  tearDown(() {
    controller.dispose();
    dir.deleteSync(recursive: true);
  });

  group('initialize', () {
    test('lists the cameras and opens the main back camera', () async {
      await controller.initialize();
      expect(controller.cameras, [front, ultra, wide, tele]);
      expect(controller.selectedCamera, wide);
      expect(controller.isReady, isTrue);
      expect(service.opened.single.streaming, isTrue);
    });

    test('falls back to the first back camera when there is no wide lens', () async {
      service = FakeCameraService(cameras: [front, tele, ultra]);
      controller = build(service);
      await controller.initialize();
      expect(controller.selectedCamera, tele);
    });

    test('falls back to the first camera when there is no back camera', () async {
      service = FakeCameraService(cameras: [front]);
      controller = build(service);
      await controller.initialize();
      expect(controller.selectedCamera, front);
    });

    test('reports unavailable when the device has no cameras', () async {
      controller = build(FakeCameraService(cameras: const []));
      await controller.initialize();
      expect(controller.problem?.failure, CameraFailure.unavailable);
      expect(controller.isReady, isFalse);
    });

    test('keeps the domain failure when listing cameras fails', () async {
      controller = build(FakeCameraService(listError: const CameraAccessException(CameraFailure.permissionDenied)));
      await controller.initialize();
      expect(controller.problem?.failure, CameraFailure.permissionDenied);
    });

    test('wraps unexpected errors as a generic failure', () async {
      controller = build(FakeCameraService(listError: StateError('boom')));
      await controller.initialize();
      expect(controller.problem?.failure, CameraFailure.failed);
      expect(controller.problem?.details, contains('boom'));
    });

    test('reports a problem when opening the camera fails', () async {
      controller = build(FakeCameraService(openError: const CameraAccessException(CameraFailure.failed, 'busy')));
      await controller.initialize();
      expect(controller.problem?.details, 'busy');
      expect(controller.camera, isNull);
    });
  });

  group('camera choice', () {
    test('never opens the front camera when a back camera exists', () async {
      await controller.initialize();
      expect(service.opened.map((s) => s.info.facing), everyElement(CameraFacing.back));
    });

    test('opens the front camera only when it is the only one', () async {
      service = FakeCameraService(cameras: [front]);
      controller = build(service);
      await controller.initialize();
      expect(controller.selectedCamera, front);
    });

    test('flash, torch and mode are kept on the opened camera', () async {
      await controller.initialize();
      await controller.cycleFlash();
      await controller.toggleTorch();
      expect(service.opened.single.flash, FlashSetting.auto);
      expect(service.opened.single.torch, isTrue);
    });
  });

  group('logical multi-camera (the phone switches lenses by itself)', () {
    setUp(() {
      service = FakeCameraService(
        cameras: [front, ultra, wide, tele],
        zoomRanges: {'wide': const ZoomRange(0.6, 10), 'ultra': const ZoomRange(1, 8), 'tele': const ZoomRange(1, 8)},
      );
      controller = build(service);
    });

    test('exposes the whole zoom range of the main camera', () async {
      await controller.initialize();
      expect(controller.usesVirtualLenses, isFalse);
      expect(controller.zoomRange.min, 0.6);
      expect(controller.zoomRange.max, 10);
    });

    test('zooming out below 1x does not open another camera', () async {
      await controller.initialize();
      await controller.setZoom(0.6);
      await controller.setZoom(5);
      expect(service.opened, hasLength(1));
      expect(service.opened.single.zoom, 5);
    });
  });

  group('separate lenses (the app switches lenses while zooming)', () {
    setUp(() {
      service = FakeCameraService(cameras: [front, ultra, wide, tele]);
      controller = build(service);
    });

    test('combines the lenses into one zoom range from 0.5x', () async {
      await controller.initialize();
      expect(controller.usesVirtualLenses, isTrue);
      expect(controller.zoomRange.min, 0.5);
      expect(controller.zoomRange.max, 8);
    });

    test('without an ultra wide lens the range starts at 1x', () async {
      service = FakeCameraService(cameras: [wide, tele]);
      controller = build(service);
      await controller.initialize();
      expect(controller.zoomRange.min, 1);
    });

    test('a single lens uses plain digital zoom', () async {
      service = FakeCameraService(cameras: [wide]);
      controller = build(service);
      await controller.initialize();
      expect(controller.usesVirtualLenses, isFalse);
      await controller.setZoom(3);
      expect(service.opened, hasLength(1));
    });

    test('zooming out below 1x switches to the ultra wide lens', () async {
      await controller.initialize();
      await controller.setZoom(0.6);
      expect(controller.selectedCamera, ultra);
      expect(service.opened.first.disposed, isTrue);
      expect(service.opened.last.zoom, closeTo(1.2, 1e-9));
      expect(controller.zoom, 0.6);
    });

    test('zooming back to 1x returns to the main lens', () async {
      await controller.initialize();
      await controller.setZoom(0.6);
      await controller.setZoom(1);
      expect(controller.selectedCamera, wide);
      expect(service.opened.last.info, wide);
      expect(service.opened.last.zoom, 1);
    });

    test('zooming in past 2x switches to the telephoto lens', () async {
      await controller.initialize();
      await controller.setZoom(2.5);
      expect(controller.selectedCamera, tele);
      expect(service.opened.last.zoom, closeTo(1.25, 1e-9));
    });

    test('between 1x and 2x the main lens keeps zooming digitally', () async {
      await controller.initialize();
      await controller.setZoom(1.5);
      expect(controller.selectedCamera, wide);
      expect(service.opened, hasLength(1));
      expect(service.opened.single.zoom, 1.5);
    });

    test('has hysteresis so the lens does not flap around 1x', () async {
      await controller.initialize();
      await controller.setZoom(0.9);
      expect(controller.selectedCamera, ultra);
      await controller.setZoom(0.97);
      expect(controller.selectedCamera, ultra);
      expect(service.opened, hasLength(2));
      await controller.setZoom(1.0);
      expect(controller.selectedCamera, wide);
    });

    test('has hysteresis so the lens does not flap around 2x', () async {
      await controller.initialize();
      await controller.setZoom(2.0);
      expect(controller.selectedCamera, tele);
      await controller.setZoom(1.95);
      expect(controller.selectedCamera, tele);
      await controller.setZoom(1.8);
      expect(controller.selectedCamera, wide);
    });

    test('keeps flash and torch when the lens changes', () async {
      await controller.initialize();
      await controller.cycleFlash();
      await controller.toggleTorch();
      await controller.setZoom(0.6);
      expect(service.opened.last.flash, FlashSetting.auto);
      expect(service.opened.last.torch, isTrue);
    });

    test('never opens the front camera', () async {
      await controller.initialize();
      await controller.setZoom(0.5);
      await controller.setZoom(3);
      expect(service.opened.map((s) => s.info), isNot(contains(front)));
    });

    test('the zoom requested during a lens change is not lost', () async {
      await controller.initialize();
      final first = controller.setZoom(0.6);
      final second = controller.setZoom(0.7);
      await Future.wait([first, second]);
      expect(controller.zoom, 0.7);
    });

    test('suspend and resume keep the active lens and zoom', () async {
      await controller.initialize();
      await controller.setZoom(0.6);
      await controller.suspend();
      await controller.resume();
      expect(controller.selectedCamera, ultra);
      expect(controller.zoom, 0.6);
    });
  });

  group('zoom', () {
    setUp(() {
      service = FakeCameraService(cameras: [wide]);
      controller = build(service);
    });

    test('clamps to the range of the camera', () async {
      await controller.initialize();
      await controller.setZoom(100);
      expect(controller.zoom, 8);
      await controller.setZoom(0.1);
      expect(controller.zoom, 1);
    });

    test('forwards the zoom to the camera', () async {
      await controller.initialize();
      await controller.setZoom(3);
      expect(service.opened.single.zoom, 3);
    });

    test('does not call the camera when the zoom does not change', () async {
      await controller.initialize();
      service.opened.single.calls.clear();
      await controller.setZoom(1);
      expect(service.opened.single.calls, isEmpty);
    });

    test('is ignored while there is no camera', () async {
      await controller.setZoom(3);
      expect(controller.zoom, 1);
    });
  });

  group('smooth zoom', () {
    late ScannerController smooth;

    setUp(() {
      service = FakeCameraService(cameras: [wide]);
      smooth = ScannerController(
        cameraService: service,
        session: buildSession(dir, processor: processor),
        zoomIdleDelay: const Duration(milliseconds: 40),
      );
    });

    tearDown(() => smooth.dispose());

    int count(String call) => service.opened.single.calls.where((c) => c == call).length;

    test('stops the frame stream while the zoom is changing, only once per gesture', () async {
      await smooth.initialize();
      for (final z in [1.2, 1.5, 1.8, 2.2, 2.8]) {
        await smooth.setZoom(z);
      }
      expect(count('stopFrames'), 1);
      expect(service.opened.single.streaming, isFalse);
    });

    test('restarts the stream shortly after the zoom stops', () async {
      await smooth.initialize();
      await smooth.setZoom(2);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(service.opened.single.streaming, isTrue);
      expect(count('startFrames'), 2);
    });

    test('keeps postponing the restart while the zoom keeps moving', () async {
      await smooth.initialize();
      for (var i = 0; i < 6; i++) {
        await smooth.setZoom(1.1 + i * 0.2);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(service.opened.single.streaming, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(service.opened.single.streaming, isTrue);
    });

    test('a new gesture after the restart pauses the stream again', () async {
      await smooth.initialize();
      await smooth.setZoom(2);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await smooth.setZoom(3);
      expect(count('stopFrames'), 2);
    });

    test('does not restart the stream while a photo is being taken', () async {
      await smooth.initialize();
      await smooth.setZoom(2);
      await smooth.capture();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(service.opened.single.streaming, isFalse);
      await smooth.finishCapture();
      expect(service.opened.single.streaming, isTrue);
    });

    test('does not touch the stream after the controller is disposed', () async {
      await smooth.initialize();
      final session = service.opened.single;
      await smooth.setZoom(2);
      smooth.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(session.calls.where((c) => c == 'startFrames'), hasLength(1));
      smooth = ScannerController(cameraService: service, session: buildSession(dir, processor: processor));
    });

    test('zoom changes do not rebuild the whole screen', () async {
      await smooth.initialize();
      var structural = 0;
      var zoomUpdates = 0;
      smooth.addListener(() => structural++);
      smooth.zoomListenable.addListener(() => zoomUpdates++);
      await smooth.setZoom(2);
      await smooth.setZoom(3);
      expect(structural, 0);
      expect(zoomUpdates, 2);
    });

    test('detected documents do not rebuild the whole screen either', () async {
      processor.detected = Quad.inset(0.2);
      await smooth.initialize();
      var structural = 0;
      var quadUpdates = 0;
      smooth.addListener(() => structural++);
      smooth.quadListenable.addListener(() => quadUpdates++);
      service.opened.single.emitFrame();
      await flush();
      await flush();
      expect(structural, 0);
      expect(quadUpdates, 1);
    });
  });

  group('flash and torch', () {
    test('flash cycles off, auto, always and back to off', () async {
      await controller.initialize();
      final seen = <FlashSetting>[];
      for (var i = 0; i < 4; i++) {
        await controller.cycleFlash();
        seen.add(controller.flash);
      }
      expect(seen, [FlashSetting.auto, FlashSetting.always, FlashSetting.off, FlashSetting.auto]);
    });

    test('torch toggles on the camera', () async {
      await controller.initialize();
      await controller.toggleTorch();
      expect(controller.torch, isTrue);
      expect(service.opened.single.torch, isTrue);
      await controller.toggleTorch();
      expect(service.opened.single.torch, isFalse);
    });
  });

  group('mode', () {
    test('defaults to single and can switch to batch', () async {
      expect(controller.mode, ScanMode.single);
      controller.setMode(ScanMode.batch);
      expect(controller.mode, ScanMode.batch);
    });

    test('notifies only when the mode actually changes', () async {
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.setMode(ScanMode.single);
      controller.setMode(ScanMode.batch);
      expect(notifications, 1);
    });
  });

  group('live detection', () {
    test('publishes the detected document', () async {
      processor.detected = Quad.inset(0.2);
      await controller.initialize();
      service.opened.single.emitFrame();
      await flush();
      await flush();
      expect(controller.quad, Quad.inset(0.2));
    });

    test('smooths consecutive detections', () async {
      processor.detected = Quad.inset(0.2);
      await controller.initialize();
      service.opened.single.emitFrame();
      await flush();
      await flush();
      processor.detected = Quad.inset(0.22);
      service.opened.single.emitFrame();
      await flush();
      await flush();
      expect(controller.quad!.points.first.x, closeTo(0.21, 1e-9));
    });

    test('forgets the document after several misses', () async {
      processor.detected = Quad.inset(0.2);
      await controller.initialize();
      service.opened.single.emitFrame();
      await flush();
      await flush();
      processor.detected = null;
      for (var i = 0; i < 4; i++) {
        service.opened.single.emitFrame();
        await flush();
        await flush();
      }
      expect(controller.quad, isNull);
    });
  });

  group('capture', () {
    test('stops the frames and returns the photo path', () async {
      await controller.initialize();
      final path = await controller.capture();
      expect(path, '${dir.path}/shot.jpg');
      expect(controller.capturing, isTrue);
      expect(service.opened.single.streaming, isFalse);
    });

    test('finishCapture restarts the frames and clears the document', () async {
      processor.detected = Quad.inset(0.2);
      await controller.initialize();
      service.opened.single.emitFrame();
      await flush();
      await flush();
      await controller.capture();
      await controller.finishCapture();
      expect(controller.capturing, isFalse);
      expect(controller.quad, isNull);
      expect(service.opened.single.streaming, isTrue);
    });

    test('throws when the camera is not ready', () async {
      expect(controller.capture(), throwsStateError);
    });

    test('ignores a second capture while one is in progress', () async {
      await controller.initialize();
      await controller.capture();
      expect(controller.capture(), throwsStateError);
    });

    test('recovers when the photo fails', () async {
      await controller.initialize();
      service.opened.single.takePictureError = StateError('no photo');
      await expectLater(controller.capture(), throwsStateError);
      expect(controller.capturing, isFalse);
      expect(service.opened.single.streaming, isTrue);
    });
  });

  group('lifecycle', () {
    test('suspend releases the camera and resume reopens the same one', () async {
      await controller.initialize();
      await controller.suspend();
      expect(controller.camera, isNull);
      await controller.resume();
      expect(controller.selectedCamera, wide);
      expect(controller.camera, isNotNull);
      expect(service.opened.last.info, wide);
    });

    test('resume before initialize behaves like initialize', () async {
      await controller.resume();
      expect(controller.isReady, isTrue);
    });

    test('pause and resume frames drive the camera stream', () async {
      await controller.initialize();
      await controller.pauseFrames();
      expect(service.opened.single.streaming, isFalse);
      await controller.resumeFrames();
      expect(service.opened.single.streaming, isTrue);
    });

    test('lifecycle events during the first open never open the camera twice', () async {
      service.openGate = Completer<void>();
      final initializing = controller.initialize();
      final suspending = controller.suspend();
      final resuming = controller.resume();
      await flush();
      service.openGate!.complete();
      await Future.wait([initializing, suspending, resuming]);
      expect(service.maxActive, 1);
      expect(service.opened.where((s) => !s.disposed), hasLength(1));
      expect(controller.isReady, isTrue);
    });

    test('rapid suspend and resume pairs end with a single open camera', () async {
      await controller.initialize();
      for (var i = 0; i < 5; i++) {
        unawaited(controller.suspend());
        unawaited(controller.resume());
      }
      await controller.resume();
      expect(service.maxActive, 1);
      expect(service.opened.where((s) => !s.disposed), hasLength(1));
    });

    test('zoom changes while suspended are applied when the camera comes back', () async {
      await controller.initialize();
      await controller.suspend();
      await controller.setZoom(3);
      await controller.resume();
      expect(controller.zoom, 3);
    });

    test('dispose releases the camera', () async {
      await controller.initialize();
      final session = service.opened.single;
      controller.dispose();
      await flush();
      expect(session.disposed, isTrue);
      controller = build(service);
    });
  });
}
