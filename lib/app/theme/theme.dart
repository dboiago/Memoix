import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MemoixTheme {
  MemoixTheme._();

  // Dark Theme Colors
  static const darkBackground = Color(0xFF1A1A1A);   // #1a1a1a
  static const darkSurface = Color(0xFF242424);       // #242424 (card)
  static const darkPrimaryText = Color(0xFFE8D5C4);   // #e8d5c4 (foreground)
  static const darkAccent1 = Color(0xFFA88FA8);       // #a88fa8 (secondary)
  static const darkAccent2 = Color(0xFFE8B4A0);       // #e8b4a0 (primary)
  static const darkMuted = Color(0xFF9B9B9B);         // #9b9b9b (muted-foreground)

  // Light Theme Colors
  static const lightBackground = Color(0xFFFAF9F7); // #faf9f7
  static const lightSurface = Color(0xFFFFFFFF);     // #fff (card)
  static const lightPrimaryText = Color(0xFF4B5563); // #4b5563 (foreground)
  static const lightAccent1 = Color(0xFFCBB2BF);     // #cbb2bf (secondary)
  static const lightAccent2 = Color(0xFFD9C2B0);     // #d9c2b0 (primary)
  static const lightMuted = Color(0xFF9CA3AF);       // #9ca3af

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: lightAccent2,
        onPrimary: Colors.white,
        secondary: lightAccent1,
        onSecondary: lightPrimaryText,
        secondaryContainer: Color(0xFFE8DDD4), // warm cream for selected chips
        onSecondaryContainer: lightPrimaryText, // #4b5563 charcoal for text on warm bg
        surface: lightSurface,
        onSurface: lightPrimaryText,
        surfaceContainerHighest: Color(0xFFF0EFED), // neutral light gray (not warm accent)
        onSurfaceVariant: lightMuted, // #9ca3af grey for subtle text
        error: Color(0xFFDC2626),
        onError: Colors.white,
        outline: lightMuted,
      ),
      scaffoldBackgroundColor: lightBackground,
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: lightPrimaryText,
        displayColor: lightPrimaryText,
      ),
      appBarTheme: const AppBarTheme(
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
          borderSide: const BorderSide(color: lightAccent2, width: 2),
        ),
      ),
      // Rounded corners for list tiles (ExpansionTile, ListTile, etc.)
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Rounded corners for expansion tiles
      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Rounded corners for dialogs
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      // Rounded corners for bottom sheets
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      // Rounded corners for popup menus
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Rounded corners for dropdown menus
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: darkAccent2,
        onPrimary: darkBackground,
        secondary: darkAccent1,
        onSecondary: darkPrimaryText,
        secondaryContainer: Color(0xFF3D3A38), // warm dark for selected chips
        onSecondaryContainer: darkPrimaryText, // light text for dark mode
        surface: darkSurface,
        onSurface: darkPrimaryText,
        surfaceContainerHighest: Color(0xFF2D2D2D), // muted/accent bg
        onSurfaceVariant: darkMuted, // #9b9b9b grey for subtle text
        error: Color(0xFFEF4444),
        onError: darkBackground,
        outline: darkMuted,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: darkPrimaryText,
        displayColor: darkPrimaryText,
      ),
      appBarTheme: const AppBarTheme(
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
          borderSide: const BorderSide(color: darkAccent2, width: 2),
        ),
      ),
      // Rounded corners for list tiles (ExpansionTile, ListTile, etc.)
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Rounded corners for expansion tiles
      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Rounded corners for dialogs
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      // Rounded corners for bottom sheets
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      // Rounded corners for popup menus
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Rounded corners for dropdown menus
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}