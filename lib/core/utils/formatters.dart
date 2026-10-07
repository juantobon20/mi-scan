import 'dart:io';

import 'package:intl/intl.dart';

String _two(int v) => v.toString().padLeft(2, '0');

String formatDocSubtitle(DateTime modified, int sizeBytes, {String locale = 'en'}) {
  final kb = sizeBytes / 1024;
  final size = kb > 1024 ? '${NumberFormat('0.0', locale).format(kb / 1024)} MB' : '${kb.round()} KB';
  final date = DateFormat.yMd(locale).add_Hm().format(modified);
  return '$date · $size';
}

String formatScanTimestamp(DateTime now) =>
    '${now.year}-${_two(now.month)}-${_two(now.day)} ${_two(now.hour)}.${_two(now.minute)}';

String sanitizeFileName(String name) {
  final s = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return s.isEmpty ? 'Document' : s;
}

void silentDelete(String path) {
  try {
    File(path).deleteSync();
  } catch (_) {}
}
