import 'dart:typed_data';

final _pageObject = RegExp(r'/Type\s*/Page(?![a-zA-Z])');

int countPdfPages(Uint8List bytes) => _pageObject.allMatches(String.fromCharCodes(bytes)).length;
