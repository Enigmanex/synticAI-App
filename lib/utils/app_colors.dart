import 'package:flutter/material.dart';

/// Brand colors matching the Syntic AI logo
/// Primary color: #0175C2 (from manifest.json)
class AppColors {
  // Primary brand color (matches logo)
  static const Color primary = Color(0xFF0175C2);
  static const Color primaryDark = Color(0xFF025A8F);
  static const Color primaryLight = Color(0xFF03A9F4);
  
  // Gradient colors
  static const Color gradientStart = Color(0xFF0175C2);
  static const Color gradientEnd = Color(0xFF025A8F);
  
  // Background gradient colors (light tints)
  static Color backgroundLight = const Color(0xFF0175C2).withOpacity(0.1);
  static Color backgroundMedium = const Color(0xFF0175C2).withOpacity(0.15);
  
  // Accent colors
  static const Color accent = Color(0xFF03A9F4);
  
  // Helper method to get primary color shades
  static MaterialColor get primarySwatch {
    return MaterialColor(
      primary.value,
      <int, Color>{
        50: const Color(0xFFE3F2FD),
        100: const Color(0xFFBBDEFB),
        200: const Color(0xFF90CAF9),
        300: const Color(0xFF64B5F6),
        400: const Color(0xFF42A5F5),
        500: primary,
        600: primaryDark,
        700: const Color(0xFF01579B),
        800: const Color(0xFF014377),
        900: const Color(0xFF002F54),
      },
    );
  }
  
  // Get gradient for app bars and cards
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Get light background gradient
  static LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      backgroundLight,
      backgroundMedium,
      Colors.white,
    ],
  );
}

