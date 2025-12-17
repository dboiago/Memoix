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

/// A custom FlexibleSpaceBar that shows a shadowed title only when expanded.
/// The title fades out as the app bar collapses, leaving the SliverAppBar.title
/// to show cleanly without shadows on the solid background.
class ExpandedTitleFlexibleSpace extends StatelessWidget {
  final String title;
  final List<Shadow>? titleShadows;
  final bool isDark;
  final Widget background;

  const ExpandedTitleFlexibleSpace({
    super.key,
    required this.title,
    required this.titleShadows,
    required this.isDark,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
        if (settings == null) {
          return _buildContent(1.0);
        }
        
        final deltaExtent = settings.maxExtent - settings.minExtent;
        // t goes from 0.0 (fully expanded) to 1.0 (fully collapsed)
        final t = deltaExtent > 0 
            ? (1.0 - (settings.currentExtent - settings.minExtent) / deltaExtent).clamp(0.0, 1.0)
            : 0.0;
        
        return _buildContent(1.0 - t); // opacity is inverse of collapse progress
      },
    );
  }

  Widget _buildContent(double titleOpacity) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        background,
        // Gradient scrim
        buildImageScrim(isDark: isDark),
        // Title - fades out as we collapse
        Positioned(
          left: 72, // Account for back button
          right: 72, // Account for action buttons
          bottom: 16,
          child: Opacity(
            opacity: titleOpacity,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: titleShadows,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
