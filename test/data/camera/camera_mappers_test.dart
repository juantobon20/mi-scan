import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/data/services/camera/camera_mappers.dart';
import 'package:mi_scan/domain/entities/camera_info.dart';

void main() {
  group('facingFrom', () {
    test('maps every plugin direction', () {
      expect(facingFrom(CameraLensDirection.back), CameraFacing.back);
      expect(facingFrom(CameraLensDirection.front), CameraFacing.front);
      expect(facingFrom(CameraLensDirection.external), CameraFacing.external);
    });
  });

  group('lensFrom', () {
    test('maps every plugin lens type', () {
      expect(lensFrom(CameraLensType.wide), CameraLens.wide);
      expect(lensFrom(CameraLensType.ultraWide), CameraLens.ultraWide);
      expect(lensFrom(CameraLensType.telephoto), CameraLens.telephoto);
      expect(lensFrom(CameraLensType.unknown), CameraLens.unknown);
    });
  });

  group('flashModeFor', () {
    test('maps the flash settings', () {
      expect(flashModeFor(FlashSetting.off, torch: false), FlashMode.off);
      expect(flashModeFor(FlashSetting.auto, torch: false), FlashMode.auto);
      expect(flashModeFor(FlashSetting.always, torch: false), FlashMode.always);
    });

    test('torch wins over any flash setting', () {
      for (final flash in FlashSetting.values) {
        expect(flashModeFor(flash, torch: true), FlashMode.torch);
      }
    });
  });

  test('infoFrom copies every field of the description', () {
    const description = CameraDescription(
      name: '2',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 270,
      lensType: CameraLensType.ultraWide,
    );
    expect(
      infoFrom(description),
      const CameraInfo(id: '2', facing: CameraFacing.back, lens: CameraLens.ultraWide, sensorOrientation: 270),
    );
  });
}
