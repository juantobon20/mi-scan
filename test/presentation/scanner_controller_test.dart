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
    test('lists all cameras and opens the main back camera', () async {
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

  group('lenses', () {
    test('switching camera releases the previous one and opens the new one', () async {
      await controller.initialize();
      await controller.selectCamera(ultra);
      expect(controller.selectedCamera, ultra);
      expect(service.opened.first.disposed, isTrue);
      expect(service.opened.last.info, ultra);
      expect(service.opened, hasLength(2));
    });

    test('selecting the active camera does nothing', () async {
      await controller.initialize();
      await controller.selectCamera(wide);
      expect(service.opened, hasLength(1));
    });

    test('flash, torch and mode survive a camera change', () async {
      await controller.initialize();
      await controller.cycleFlash();
      await controller.toggleTorch();
      await controller.selectCamera(tele);
      final session = service.opened.last;
      expect(session.flash, FlashSetting.auto);
      expect(session.torch, isTrue);
    });

    test('zoom is reset to 1x when changing camera', () async {
      await controller.initialize();
      await controller.setZoom(4);
      await controller.selectCamera(ultra);
      expect(controller.zoom, 1);
    });
  });

  group('zoom', () {
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
      await controller.selectCamera(tele);
      await controller.suspend();
      expect(controller.camera, isNull);
      await controller.resume();
      expect(controller.selectedCamera, tele);
      expect(controller.camera, isNotNull);
      expect(service.opened.last.info, tele);
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
