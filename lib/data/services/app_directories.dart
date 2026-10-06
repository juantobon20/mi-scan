import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class AppDirectories {
  Future<Directory> documents();
  Future<Directory> temp();
}

class PathProviderDirectories implements AppDirectories {
  @override
  Future<Directory> documents() => getApplicationDocumentsDirectory();

  @override
  Future<Directory> temp() => getTemporaryDirectory();
}
