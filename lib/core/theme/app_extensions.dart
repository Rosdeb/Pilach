import 'package:flutter/material.dart';

class CustomThemeExtension extends ThemeExtension<CustomThemeExtension> {
  final Color? cardColor;
  final LinearGradient? primaryGradient;
  final List<BoxShadow>? cardShadows;

  const CustomThemeExtension({
    required this.cardColor,
    required this.primaryGradient,
    required this.cardShadows,
  });

  @override
  CustomThemeExtension copyWith({
    Color? cardColor,
    LinearGradient? primaryGradient,
    List<BoxShadow>? cardShadows,
  }) {
    return CustomThemeExtension(
      cardColor: cardColor ?? this.cardColor,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      cardShadows: cardShadows ?? this.cardShadows,
    );
  }

  @override
  CustomThemeExtension lerp(ThemeExtension<CustomThemeExtension>? other, double t) {
    if (other is! CustomThemeExtension) {
      return this;
    }
    return CustomThemeExtension(
      cardColor: Color.lerp(cardColor, other.cardColor, t),
      primaryGradient: LinearGradient.lerp(primaryGradient, other.primaryGradient, t),
      cardShadows: other.cardShadows,
    );
  }
}
