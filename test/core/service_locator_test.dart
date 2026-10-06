import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/core/di/service_locator.dart';
import 'package:mi_scan/domain/repositories/document_repository.dart';
import 'package:mi_scan/domain/services/image_processor.dart';
import 'package:mi_scan/presentation/home/home_controller.dart';
import 'package:mi_scan/presentation/scanner/scan_session.dart';

void main() {
  setUp(() async {
    await sl.reset();
    configureDependencies();
  });

  tearDown(sl.reset);

  test('the dependency graph resolves completely', () {
    expect(sl<DocumentRepository>(), isNotNull);
    expect(sl<ImageProcessor>(), isNotNull);
    expect(sl<ScanSessionFactory>(), isNotNull);
  });

  test('HomeController is a factory (new instance per use)', () {
    expect(identical(sl<HomeController>(), sl<HomeController>()), isFalse);
  });

  test('the repository is a singleton', () {
    expect(identical(sl<DocumentRepository>(), sl<DocumentRepository>()), isTrue);
  });
}
