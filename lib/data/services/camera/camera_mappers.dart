import 'package:camera/camera.dart';

import '../../../domain/entities/camera_info.dart';

CameraFacing facingFrom(CameraLensDirection direction) => switch (direction) {
      CameraLensDirection.back => CameraFacing.back,
      CameraLensDirection.front => CameraFacing.front,
      CameraLensDirection.external => CameraFacing.external,
    };

CameraLens lensFrom(CameraLensType type) => switch (type) {
      CameraLensType.wide => CameraLens.wide,
      CameraLensType.ultraWide => CameraLens.ultraWide,
      CameraLensType.telephoto => CameraLens.telephoto,
      CameraLensType.unknown => CameraLens.unknown,
    };

FlashMode flashModeFor(FlashSetting flash, {required bool torch}) {
  if (torch) return FlashMode.torch;
  return switch (flash) {
    FlashSetting.off => FlashMode.off,
    FlashSetting.auto => FlashMode.auto,
    FlashSetting.always => FlashMode.always,
  };
}

CameraInfo infoFrom(CameraDescription description) => CameraInfo(
      id: description.name,
      facing: facingFrom(description.lensDirection),
      lens: lensFrom(description.lensType),
      sensorOrientation: description.sensorOrientation,
    );
