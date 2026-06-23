import 'package:flutter/material.dart';

final ColorScheme lightColorScheme = const ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF2563EB),
  onPrimary: Colors.white,
  secondary: Color(0xFF10B981),
  onSecondary: Colors.white,
  error: Colors.red,
  onError: Colors.white,
  background: Color(0xFFF8FAFC),
  onBackground: Color(0xFF0F172A),
  surface: Colors.white,
  onSurface: Color(0xFF0F172A),
);

final ThemeData lightThemeData = ThemeData(
  useMaterial3: true,
  colorScheme: lightColorScheme,
  scaffoldBackgroundColor: lightColorScheme.background,
  dividerColor: const Color(0xFFE2E8F0),
  dividerTheme: const DividerThemeData(
    color: Color(0xFFE2E8F0),
    thickness: 0.5,
  ),

  // Text
  textTheme: const TextTheme(
    headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(fontSize: 14),
  ),

  // AppBar
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    backgroundColor: Color(0xFF2563EB),
    foregroundColor: Colors.white,
  ),

  // Button
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),

  // Input
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey.shade100,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),
);
