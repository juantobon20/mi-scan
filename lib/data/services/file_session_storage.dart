import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/services/share_service.dart';
import 'app_directories.dart';

class FileSessionStorage implements SessionStorage {
  FileSessionStorage(this._dirs);
  final AppDirectories _dirs;

  @override
  Future<String> createSessionDir() async {
    final base = await _dirs.temp();
    final dir = Directory(p.join(base.path, 'session_${DateTime.now().microsecondsSinceEpoch}'))
      ..createSync(recursive: true);
    return dir.path;
  }
}
