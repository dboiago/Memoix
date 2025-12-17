import 'package:flutter/material.dart';

/// Helper to build title shadows for header text over images.
/// Subtle, diffused shadow for readability plus black outline/stroke.
List<Shadow> buildTitleShadows(bool isDark) {
  return [
    // Soft diffused shadow
    Shadow(offset: const Offset(0, 2), blurRadius: 12, color: Colors.black.withOpacity(0.4)),
    Shadow(offset: const Offset(0, 1), blurRadius: 3, color: Colors.black.withOpacity(0.3)),
    // Black outline/stroke (no blur, offset in all directions)
    const Shadow(offset: Offset(-1, -1), blurRadius: 0, color: Colors.black54),
    const Shadow(offset: Offset(1, -1), blurRadius: 0, color: Colors.black54),
    const Shadow(offset: Offset(-1, 1), blurRadius: 0, color: Colors.black54),
    const Shadow(offset: Offset(1, 1), blurRadius: 0, color: Colors.black54),
  ];
}

/// Helper to build icon shadows for header icons over images.
/// Lighter version suitable for icons plus black outline/stroke.
List<Shadow> buildIconShadows(bool isDark) {
  return [
    // Soft diffused shadow
    Shadow(offset: const Offset(0, 1), blurRadius: 6, color: Colors.black.withOpacity(0.4)),
    Shadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withOpacity(0.3)),
    // Black outline/stroke (no blur, offset in all directions)
    const Shadow(offset: Offset(-1, 0), blurRadius: 0, color: Colors.black54),
    const Shadow(offset: Offset(1, 0), blurRadius: 0, color: Colors.black54),
    const Shadow(offset: Offset(0, -1), blurRadius: 0, color: Colors.black54),
    const Shadow(offset: Offset(0, 1), blurRadius: 0, color: Colors.black54),
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
