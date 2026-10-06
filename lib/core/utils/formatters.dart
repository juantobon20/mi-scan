import 'dart:io';

String _two(int v) => v.toString().padLeft(2, '0');

String formatDocSubtitle(DateTime modified, int sizeBytes) {
  final kb = sizeBytes / 1024;
  final size = kb > 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.round()} KB';
  final m = modified;
  return '${_two(m.day)}/${_two(m.month)}/${m.year} ${_two(m.hour)}:${_two(m.minute)} · $size';
}

String defaultScanName(DateTime now) =>
    'Scan ${now.year}-${_two(now.month)}-${_two(now.day)} ${_two(now.hour)}.${_two(now.minute)}';

String sanitizeFileName(String name) {
  final s = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return s.isEmpty ? 'Document' : s;
}

void silentDelete(String path) {
  try {
    File(path).deleteSync();
  } catch (_) {}
}
