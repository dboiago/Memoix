import 'package:flutter/material.dart';
import '../../features/recipes/models/category.dart';

/// Course card widget matching Figma design
/// Shows course icon, name, and recipe count in a card layout
class CourseCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      color: isDark ? const Color(0xFF1A1A1A) : theme.colorScheme.surfaceContainerHigh,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: theme.colorScheme.secondary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Icon circle (muted design)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconData(category.iconName),
                    color: theme.colorScheme.secondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$recipeCount recipes',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
