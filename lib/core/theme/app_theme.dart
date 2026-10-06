import 'package:flutter/material.dart';

const kScanColor = Color(0xFF1ABC9C);

abstract final class AppTheme {
  static ThemeData get light => ThemeData(colorSchemeSeed: kScanColor, useMaterial3: true);

  static ThemeData get dark =>
      ThemeData(colorSchemeSeed: kScanColor, useMaterial3: true, brightness: Brightness.dark);
}
