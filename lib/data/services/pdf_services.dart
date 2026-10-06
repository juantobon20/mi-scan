import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/scan_page.dart';
import '../../domain/services/pdf_generator.dart';

class PdfPackageGenerator implements PdfGenerator {
  @override
  Future<Uint8List> generate(List<ScanPage> pages) async {
    final doc = pw.Document();
    for (final page in pages) {
      final image = pw.MemoryImage(await File(page.path).readAsBytes());
      doc.addPage(pw.Page(
        pageFormat: page.isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ));
    }
    return doc.save();
  }
}

class UiThumbnailGenerator implements ThumbnailGenerator {
  @override
  Future<Uint8List> generate(String imagePath) async {
    final codec = await ui.instantiateImageCodec(await File(imagePath).readAsBytes(), targetWidth: 240);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}
