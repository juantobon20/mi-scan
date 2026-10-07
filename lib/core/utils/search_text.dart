const _accented = '\u00e1\u00e0\u00e4\u00e2\u00e3\u00e5\u00e9\u00e8\u00eb\u00ea\u00ed\u00ec\u00ef\u00ee\u00f3\u00f2\u00f6\u00f4\u00f5\u00fa\u00f9\u00fc\u00fb\u00f1\u00e7\u00c1\u00c0\u00c4\u00c2\u00c3\u00c5\u00c9\u00c8\u00cb\u00ca\u00cd\u00cc\u00cf\u00ce\u00d3\u00d2\u00d6\u00d4\u00d5\u00da\u00d9\u00dc\u00db\u00d1\u00c7';
const _plain = 'aaaaaaeeeeiiiiooooouuuuncaaaaaaeeeeiiiiooooouuuunc';

String normalizeSearchText(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final index = _accented.indexOf(char);
    out.write(index >= 0 ? _plain[index] : char.toLowerCase());
  }
  return out.toString().trim();
}

List<String> searchTokens(String text) =>
    normalizeSearchText(text).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
