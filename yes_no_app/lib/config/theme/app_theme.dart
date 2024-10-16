import 'package:flutter/material.dart';

const Color _customColor = Color(0xFF49149F);

const List<Color> _colorThemes = [
  _customColor,
  Colors.blue,
  Colors.red,
  Colors.orange,
  Colors.pink,
  Colors.blueAccent,
  Colors.greenAccent,
  Colors.white,
  Colors.black
];

class AppTheme {
  final int selectedColor;

  AppTheme({this.selectedColor = 0})
      : assert(selectedColor >= 0 && selectedColor <= _colorThemes.length-1,
            'El color debe ser un valor entre 0 y {$_colorThemes.length-1}');

  ThemeData theme() {
    return ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _colorThemes[selectedColor]);
  }
}
