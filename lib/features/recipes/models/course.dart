import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../../../app/theme/colors.dart';

part 'course.g.dart';

/// Represents a recipe course (like tabs in the spreadsheet)
@collection
class Course {
  Id id = Isar.autoIncrement;

  /// Unique identifier
  @Index(unique: true, replace: true)
  late String slug;

  /// Display name (e.g., "Mains", "Pickles")
  late String name;

  /// Icon name (Material icon)
  String? iconName;

  /// Display order in navigation
  int sortOrder = 0;

  /// Color as hex int
  int colorValue = 0xFFFFB74D;

  /// Whether this course is visible
  bool isVisible = true;

  Course();

  Course.create({
    required this.slug,
    required this.name,
    this.iconName,
    this.sortOrder = 0,
    required this.colorValue,
    this.isVisible = true,
  });

  /// Get Color object from stored value
  @ignore
  Color get color => Color(colorValue);

  /// Default courses matching your spreadsheet
  /// Order: Apps, Soups, Mains, Veg'n, Sides, Salads, Desserts, Brunch, Drinks, Breads, Sauces, Rubs, Pickles, Modernist, Pizzas, Sandwiches, Smoking, Cheese, Scratch
  static List<Course> get defaults => [
        Course.create(
          slug: 'apps',
          name: 'Apps',
          iconName: 'restaurant',
          sortOrder: 0,
          colorValue: MemoixColors.apps.value,
        ),
        Course.create(
          slug: 'soup',
          name: 'Soups',
          iconName: 'soup_kitchen',
          sortOrder: 1,
          colorValue: MemoixColors.soups.value,
        ),
        Course.create(
          slug: 'mains',
          name: 'Mains',
          iconName: 'dinner_dining',
          sortOrder: 2,
          colorValue: MemoixColors.mains.value,
        ),
        Course.create(
          slug: 'vegn',
          name: 'Veg\'n',
          iconName: 'eco',
          sortOrder: 3,
          colorValue: MemoixColors.vegn.value,
        ),
        Course.create(
          slug: 'sides',
          name: 'Sides',
          iconName: 'rice_bowl',
          sortOrder: 4,
          colorValue: MemoixColors.sides.value,
        ),
        Course.create(
          slug: 'salad',
          name: 'Salads',
          iconName: 'grass',
          sortOrder: 5,
          colorValue: MemoixColors.salads.value,
        ),
        Course.create(
          slug: 'desserts',
          name: 'Desserts',
          iconName: 'cake',
          sortOrder: 6,
          colorValue: MemoixColors.desserts.value,
        ),
        Course.create(
          slug: 'brunch',
          name: 'Brunch',
          iconName: 'egg_alt',
          sortOrder: 7,
          colorValue: MemoixColors.brunch.value,
        ),
        Course.create(
          slug: 'drinks',
          name: 'Drinks',
          iconName: 'local_bar',
          sortOrder: 8,
          colorValue: MemoixColors.drinks.value,
        ),
        Course.create(
          slug: 'breads',
          name: 'Breads',
          iconName: 'bakery_dining',
          sortOrder: 9,
          colorValue: MemoixColors.breads.value,
        ),
        Course.create(
          slug: 'sauces',
          name: 'Sauces',
          iconName: 'water_drop',
          sortOrder: 10,
          colorValue: MemoixColors.sauces.value,
        ),
        Course.create(
          slug: 'rubs',
          name: 'Rubs',
          iconName: 'local_fire_department',
          sortOrder: 11,
          colorValue: MemoixColors.rubs.value,
        ),
        Course.create(
          slug: 'pickles',
          name: 'Pickles',
          iconName: 'local_florist',
          sortOrder: 12,
          colorValue: MemoixColors.pickles.value,
        ),
        Course.create(
          slug: 'modernist',
          name: 'Modernist',
          iconName: 'science',
          sortOrder: 13,
          colorValue: MemoixColors.modernist.value,
        ),
        Course.create(
          slug: 'pizzas',
          name: 'Pizzas',
          iconName: 'local_pizza',
          sortOrder: 14,
          colorValue: MemoixColors.pizzas.value,
        ),
        Course.create(
          slug: 'sandwiches',
          name: 'Sandwiches',
          iconName: 'lunch_dining',
          sortOrder: 15,
          colorValue: MemoixColors.sandwiches.value,
        ),
        Course.create(
          slug: 'smoking',
          name: 'Smoking',
          iconName: 'outdoor_grill',
          sortOrder: 16,
          colorValue: MemoixColors.smoking.value,
        ),
        Course.create(
          slug: 'cheese',
          name: 'Cheese',
          iconName: 'lunch_dining',
          sortOrder: 17,
          colorValue: MemoixColors.cheese.value,
        ),
        Course.create(
          slug: 'cellar',
          name: 'Cellar',
          iconName: 'liquor',
          sortOrder: 18,
          colorValue: MemoixColors.cellar.value,
        ),
        Course.create(
          slug: 'scratch',
          name: 'Scratch',
          iconName: 'note_alt',
          sortOrder: 19,
          colorValue: MemoixColors.scratch.value,
        ),
      ];

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course()
      ..slug = json['slug'] as String
      ..name = json['name'] as String
      ..iconName = json['iconName'] as String?
      ..sortOrder = json['sortOrder'] as int? ?? 0
      ..colorValue = json['colorValue'] as int? ?? MemoixColors.primary.value
      ..isVisible = json['isVisible'] as bool? ?? true;
  }

  /// Get display name from slug (e.g., 'vegn' -> "Veg'n")
  static String displayNameFromSlug(String slug) {
    final lower = slug.toLowerCase();
    
    // Handle vegan/vegetarian variations -> Veg'n
    if (lower == 'vegan' || lower == 'vegetarian' || lower == "veg'n") {
      return "Veg'n";
    }
    
    for (final course in defaults) {
      if (course.slug == lower) {
        return course.name;
      }
    }
    // Fallback: capitalize first letter
    if (slug.isEmpty) return slug;
    return slug[0].toUpperCase() + slug.substring(1);
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'name': name,
      'iconName': iconName,
      'sortOrder': sortOrder,
      'colorValue': colorValue,
      'isVisible': isVisible,
    };
  }
}
