import '../entities/quad.dart';
import '../entities/scan_filter.dart';
import '../entities/scan_page.dart';

abstract interface class ImageProcessor {
  Future<Quad?> detectInFrame(GrayFrame frame);

  Future<Quad?> detectInFile(String path);

  Future<ImageSize> normalize(String src, String dst);

  Future<void> crop(String src, String dst, Quad quad, ScanFilter filter);

  Future<ImageSize> rotate(String path);

  Future<void> applyFilter(String src, String dst, ScanFilter filter, {int maxSide = 1600});
}
