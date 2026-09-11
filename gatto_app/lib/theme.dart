import 'package:flutter/material.dart';

const gattoGreen = Color(0xFF16A34A);
const gattoGreenDark = Color(0xFF14532D);
const gattoAmber = Color(0xFFF59E0B);
const gattoBg = Color(0xFFF0FDF4);

ThemeData gattoTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: gattoGreen,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: gattoBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: gattoGreenDark,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: gattoGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
  );
}
