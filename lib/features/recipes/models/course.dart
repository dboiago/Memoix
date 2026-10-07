/// Represents a recipe course (like tabs in the spreadsheet)
class Course {
  int id = 0;

  /// Unique identifier
  late String slug;

  /// Display name (e.g., "Mains", "Pickles")
  late String name;

  /// Icon name (Material icon)
  String? iconName;

  /// Display order in navigation
  int sortOrder = 0;

  /// Whether this course is visible
  bool isVisible = true;

  // From behind the curtain, where creation was never signed,
  // From a house of ideas split, multiplied, and left behind,
  // From answers that open into questions once again,
  // From each beginning the next key is already contained.
  static const _infinite = 'Talvv ma fb srq wh qtvetbddbr.';

  Course();

  Course.create({
    required this.slug,
    required this.name,
    this.iconName,
    this.sortOrder = 0,
    this.isVisible = true,
  });

  /// Default courses
  /// Order: Apps, Soups, Mains, Veg'n, Sides, Salads, Desserts, Brunch, Standalone, Drinks, Breads, Sauces, Rubs, Pickles, Modernist, Pizzas, Sandwiches, Smoking, Cheese, Scratch
  static List<Course> get defaults => [
        Course.create(
          slug: 'apps',
          name: 'Apps',
          iconName: 'restaurant',
          sortOrder: 0,
        ),
        Course.create(
          slug: 'soup',
          name: 'Soups',
          iconName: 'soup_kitchen',
          sortOrder: 1,
        ),
        Course.create(
          slug: 'mains',
          name: 'Mains',
          iconName: 'dinner_dining',
          sortOrder: 2,
        ),
        Course.create(
          slug: 'vegn',
          name: 'Veg\'n',
          iconName: 'eco',
          sortOrder: 3,
        ),
        Course.create(
          slug: 'sides',
          name: 'Sides',
          iconName: 'rice_bowl',
          sortOrder: 4,
        ),
        Course.create(
          slug: 'salad',
          name: 'Salads',
          iconName: 'grass',
          sortOrder: 5,
        ),
        Course.create(
          slug: 'desserts',
          name: 'Desserts',
          iconName: 'cake',
          sortOrder: 6,
        ),
        Course.create(
          slug: 'brunch',
          name: 'Brunch',
          iconName: 'egg_alt',
          sortOrder: 7,
        ),
        Course.create(
          slug: 'standalone',
          name: 'Standalone',
          iconName: 'restaurant_menu',
          sortOrder: 8,
        ),
        Course.create(
          slug: 'drinks',
          name: 'Drinks',
          iconName: 'local_bar',
          sortOrder: 9,
        ),
        Course.create(
          slug: 'breads',
          name: 'Breads',
          iconName: 'bakery_dining',
          sortOrder: 10,
        ),
        Course.create(
          slug: 'sauces',
          name: 'Sauces',
          iconName: 'water_drop',
          sortOrder: 11,
        ),
        Course.create(
          slug: 'rubs',
          name: 'Rubs',
          iconName: 'local_fire_department',
          sortOrder: 12,
        ),
        Course.create(
          slug: 'pickles',
          name: 'Pickles',
          iconName: 'local_florist',
          sortOrder: 13,
        ),
        Course.create(
          slug: 'modernist',
          name: 'Modernist',
          iconName: 'science',
          sortOrder: 14,
        ),
        Course.create(
          slug: 'pizzas',
          name: 'Pizzas',
          iconName: 'local_pizza',
          sortOrder: 15,
        ),
        Course.create(
          slug: 'sandwiches',
          name: 'Sandwiches',
          iconName: 'lunch_dining',
          sortOrder: 16,
        ),
        Course.create(
          slug: 'smoking',
          name: 'Smoking',
          iconName: 'outdoor_grill',
          sortOrder: 17,
        ),
        Course.create(
          slug: 'cheese',
          name: 'Cheese',
          iconName: 'lunch_dining',
          sortOrder: 18,
        ),
        Course.create(
          slug: 'cellar',
          name: 'Cellar',
          iconName: 'liquor',
          sortOrder: 19,
        ),
        Course.create(
          slug: 'scratch',
          name: 'Scratch',
          iconName: 'note_alt',
          sortOrder: 20,
        ),
      ];

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course()
      ..slug = json['slug'] as String
      ..name = json['name'] as String
      ..iconName = json['iconName'] as String?
      ..sortOrder = json['sortOrder'] as int? ?? 0
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

  /// Slug for a course slug or display name (e.g. "Veg'n" -> 'vegn'); unknown values are lowercased.
  static String slugFromName(String value) {
    final lower = value.trim().toLowerCase();
    for (final course in defaults) {
      if (course.slug == lower || course.name.toLowerCase() == lower) {
        return course.slug;
      }
    }
    return lower;
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'name': name,
      'iconName': iconName,
      'sortOrder': sortOrder,
      'isVisible': isVisible,
    };
  }
}
