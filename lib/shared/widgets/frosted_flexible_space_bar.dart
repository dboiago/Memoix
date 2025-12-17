import 'package:flutter/material.dart';

/// Helper to build title shadows for header text over images.
/// Subtle, diffused shadow for readability plus soft outline.
List<Shadow> buildTitleShadows(bool isDark) {
  return [
    // Soft diffused shadow
    Shadow(offset: const Offset(0, 2), blurRadius: 12, color: Colors.black.withOpacity(0.4)),
    Shadow(offset: const Offset(0, 1), blurRadius: 3, color: Colors.black.withOpacity(0.3)),
    // Soft outline (slight blur to blend, low opacity for subtlety)
    Shadow(offset: const Offset(-0.5, -0.5), blurRadius: 1, color: Colors.black.withOpacity(0.25)),
    Shadow(offset: const Offset(0.5, -0.5), blurRadius: 1, color: Colors.black.withOpacity(0.25)),
    Shadow(offset: const Offset(-0.5, 0.5), blurRadius: 1, color: Colors.black.withOpacity(0.25)),
    Shadow(offset: const Offset(0.5, 0.5), blurRadius: 1, color: Colors.black.withOpacity(0.25)),
  ];
}

/// Helper to build icon shadows for header icons over images.
/// Lighter version suitable for icons plus soft outline.
List<Shadow> buildIconShadows(bool isDark) {
  return [
    // Soft diffused shadow
    Shadow(offset: const Offset(0, 1), blurRadius: 6, color: Colors.black.withOpacity(0.4)),
    Shadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withOpacity(0.3)),
    // Soft outline (slight blur to blend, low opacity for subtlety)
    Shadow(offset: const Offset(-0.5, 0), blurRadius: 1, color: Colors.black.withOpacity(0.25)),
    Shadow(offset: const Offset(0.5, 0), blurRadius: 1, color: Colors.black.withOpacity(0.25)),
    Shadow(offset: const Offset(0, -0.5), blurRadius: 1, color: Colors.black.withOpacity(0.25)),
    Shadow(offset: const Offset(0, 0.5), blurRadius: 1, color: Colors.black.withOpacity(0.25)),
  ];
}

/// Builds a gradient scrim overlay for images.
/// Dark at bottom (for title), subtle at top (for icons), transparent in middle.
Widget buildImageScrim({required bool isDark}) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withOpacity(0.4), // Darkening at top for icons
          Colors.black.withOpacity(0.1),
          Colors.black.withOpacity(0.2),
          Colors.black.withOpacity(0.7), // Strong darkening at bottom for title
        ],
        stops: const [0.0, 0.25, 0.5, 1.0],
      ),
    ),
  );
}
