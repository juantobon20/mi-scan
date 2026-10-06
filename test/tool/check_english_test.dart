import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_english.dart';

void main() {
  final words = {'documento', 'guardar', 'para'};

  List<Violation> check(String text) => checkText('f.dart', text, words);

  test('accepts plain English code', () {
    expect(check("final title = 'Save document';"), isEmpty);
  });

  test('flags accented characters', () {
    final v = check("final t = 'Cámara';");
    expect(v.single.message, contains('non-English character'));
    expect(v.single.line, 1);
  });

  test('flags inverted punctuation and eñe', () {
    expect(check("'¿Eliminar?'"), isNotEmpty);
    expect(check("'año'"), isNotEmpty);
  });

  test('flags other scripts', () {
    expect(check("'Привет'"), isNotEmpty);
    expect(check("'文档'"), isNotEmpty);
  });

  test('flags unaccented Spanish words in strings and identifiers', () {
    expect(check("Text('Guardar')").single.message, contains('guardar'));
    expect(check('void guardarDocumento() {}').map((v) => v.message).join(), allOf(contains('guardar'), contains('documento')));
  });

  test('reports the right line number', () {
    expect(check("a\nb\nText('para')").single.line, 3);
  });

  test('ignores URLs', () {
    expect(check('// https://example.com/documento'), isEmpty);
  });

  test('allows typographic symbols used in docs', () {
    expect(check('A → B · C ├── ✓'), isEmpty);
  });

  test('is case-insensitive', () {
    expect(check("'GUARDAR'"), isNotEmpty);
  });

  test('does not flag English words that merely contain Spanish ones', () {
    expect(check('final parameter = paragraph;'), isEmpty);
  });
}
