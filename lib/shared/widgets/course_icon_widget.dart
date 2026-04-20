import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Central course icon widget.
///
/// Accepts a course slug string (e.g. 'mains', 'apps', 'soup') and renders
/// a custom SVG asset when one exists, falling back to a Material icon otherwise.
///
/// [slug]  — canonical course slug from Course.defaults (case-insensitive)
/// [size]  — width/height in logical pixels (default 24.0)
/// [color] — optional tint applied via colorFilter (SVG) or iconTheme (Material)
class CourseIconWidget extends StatelessWidget {
  final String slug;
  final double size;
  final Color? color;

  const CourseIconWidget({
    super.key,
    required this.slug,
    this.size = 24.0,
    this.color,
  });

  /// Maps every canonical course slug to its SVG asset path.
  /// Slugs that have no entry fall through to [_fallbackIcon].
  static const Map<String, String> svgAssets = {
    'apps':       'assets/icons/apps-icon-512.svg',
    'breads':     'assets/icons/bread-icon-512.svg',
    'brunch':     'assets/icons/brunch-icon-512.svg',
    'cellar':     'assets/icons/cellar-icon-512.svg',
    'cheese':     'assets/icons/cheese-icon-512.svg',
    'desserts':   'assets/icons/dessert-icon-512.svg',
    'drinks':     'assets/icons/drink-icon-512.svg',
    'mains':      'assets/icons/main-icon-512.svg',
    'modernist':  'assets/icons/modernist-icon-512.svg',
    'pickles':    'assets/icons/pickle-icon-512.svg',
    'pizzas':     'assets/icons/pizza-icon-512.svg',
    'rubs':       'assets/icons/rubs-icon-512.svg',
    'salad':      'assets/icons/salad-icon-512.svg',
    'sandwiches': 'assets/icons/sandwich-icon-512.svg',
    'sauces':     'assets/icons/sauce-icon-512.svg',
    'scratch':    'assets/icons/scratch-icon-512.svg',
    'sides':      'assets/icons/side-icon-512.svg',
    'smoking':    'assets/icons/smoking-icon-512.svg',
    'soup':       'assets/icons/soup-icon-512.svg',
    'vegn':       'assets/icons/vegn-icon-512.svg',
    'classics':   'assets/icons/classics-icon-512.svg',
  };

  /// Material icon fallback for slugs without a custom SVG.
  static IconData fallbackIcon(String slug) {
    switch (slug.toLowerCase()) {
      case 'apps':
        return Icons.restaurant;
      case 'soup':
      case 'soups':
        return Icons.soup_kitchen;
      case 'mains':
        return Icons.dinner_dining;
      case 'vegn':
        return Icons.eco;
      case 'sides':
        return Icons.rice_bowl;
      case 'salad':
      case 'salads':
        return Icons.grass;
      case 'desserts':
        return Icons.cake;
      case 'brunch':
        return Icons.egg_alt;
      case 'drinks':
        return Icons.local_bar;
      case 'breads':
        return Icons.bakery_dining;
      case 'sauces':
        return Icons.water_drop;
      case 'rubs':
        return Icons.local_fire_department;
      case 'pickles':
        return Icons.local_florist;
      case 'modernist':
        return Icons.science;
      case 'pizzas':
        return Icons.local_pizza;
      case 'sandwiches':
        return Icons.lunch_dining;
      case 'smoking':
        return Icons.outdoor_grill;
      case 'cheese':
        return Icons.lunch_dining;
      case 'cellar':
        return Icons.liquor;
      case 'scratch':
        return Icons.note_alt;
      default:
        return Icons.restaurant_menu;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedSlug = slug.toLowerCase();
    final assetPath = svgAssets[normalizedSlug];

    if (assetPath != null) {
      return SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        colorFilter: color != null
            ? ColorFilter.mode(color!, BlendMode.srcIn)
            : null,
      );
    }

    return Icon(
      fallbackIcon(normalizedSlug),
      size: size,
      color: color,
    );
  }
}
