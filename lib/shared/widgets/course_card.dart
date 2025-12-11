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
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon circle (matching Figma accent background)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconData(category.iconName),
                  color: category.color,
                  size: 24,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Course name
              Text(
                category.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 4),
              
              // Recipe count
              Text(
                '$recipeCount ${recipeCount == 1 ? 'recipe' : 'recipes'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
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
