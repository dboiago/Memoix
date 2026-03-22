import 'package:flutter/material.dart';
import '../../features/recipes/models/course.dart';
import 'course_icon_widget.dart';

/// Course card widget
/// Shows course icon, name, and recipe count in a card layout
class CourseCard extends StatefulWidget {
  final Course course;
  final int recipeCount;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.recipeCount,
    required this.onTap,
  });

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void deactivate() {
    // Reset hover state when navigating away to prevent stale hover on return
    _hovered = false;
    _pressed = false;
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: (_hovered || _pressed)
              ? theme.colorScheme.secondary // hover:border-secondary
              : theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (h) => setState(() => _hovered = h),
          onHighlightChanged: (p) => setState(() => _pressed = p),
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon container
                Flexible(
                  flex: 3,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 36, maxHeight: 36),
                    decoration: BoxDecoration(
                      color: (_hovered || _pressed)
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: CourseIconWidget(
                        slug: widget.course.slug,
                        size: 18,
                        color: (_hovered || _pressed)
                            ? (isDark ? Colors.black87 : Colors.white)
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Course name
                Flexible(
                  flex: 2,
                  child: Text(
                    widget.course.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                // Recipe count
                Flexible(
                  flex: 1,
                  child: Text(
                    '${widget.recipeCount} recipes',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
