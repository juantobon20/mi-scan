import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import '../../domain/entities/gallery_image.dart';
import '../../domain/services/gallery_service.dart';

class PhotoManagerGalleryService implements GalleryService {
  AssetPathEntity? _album;
  final _entities = <String, AssetEntity>{};

  @override
  Future<GalleryAccess> requestAccess() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) return GalleryAccess.denied;
    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
      filterOption: FilterOptionGroup(orders: [const OrderOption(type: OrderOptionType.createDate)]),
    );
    _album = albums.isEmpty ? null : albums.first;
    _entities.clear();
    return GalleryAccess.granted;
  }

  @override
  Future<List<GalleryImage>> loadPage({required int page, required int size}) async {
    final album = _album;
    if (album == null) return const [];
    final assets = await album.getAssetListPaged(page: page, size: size);
    for (final asset in assets) {
      _entities[asset.id] = asset;
    }
    return [for (final asset in assets) GalleryImage(asset.id)];
  }

  @override
  Future<Uint8List?> thumbnail(GalleryImage image, {required int size}) =>
      _entities[image.id]?.thumbnailDataWithSize(ThumbnailSize.square(size)) ?? Future.value(null);

  @override
  Future<bool> exportJpeg(GalleryImage image, String destinationPath) async {
    final bytes = await _entities[image.id]?.thumbnailDataWithSize(
      const ThumbnailSize(2800, 2800),
      format: ThumbnailFormat.jpeg,
      quality: 92,
    );
    if (bytes == null) return false;
    await File(destinationPath).writeAsBytes(bytes);
    return true;
  }

  @override
  Future<void> openSettings() => PhotoManager.openSetting();
}
