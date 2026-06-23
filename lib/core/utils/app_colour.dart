import 'package:flutter/material.dart';

class ThemeColor extends Color {
  final int lightValue;
  final int darkValue;

  const ThemeColor(this.lightValue, this.darkValue) : super(lightValue);

  @override
  int get value => AppColors.isDarkMode ? darkValue : lightValue;
}

class AppColors {
  static bool isDarkMode = false;

  static const Color primary = ThemeColor(0xFF2563EB, 0xFF2563EB);
  static const Color background = ThemeColor(0xFFF0F4F8, 0xFF0F172A);
  static const Color white_bg = ThemeColor(0xFFFFFFFF, 0xFF1E293B);
  static const Color background_s1 = ThemeColor(0xFFDFF1F1, 0xFF112D2D);
  static const Color background_s2 = ThemeColor(0xFFB8D8DA, 0xFF1A3E40);
  
  static const Color textWhite = ThemeColor(0xFFFFFFFF, 0xFFFFFFFF);
  static const Color textDark = ThemeColor(0xFF0F172A, 0xFFF8FAFC);
  static const Color textLight = ThemeColor(0xFF64748B, 0xFF94A3B8);

  //border colour
  static const Color border = ThemeColor(0xFFA4A4A5, 0xFF334155);
  static const Color black_border = ThemeColor(0xFF0F172A, 0xFFF8FAFC);
  static const Color back_icon = ThemeColor(0xFF0F172A, 0xFFF8FAFC);

  // --- NEW ADDED COLORS ---
  static const Color successGreen = ThemeColor(0xFF34C759, 0xFF34C759);
  static const Color destructiveRed = ThemeColor(0xFFFF3B30, 0xFFFF3B30);
}