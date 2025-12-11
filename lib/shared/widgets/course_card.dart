import 'package:flutter/material.dart';
import '../../features/recipes/models/category.dart';

/// Course card widget matching Figma design
/// Shows course icon, name, and recipe count in a card layout
class CourseCard extends StatefulWidget {
  final Category category;
  final int recipeCount;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.category,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // compact
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon container: compact size with rounded corners
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (_hovered || _pressed)
                        ? theme.colorScheme.secondary // group-hover:bg-secondary
                        : theme.colorScheme.surfaceContainerHighest, // bg-accent
                    borderRadius: BorderRadius.circular(8), // rounded-lg
                  ),
                  child: Icon(
                    _getIconData(widget.category.iconName),
                    color: (_hovered || _pressed)
                        ? (isDark ? Colors.black87 : Colors.white) // dark icon on purple bg
                        : theme.colorScheme.onSurfaceVariant,
                    size: 20, // smaller icon
                  ),
                ),
                const SizedBox(height: 8), // tighter spacing
                // Texts
                Text(
                  widget.category.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.recipeCount} recipes',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Get Material IconData from icon name string
  IconData _getIconData(String? iconName) {
    if (iconName == null) return Icons.restaurant_menu;
    
    // Map of icon names to Material Icons
    final iconMap = {
      'restaurant': Icons.restaurant_menu,
      'soup_kitchen': Icons.soup_kitchen,
      'grass': Icons.grass,
      'dinner_dining': Icons.dinner_dining,
      'eco': Icons.eco,
      'rice_bowl': Icons.rice_bowl,
      'bakery_dining': Icons.bakery_dining,
      'cake': Icons.cake,
      'water_drop': Icons.water_drop,
      'local_fire_department': Icons.local_fire_department,
      'local_pizza': Icons.local_pizza,
      'lunch_dining': Icons.lunch_dining,
      'local_florist': Icons.local_florist,
      'outdoor_grill': Icons.outdoor_grill,
      'science': Icons.science,
      'note_alt': Icons.note_alt,
      'local_bar': Icons.local_bar,
    };
    
    return iconMap[iconName] ?? Icons.restaurant_menu;
  }
}
