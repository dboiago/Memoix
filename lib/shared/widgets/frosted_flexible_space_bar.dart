import 'dart:ui';
import 'package:flutter/material.dart';

/// Custom FlexibleSpaceBar with frosted glass effect behind the title.
/// Provides better text readability over images using backdrop blur
/// and gradient scrim instead of heavy text shadows.
class FrostedFlexibleSpaceBar extends StatelessWidget {
  final String title;
  final List<Shadow>? titleShadows;
  final bool isDark;
  final Widget background;

  const FrostedFlexibleSpaceBar({
    super.key,
    required this.title,
    required this.isDark,
    required this.background,
    this.titleShadows,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
        final double deltaExtent = settings != null 
            ? settings.maxExtent - settings.minExtent 
            : constraints.maxHeight - kToolbarHeight;
        final double t = settings != null 
            ? (1.0 - (settings.currentExtent - settings.minExtent) / deltaExtent).clamp(0.0, 1.0) 
            : 0.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            background,
            
            // Gradient scrim - dark at top (for icons) and bottom (for title)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Colors.black.withOpacity(0.5),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ]
                      : [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                  stops: const [0.0, 0.25, 0.5, 1.0],
                ),
              ),
            ),
            
            // Frosted glass bar behind title at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 56 + MediaQuery.of(context).padding.bottom * 0.5,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                Colors.black.withOpacity(0.0),
                                Colors.black.withOpacity(0.3),
                              ]
                            : [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.15),
                              ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Title text positioned at bottom-left
            Positioned(
              left: 16 + 56 * t, // Animate towards the center as it collapses
              right: 16,
              bottom: 16,
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20 - 2 * t, // Scale down slightly when collapsed
                  color: Colors.white,
                  shadows: titleShadows,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Helper to build title shadows for use with FrostedFlexibleSpaceBar.
/// These are minimal shadows since the backdrop blur does most of the work.
List<Shadow> buildTitleShadows(bool isDark) {
  return isDark 
      ? [
          const Shadow(blurRadius: 4, color: Colors.black87, offset: Offset(0, 1)),
        ]
      : [
          const Shadow(blurRadius: 2, color: Colors.black38, offset: Offset(0, 1)),
        ];
}

/// Helper to build icon shadows for use in SliverAppBar actions.
/// Subtle drop shadow for icon readability over images.
List<Shadow> buildIconShadows(bool isDark) {
  return isDark 
      ? [
          const Shadow(blurRadius: 6, color: Colors.black54),
        ]
      : [
          const Shadow(blurRadius: 4, color: Colors.black38),
        ];
}
