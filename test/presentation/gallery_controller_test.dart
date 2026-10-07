import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/gallery_image.dart';
import 'package:mi_scan/presentation/gallery/gallery_controller.dart';

import '../helpers/fakes.dart';

void main() {
  late Directory dir;
  late FakeGalleryService service;
  late GalleryController controller;

  GalleryController build({int pageSize = 90}) =>
      GalleryController(service: service, directory: dir.path, pageSize: pageSize);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gallery_controller_test_');
    service = FakeGalleryService(count: 5);
    controller = build();
  });

  tearDown(() {
    controller.dispose();
    dir.deleteSync(recursive: true);
  });

  test('starts loading', () {
    expect(controller.status, GalleryStatus.loading);
  });

  test('loads the first page when access is granted', () async {
    await controller.initialize();
    expect(controller.status, GalleryStatus.ready);
    expect(controller.images, hasLength(5));
  });

  test('reports denied access without loading images', () async {
    service.access = GalleryAccess.denied;
    await controller.initialize();
    expect(controller.status, GalleryStatus.denied);
    expect(controller.images, isEmpty);
  });

  test('openSettings goes through the service', () async {
    await controller.openSettings();
    expect(service.settingsOpened, 1);
  });

  group('pagination', () {
    test('loadMore appends the next page until the end', () async {
      service = FakeGalleryService(count: 5);
      controller = build(pageSize: 2);
      await controller.initialize();
      expect(controller.images, hasLength(2));
      await controller.loadMore();
      expect(controller.images, hasLength(4));
      await controller.loadMore();
      expect(controller.images, hasLength(5));
      await controller.loadMore();
      expect(controller.images, hasLength(5));
    });

    test('does not load again once the last page was short', () async {
      await controller.initialize();
      await controller.loadMore();
      expect(controller.images, hasLength(5));
    });
  });

  group('selection', () {
    test('keeps the order in which images were picked', () async {
      await controller.initialize();
      final a = controller.images[3], b = controller.images[1];
      controller.toggle(a);
      controller.toggle(b);
      expect(controller.selected, [a, b]);
      expect(controller.selectionIndex(a), 0);
      expect(controller.selectionIndex(b), 1);
      expect(controller.selectedCount, 2);
    });

    test('toggling twice unselects', () async {
      await controller.initialize();
      final a = controller.images.first;
      controller.toggle(a);
      controller.toggle(a);
      expect(controller.selectedCount, 0);
      expect(controller.selectionIndex(a), -1);
    });

    test('initialize clears a previous selection', () async {
      await controller.initialize();
      controller.toggle(controller.images.first);
      await controller.initialize();
      expect(controller.selectedCount, 0);
    });
  });

  group('confirm', () {
    test('exports every selected image as a JPEG inside the session directory', () async {
      await controller.initialize();
      controller.toggle(controller.images[2]);
      controller.toggle(controller.images[0]);
      final paths = await controller.confirm();
      expect(paths, hasLength(2));
      expect(paths.every((p) => p.startsWith(dir.path) && p.endsWith('.jpg')), isTrue);
      expect(paths.every((p) => File(p).existsSync()), isTrue);
      expect(service.exported, ['img2', 'img0']);
      expect(controller.working, isFalse);
    });

    test('skips images that fail to export', () async {
      await controller.initialize();
      service.failExport = {'img1'};
      controller.toggle(controller.images[0]);
      controller.toggle(controller.images[1]);
      expect(await controller.confirm(), hasLength(1));
    });

    test('returns nothing when no image is selected', () async {
      await controller.initialize();
      expect(await controller.confirm(), isEmpty);
    });
  });

  test('thumbnail results are cached per image', () async {
    await controller.initialize();
    final image = controller.images.first;
    expect(identical(controller.thumbnail(image), controller.thumbnail(image)), isTrue);
    expect(await controller.thumbnail(image), isNotNull);
    expect(controller.thumbnail(const GalleryImage('other')), isNot(same(controller.thumbnail(image))));
  });
}
