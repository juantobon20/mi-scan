import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/core/utils/id_generator.dart';
import 'package:mi_scan/core/utils/search_text.dart';

void main() {
  group('normalizeSearchText', () {
    test('lowercases', () {
      expect(normalizeSearchText('HeLLo'), 'hello');
    });

    test('removes Spanish accents and the tilde of the n', () {
      expect(normalizeSearchText('Declaraci\u00f3n'), 'declaracion');
      expect(normalizeSearchText('A\u00d1O GRANDE'), 'ano grande');
      expect(normalizeSearchText('ping\u00fcino'), 'pinguino');
    });

    test('removes other common Latin accents', () {
      expect(normalizeSearchText('Cr\u00e8me br\u00fbl\u00e9e \u00e0 la fa\u00e7on'), 'creme brulee a la facon');
    });

    test('keeps digits and symbols', () {
      expect(normalizeSearchText('Invoice #42 (2026)'), 'invoice #42 (2026)');
    });

    test('trims the ends', () {
      expect(normalizeSearchText('  hi  '), 'hi');
    });

    test('an empty string stays empty', () {
      expect(normalizeSearchText(''), '');
    });
  });

  group('searchTokens', () {
    test('splits on any amount of whitespace', () {
      expect(searchTokens('  Invoice   MARCH\tnow '), ['invoice', 'march', 'now']);
    });

    test('blank text has no tokens', () {
      expect(searchTokens('   '), isEmpty);
    });

    test('normalizes every token', () {
      expect(searchTokens('Declaraci\u00f3n A\u00f1o'), ['declaracion', 'ano']);
    });
  });

  group('generateId', () {
    test('produces distinct ids', () {
      final ids = {for (var i = 0; i < 2000; i++) generateId()};
      expect(ids, hasLength(2000));
    });

    test('ids are not empty and use only safe characters', () {
      expect(generateId(), matches(RegExp(r'^[a-z0-9]+$')));
    });
  });
}
