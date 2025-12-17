import 'package:flutter/material.dart';

/// Helper to build title shadows for header text over images.
/// Subtle, diffused shadow for readability without being heavy.
List<Shadow> buildTitleShadows(bool isDark) {
  // Same shadows work well for both themes over images
  return [
    Shadow(offset: const Offset(0, 2), blurRadius: 12, color: Colors.black.withOpacity(0.4)),
    Shadow(offset: const Offset(0, 1), blurRadius: 3, color: Colors.black.withOpacity(0.3)),
  ];
}

/// Helper to build icon shadows for header icons over images.
/// Lighter version suitable for icons.
List<Shadow> buildIconShadows(bool isDark) {
  return [
    Shadow(offset: const Offset(0, 1), blurRadius: 6, color: Colors.black.withOpacity(0.4)),
    Shadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withOpacity(0.3)),
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
          Colors.black.withOpacity(0.25), // Subtle darkening at top for icons
          Colors.transparent,
          Colors.transparent,
          Colors.black.withOpacity(0.55), // Darker at bottom for title
        ],
        stops: const [0.0, 0.2, 0.5, 1.0],
      ),
    ),
  );
}
