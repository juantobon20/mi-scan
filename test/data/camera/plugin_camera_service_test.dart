import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/data/services/camera/plugin_camera_service.dart';
import 'package:mi_scan/domain/entities/camera_info.dart';
import 'package:mi_scan/domain/services/camera_service.dart';

void main() {
  const back = CameraDescription(name: '0', lensDirection: CameraLensDirection.back, sensorOrientation: 90);
  const ultra = CameraDescription(
    name: '2',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
    lensType: CameraLensType.ultraWide,
  );
  const front = CameraDescription(name: '1', lensDirection: CameraLensDirection.front, sensorOrientation: 270);

  test('lists every camera the plugin reports, keeping lens and facing', () async {
    final service = PluginCameraService(loadCameras: () async => [back, ultra, front]);
    final cameras = await service.listCameras();
    expect(cameras.map((c) => c.id), ['0', '2', '1']);
    expect(cameras[1].lens, CameraLens.ultraWide);
    expect(cameras[2].facing, CameraFacing.front);
    expect(cameras[2].sensorOrientation, 270);
  });

  test('translates a permission error into a domain exception', () {
    final service = PluginCameraService(
      loadCameras: () async => throw CameraException('CameraAccessDenied', 'denied'),
    );
    expect(
      service.listCameras(),
      throwsA(isA<CameraAccessException>().having((e) => e.failure, 'failure', CameraFailure.permissionDenied)),
    );
  });

  test('translates any other plugin error into a generic failure', () {
    final service = PluginCameraService(loadCameras: () async => throw CameraException('boom', 'broken'));
    expect(
      service.listCameras(),
      throwsA(
        isA<CameraAccessException>()
            .having((e) => e.failure, 'failure', CameraFailure.failed)
            .having((e) => e.details, 'details', 'broken'),
      ),
    );
  });

  test('opening a camera that was never listed reports it as unavailable', () {
    final service = PluginCameraService(loadCameras: () async => [back]);
    expect(
      service.open(const CameraInfo(id: 'missing', facing: CameraFacing.back)),
      throwsA(isA<CameraAccessException>().having((e) => e.failure, 'failure', CameraFailure.unavailable)),
    );
  });
}
