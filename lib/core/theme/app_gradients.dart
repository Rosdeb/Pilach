import 'package:flutter/material.dart';
import 'package:messageapp/core/utils/app_colour.dart';

class AppGradients {
  static LinearGradient get primary => LinearGradient(
        colors: AppColors.isDarkMode
            ? [const Color(0xFF1E3A8A), const Color(0xFF2563EB)]
            : [const Color(0xFF2563EB), const Color(0xFF60A5FA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get success => LinearGradient(
        colors: AppColors.isDarkMode
            ? [const Color(0xFF065F46), const Color(0xFF10B981)]
            : [const Color(0xFF10B981), const Color(0xFF34D399)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get error => LinearGradient(
        colors: AppColors.isDarkMode
            ? [const Color(0xFF991B1B), const Color(0xFFEF4444)]
            : [const Color(0xFFEF4444), const Color(0xFFF87171)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get premium => const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get gold => const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get purple => const LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get green => const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF34D399)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get blue => const LinearGradient(
        colors: [Color(0xFF1D4ED8), Color(0xFF93C5FD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
