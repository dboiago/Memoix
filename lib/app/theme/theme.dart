import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MemoixTheme {
  MemoixTheme._();

  // Dark Theme Colors
  static const darkBackground = Color(0xFF0F1A26);
  static const darkSurface = Color(0xFF1A2A3A);
  static const darkPrimaryText = Color(0xFFE0E7FF);
  static const darkAccent1 = Color(0xFFC68FA0); // mauve
  static const darkAccent2 = Color(0xFFFF9A4A); // peach
  static const darkMuted = Color(0xFF6B7280);

  // Light Theme Colors
  static const lightBackground = Color(0xFFF8FAFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightPrimaryText = Color(0xFF1E293B);
  static const lightAccent1 = Color(0xFFD4A9B8); // lighter mauve
  static const lightAccent2 = Color(0xFFFFB894); // brighter peach
  static const lightMuted = Color(0xFF64748B);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: lightAccent2,
        onPrimary: Colors.white,
        secondary: lightAccent1,
        onSecondary: lightPrimaryText,
        surface: lightSurface,
        onSurface: lightPrimaryText,
        background: lightBackground,
        onBackground: lightPrimaryText,
        error: const Color(0xFFDC2626),
        onError: Colors.white,
        outline: lightMuted,
      ),
      scaffoldBackgroundColor: lightBackground,
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: lightPrimaryText,
        displayColor: lightPrimaryText,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: lightSurface,
        foregroundColor: lightPrimaryText,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurface,
        side: BorderSide(color: lightMuted.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightMuted.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightMuted.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightAccent2, width: 2),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: darkAccent2,
        onPrimary: darkBackground,
        secondary: darkAccent1,
        onSecondary: darkPrimaryText,
        surface: darkSurface,
        onSurface: darkPrimaryText,
        background: darkBackground,
        onBackground: darkPrimaryText,
        error: const Color(0xFFEF4444),
        onError: darkBackground,
        outline: darkMuted,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: darkPrimaryText,
        displayColor: darkPrimaryText,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: darkSurface,
        foregroundColor: darkPrimaryText,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        side: BorderSide(color: darkMuted.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkMuted.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkMuted.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkAccent2, width: 2),
        ),
      ),
    );
  }
}