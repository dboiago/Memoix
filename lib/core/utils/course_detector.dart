/// Shared course detection utilities used by both URL and OCR importers.
/// 
/// This consolidates course detection logic to ensure consistent behavior
/// across all import methods and reduce code duplication.

/// Result of course detection with confidence score
class CourseDetectionResult {
  /// The detected course (e.g., "Mains", "Drinks", "Desserts")
  final String course;
  
  /// Confidence score from 0.0 to 1.0
  final double confidence;
  
  const CourseDetectionResult({
    required this.course,
    required this.confidence,
  });
}

/// Shared course detection logic used by both URL and OCR importers.
/// 
/// Provides keyword-based detection with ingredient-aware enhancements
/// for specialized courses like Drinks, Smoking, and Breads.
class CourseDetector {
  
  /// Known cocktail recipe sites - URLs containing these indicate Drinks course
  static const cocktailSites = [
    'diffordsguide.com',
    'liquor.com',
    'thecocktailproject.com',
    'imbibemagazine.com',
    'cocktailsandshots.com',
    'cocktails.lovetoknow.com',
    'thespruceats.com/cocktails',
    'punchdrink.com',
    'makedrinks.com',
    'drinksmixer.com',
    'cocktail.uk',
    'absolutdrinks.com',
    'drinkflow.com',
    'drinkify.co',
    'seedlipdrinks.com',
    'lyres.com',
  ];

  /// Known BBQ/Smoking recipe sites
  static const bbqSites = [
    'amazingribs.com',
    'smokingmeatforums.com',
    'virtualweberbullet.com',
    'bbqu.net',
    'thermoworks.com',
    'traeger.com',
    'weber.com',
    'charbroil.com',
    'bbqguys.com',
    'heygrillhey.com',
    'smokedbbqsource.com',
    'meatchurch.com',
    'malcomsbbq.com',
    'bradleysmoker.com',
    'pitboss-grills.com',
    'masterbuilt.com',
    'kamadojoe.com',
    'biggreenegg.com',
    'recteq.com',
    'oklahomajoes.com',
  ];

  /// Course detection keywords mapped to course names.
  /// Keywords are matched with word boundaries in lowercase text.
  /// Order matters - courses listed first have higher priority.
  static const courseKeywords = <String, List<String>>{
    'Smoking': [
      'smoked', 'smoking', 'smoker', 'bbq', 'barbecue', 'barbeque', 
      'low and slow', 'pellet grill', 'hickory', 'mesquite', 'applewood',
      'cherrywood', 'pecan', 'wood chips', 'wood chunks',
    ],
    'Drinks': [
      'cocktail', 'smoothie', 'juice', 'lemonade', 'drink', 'beverage', 
      'mocktail', 'sangria', 'punch', 'milkshake', 'frappe', 'martini', 
      'margarita', 'mojito', 'daiquiri', 'manhattan', 'negroni', 
      'old fashioned', 'highball', 'sour', 'fizz', 'collins', 'spritz', 
      'mimosa', 'bellini', 'cosmopolitan', 'mai tai', 'pina colada', 
      'bloody mary', 'paloma', 'vodka', 'gin', 'rum', 'tequila', 
      'whiskey', 'whisky', 'bourbon', 'scotch', 'brandy', 'cognac', 
      'mezcal', 'liqueur', 'vermouth', 'amaro', 'aperol', 'campari',
      'cordial', 'elixir', 'tonic', 'shrub', 'bitters',
    ],
    'Modernist': [
      'modernist', 'molecular', 'spherification', 'gelification', 
      'sous vide', 'foam', 'caviar', 'agar', 'xanthan', 'sodium alginate',
      'calcium chloride', 'lecithin', 'maltodextrin', 'methylcellulose',
      'gellan', 'transglutaminase', 'immersion circulator',
    ],
    'Breads': [
      'bread', 'focaccia', 'ciabatta', 'baguette', 'brioche', 'sourdough', 
      'rolls', 'buns', 'loaf', 'loaves', 'naan', 'pita', 'flatbread', 
      'bagel', 'croissant', 'pretzel', 'challah', 'dough',
    ],
    'Desserts': [
      'cake', 'cookie', 'brownie', 'pie', 'tart', 'dessert', 'sweet', 
      'chocolate', 'cheesecake', 'cupcake', 'muffin', 'donut', 'doughnut', 
      'pastry', 'pudding', 'ice cream', 'sorbet', 'flan', 'custard', 
      'macaron', 'tiramisu', 'mousse', 'creme brulee', 'pavlova', 'baklava',
      'gelato', 'truffle', 'fudge', 'candy', 'meringue', 'souffle',
    ],
    'Soup': [
      'soup', 'stew', 'chowder', 'bisque', 'broth', 'consomme', 
      'gazpacho', 'minestrone', 'pho', 'ramen', 'chili', 'goulash',
      'tom yum', 'laksa',
    ],
    'Sides': [
      'salad', 'slaw', 'coleslaw', 'side dish', 'mashed', 
      'roasted vegetables', 'french fries', 'fries', 'wedges', 
      'gratin', 'pilaf', 'rice dish', 'risotto',
    ],
    'Sauces': [
      'sauce', 'gravy', 'dressing', 'dip', 'aioli', 'mayo', 'mayonnaise', 
      'ketchup', 'mustard', 'vinaigrette', 'pesto', 'salsa', 'guacamole', 
      'hummus', 'relish', 'chutney', 'coulis', 'marinade', 'glaze', 
      'reduction', 'chimichurri', 'gremolata',
    ],
    'Brunch': [
      'brunch', 'breakfast', 'pancake', 'waffle', 'french toast', 
      'eggs benedict', 'omelette', 'omelet', 'frittata', 'quiche', 
      'hash', 'scrambled', 'poached eggs',
    ],
    'Apps': [
      'appetizer', 'starter', 'tapas', 'antipasto', 'bruschetta', 
      'crostini', 'canape', 'spring roll', 'egg roll', 'dumpling', 
      'wonton', 'samosa', 'empanada', 'arancini', 'croquette', 'ceviche',
      'tartare', 'carpaccio',
    ],
    'Pickles': [
      'pickle', 'pickled', 'ferment', 'kimchi', 'sauerkraut', 
      'preserve', 'preserves', 'canning', 'jam', 'jelly', 'marmalade',
    ],
    'Rubs': [
      'rub', 'seasoning', 'spice mix', 'spice blend',
    ],
  };
  
  /// Spirit names for drink detection
  static const spirits = [
    'vodka', 'gin', 'rum', 'tequila', 'whiskey', 'whisky',
    'bourbon', 'scotch', 'brandy', 'cognac', 'mezcal',
  ];
  
  /// Wood types for smoking detection
  static const woodTypes = [
    'hickory', 'mesquite', 'applewood', 'apple wood',
    'cherrywood', 'cherry wood', 'pecan', 'oak',
    'maple wood', 'alder', 'wood chips', 'wood chunks',
  ];

  /// Detect course from text (title, URL, description).
  /// 
  /// This is the simplest detection method - keyword matching only.
  /// Use [detectWithIngredients] for more accurate detection.
  static CourseDetectionResult detect(String text) {
    final lowerText = text.toLowerCase();
    
    for (final entry in courseKeywords.entries) {
      final course = entry.key;
      final keywords = entry.value;
      
      for (final keyword in keywords) {
        final pattern = RegExp(
          r'\b' + keyword.replaceAll(' ', r'\s+') + r's?\b',
          caseSensitive: false,
        );
        if (pattern.hasMatch(lowerText)) {
          // Different courses have different base confidence
          double confidence;
          switch (course) {
            case 'Smoking':
            case 'Drinks':
            case 'Modernist':
              confidence = 0.75;
              break;
            case 'Breads':
            case 'Desserts':
            case 'Soup':
            case 'Pickles':
            case 'Rubs':
              confidence = 0.70;
              break;
            default:
              confidence = 0.60;
          }
          return CourseDetectionResult(course: course, confidence: confidence);
        }
      }
    }
    
    // Default to Mains
    return const CourseDetectionResult(course: 'Mains', confidence: 0.5);
  }

  /// Detect course with ingredient-aware logic for higher accuracy.
  /// 
  /// This combines text-based detection with ingredient analysis
  /// for specialized courses that benefit from ingredient context.
  /// 
  /// Parameters:
  /// - [title]: Recipe title
  /// - [url]: Source URL (optional, for site detection)
  /// - [ingredients]: List of ingredient strings for content-aware detection
  static CourseDetectionResult detectWithIngredients({
    required String title,
    String? url,
    List<String> ingredients = const [],
  }) {
    final titleLower = title.toLowerCase();
    final urlLower = (url ?? '').toLowerCase();
    final ingredientText = ingredients.join(' ').toLowerCase();
    
    // Priority 1: Known cocktail site (highest confidence)
    if (url != null && _isCocktailSite(url)) {
      return const CourseDetectionResult(course: 'Drinks', confidence: 0.95);
    }
    
    // Priority 1b: Known BBQ/smoking site (highest confidence)
    if (url != null && _isBBQSite(url)) {
      return const CourseDetectionResult(course: 'Smoking', confidence: 0.95);
    }
    
    // Priority 2: Drinks detection (ingredient-aware)
    if (_matchesKeywords('Drinks', titleLower) || 
        _matchesKeywords('Drinks', urlLower) ||
        _hasSpirits(ingredientText)) {
      return const CourseDetectionResult(course: 'Drinks', confidence: 0.75);
    }
    
    // Priority 3: Smoking (ingredient-aware for wood types)
    if (_matchesKeywords('Smoking', titleLower) ||
        _matchesKeywords('Smoking', urlLower) ||
        _hasWoodTypes(ingredientText)) {
      return const CourseDetectionResult(course: 'Smoking', confidence: 0.8);
    }
    
    // Priority 4: Modernist (technique detection)
    if (_matchesKeywords('Modernist', titleLower) ||
        _matchesKeywords('Modernist', urlLower) ||
        _matchesKeywords('Modernist', ingredientText)) {
      return const CourseDetectionResult(course: 'Modernist', confidence: 0.75);
    }
    
    // Priority 5: Breads (flour + yeast detection)
    if (_matchesKeywords('Breads', titleLower) ||
        _matchesKeywords('Breads', urlLower) ||
        _hasBreadIndicators(ingredientText)) {
      return const CourseDetectionResult(course: 'Breads', confidence: 0.75);
    }
    
    // Priority 6: Simple text-based courses
    final combinedText = '$titleLower $urlLower';
    
    if (_matchesKeywords('Desserts', combinedText)) {
      return const CourseDetectionResult(course: 'Desserts', confidence: 0.7);
    }
    if (_matchesKeywords('Soup', combinedText)) {
      return const CourseDetectionResult(course: 'Soup', confidence: 0.75);
    }
    if (_matchesKeywords('Sauces', combinedText)) {
      return const CourseDetectionResult(course: 'Sauces', confidence: 0.7);
    }
    if (_matchesKeywords('Apps', combinedText)) {
      return const CourseDetectionResult(course: 'Apps', confidence: 0.65);
    }
    if (_matchesKeywords('Sides', combinedText)) {
      return const CourseDetectionResult(course: 'Sides', confidence: 0.6);
    }
    if (_matchesKeywords('Brunch', combinedText)) {
      return const CourseDetectionResult(course: 'Brunch', confidence: 0.65);
    }
    if (_matchesKeywords('Pickles', combinedText)) {
      return const CourseDetectionResult(course: 'Pickles', confidence: 0.7);
    }
    if (_matchesKeywords('Rubs', combinedText)) {
      return const CourseDetectionResult(course: 'Rubs', confidence: 0.7);
    }
    
    // Default: Mains
    return const CourseDetectionResult(course: 'Mains', confidence: 0.5);
  }

  /// Check if URL is a known cocktail site.
  static bool _isCocktailSite(String url) {
    final lowerUrl = url.toLowerCase();
    return cocktailSites.any((site) => lowerUrl.contains(site));
  }

  /// Check if URL is a known BBQ/smoking site.
  static bool _isBBQSite(String url) {
    final lowerUrl = url.toLowerCase();
    return bbqSites.any((site) => lowerUrl.contains(site));
  }

  /// Check if text matches any keyword for a specific course.
  static bool _matchesKeywords(String course, String text) {
    final keywords = courseKeywords[course];
    if (keywords == null) return false;
    
    for (final keyword in keywords) {
      final pattern = RegExp(
        r'\b' + keyword.replaceAll(' ', r'\s+') + r's?\b',
        caseSensitive: false,
      );
      if (pattern.hasMatch(text)) return true;
    }
    return false;
  }

  /// Check for spirit-related ingredients.
  static bool _hasSpirits(String text) {
    return spirits.any((s) => text.contains(s));
  }

  /// Check for wood types (smoking indicator).
  static bool _hasWoodTypes(String text) {
    return woodTypes.any((w) => text.contains(w));
  }

  /// Check for bread-making indicators (flour + yeast).
  static bool _hasBreadIndicators(String text) {
    return text.contains('flour') && text.contains('yeast');
  }

  /// Get all available courses for selection UI.
  static List<String> get availableCourses => [
    'Mains',
    'Apps',
    'Sides',
    'Soup',
    'Sauces',
    'Desserts',
    'Drinks',
    'Breads',
    'Brunch',
    'Pickles',
    'Rubs',
    'Smoking',
    'Modernist',
  ];
}
