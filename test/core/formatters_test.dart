import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/core/utils/formatters.dart';
import 'package:mi_scan/domain/entities/scan_filter.dart';

void main() {
  group('formatDocSubtitle', () {
    test('formats date with zero padding and size in KB', () {
      expect(formatDocSubtitle(DateTime(2026, 3, 5, 9, 7), 2048), '05/03/2026 09:07 · 2 KB');
    });

    test('switches to MB above 1024 KB', () {
      expect(formatDocSubtitle(DateTime(2026, 12, 25, 18, 30), 3 * 1024 * 1024), '25/12/2026 18:30 · 3.0 MB');
    });

    test('exactly 1024 KB is shown in KB', () {
      expect(formatDocSubtitle(DateTime(2026, 1, 1), 1024 * 1024), contains('1024 KB'));
    });
  });

  test('defaultScanName', () {
    expect(defaultScanName(DateTime(2026, 3, 5, 9, 7)), 'Scan 2026-03-05 09.07');
  });

  group('sanitizeFileName', () {
    test('replaces invalid characters', () {
      expect(sanitizeFileName(r'a/b\c:d*e?f"g<h>i|j'), 'a_b_c_d_e_f_g_h_i_j');
    });

    test('empty or whitespace-only → Document', () {
      expect(sanitizeFileName(''), 'Document');
      expect(sanitizeFileName('   '), 'Document');
    });

    test('trims whitespace and keeps accents', () {
      expect(sanitizeFileName('  Invoice year  '), 'Invoice year');
    });
  });

  test('silentDelete does not throw if the file does not exist', () {
    expect(() => silentDelete('/ruta/que/no/existe.jpg'), returnsNormally);
  });

  test('silentDelete deletes an existing file', () {
    final f = File('${Directory.systemTemp.path}/silent_${DateTime.now().microsecondsSinceEpoch}')..writeAsStringSync('x');
    silentDelete(f.path);
    expect(f.existsSync(), isFalse);
  });

  test('ScanFilter exposes display labels', () {
    expect(ScanFilter.values.map((f) => f.label), ['Original', 'Enhanced', 'Grayscale', 'B&W']);
  });
}
