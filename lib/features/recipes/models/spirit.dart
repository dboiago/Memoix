/// Spirit/base category for drinks and cocktails
/// Similar to how Cuisine works for food, Spirit categorizes drinks by their base
class Spirit {
  final String code;       // Short code (e.g., 'GIN', 'VODKA')
  final String name;       // Display name (e.g., 'Gin', 'Vodka')
  final String category;   // Grouping (e.g., 'Spirits', 'Wine', 'Non-Alcoholic')

  const Spirit({
    required this.code,
    required this.name,
    required this.category,
  });

  /// Check if this spirit is alcoholic
  bool get isAlcoholic => category != 'Non-Alcoholic';

  /// All spirits organized by category
  /// Categories: Spirits (base liquors), Wine/Fortified, Beer, Non-Alcoholic
  static const List<Spirit> all = [
    // === SPIRITS (Base Liquors) ===
    const Spirit(code: 'GIN', name: 'Gin', category: 'Spirits'),
    const Spirit(code: 'VODKA', name: 'Vodka', category: 'Spirits'),
    const Spirit(code: 'WHISKEY', name: 'Whiskey', category: 'Spirits'),
    const Spirit(code: 'BOURBON', name: 'Bourbon', category: 'Spirits'),
    const Spirit(code: 'RYE', name: 'Rye', category: 'Spirits'),
    const Spirit(code: 'SCOTCH', name: 'Scotch', category: 'Spirits'),
    const Spirit(code: 'RUM', name: 'Rum', category: 'Spirits'),
    const Spirit(code: 'TEQUILA', name: 'Tequila', category: 'Spirits'),
    const Spirit(code: 'MEZCAL', name: 'Mezcal', category: 'Spirits'),
    const Spirit(code: 'BRANDY', name: 'Brandy', category: 'Spirits'),
    const Spirit(code: 'COGNAC', name: 'Cognac', category: 'Spirits'),
    const Spirit(code: 'PISCO', name: 'Pisco', category: 'Spirits'),
    const Spirit(code: 'CACHACA', name: 'Cachaça', category: 'Spirits'),
    const Spirit(code: 'ABSINTHE', name: 'Absinthe', category: 'Spirits'),
    const Spirit(code: 'AQUAVIT', name: 'Aquavit', category: 'Spirits'),
    const Spirit(code: 'SAKE', name: 'Sake', category: 'Spirits'),
    const Spirit(code: 'SOJU', name: 'Soju', category: 'Spirits'),
    
    // === LIQUEURS & AMARI ===
    const Spirit(code: 'LIQUEUR', name: 'Liqueur', category: 'Liqueurs'),
    const Spirit(code: 'AMARO', name: 'Amaro', category: 'Liqueurs'),
    const Spirit(code: 'APERITIF', name: 'Aperitif', category: 'Liqueurs'),
    const Spirit(code: 'DIGESTIF', name: 'Digestif', category: 'Liqueurs'),
    const Spirit(code: 'CHARTREUSE', name: 'Chartreuse', category: 'Liqueurs'),
    const Spirit(code: 'BENEDICTINE', name: 'Bénédictine', category: 'Liqueurs'),
    const Spirit(code: 'MARASCHINO', name: 'Maraschino', category: 'Liqueurs'),
    const Spirit(code: 'TRIPLE_SEC', name: 'Triple Sec/Curaçao', category: 'Liqueurs'),
    const Spirit(code: 'AMARETTO', name: 'Amaretto', category: 'Liqueurs'),
    const Spirit(code: 'FERNET', name: 'Fernet', category: 'Liqueurs'),
    const Spirit(code: 'SAMBUCA', name: 'Sambuca', category: 'Liqueurs'),
    const Spirit(code: 'GRAPPA', name: 'Grappa', category: 'Liqueurs'),
    const Spirit(code: 'LIMONCELLO', name: 'Limoncello', category: 'Liqueurs'),
    const Spirit(code: 'ST_GERMAIN', name: 'St-Germain', category: 'Liqueurs'),
    const Spirit(code: 'KAHLUA', name: 'Coffee Liqueur', category: 'Liqueurs'),
    const Spirit(code: 'BAILEYS', name: 'Cream Liqueur', category: 'Liqueurs'),
    
    // === WINE & FORTIFIED ===
    const Spirit(code: 'PROSECCO', name: 'Prosecco', category: 'Wine'),
    const Spirit(code: 'CHAMPAGNE', name: 'Champagne', category: 'Wine'),
    const Spirit(code: 'SPARKLING', name: 'Sparkling Wine', category: 'Wine'),
    const Spirit(code: 'RED_WINE', name: 'Red Wine', category: 'Wine'),
    const Spirit(code: 'WHITE_WINE', name: 'White Wine', category: 'Wine'),
    const Spirit(code: 'ROSE_WINE', name: 'Rosé Wine', category: 'Wine'),
    const Spirit(code: 'VERMOUTH', name: 'Vermouth', category: 'Wine'),
    const Spirit(code: 'SHERRY', name: 'Sherry', category: 'Wine'),
    const Spirit(code: 'PORT', name: 'Port', category: 'Wine'),
    
    // === BEER ===
    const Spirit(code: 'BEER', name: 'Beer', category: 'Beer'),
    const Spirit(code: 'CIDER', name: 'Cider', category: 'Beer'),
    
    // === NON-ALCOHOLIC ===
    const Spirit(code: 'TEA', name: 'Tea', category: 'Non-Alcoholic'),
    const Spirit(code: 'COFFEE', name: 'Coffee', category: 'Non-Alcoholic'),
    const Spirit(code: 'MOCKTAIL', name: 'Mocktail', category: 'Non-Alcoholic'),
    const Spirit(code: 'SMOOTHIE', name: 'Smoothie', category: 'Non-Alcoholic'),
    const Spirit(code: 'JUICE', name: 'Juice', category: 'Non-Alcoholic'),
    const Spirit(code: 'SODA', name: 'Soda/Tonic', category: 'Non-Alcoholic'),
    const Spirit(code: 'HOT_CHOC', name: 'Hot Chocolate', category: 'Non-Alcoholic'),
  ];

  /// First-wins index of [all] by exact code.
  static final Map<String, Spirit> _byCodeIndex = () {
    final index = <String, Spirit>{};
    for (final s in all) {
      index.putIfAbsent(s.code, () => s);
    }
    return index;
  }();

  /// First-wins index of [all] by lowercase name.
  static final Map<String, Spirit> _byLowerNameIndex = () {
    final index = <String, Spirit>{};
    for (final s in all) {
      index.putIfAbsent(s.name.toLowerCase(), () => s);
    }
    return index;
  }();

  /// Find spirit by code
  static Spirit? byCode(String code) =>
      _byCodeIndex[code.toUpperCase().trim()];

  /// Find spirit by name (case-insensitive)
  static Spirit? byName(String name) =>
      _byLowerNameIndex[name.toLowerCase().trim()];

  /// Get spirit from code or name
  static Spirit? lookup(String? value) {
    if (value == null || value.isEmpty) return null;
    return byCode(value) ?? byName(value);
  }

  /// Get display name for a spirit code/name
  static String toDisplayName(String? value) {
    if (value == null || value.isEmpty) return '';
    final spirit = lookup(value);
    return spirit?.name ?? value;
  }

  /// Matches any of [keywords] as a whole word. The boundary is letters,
  /// digits and underscore, so it works after accented letters (e.g. cachaça).
  static RegExp _wholeWord(List<String> keywords) {
    final alternatives = keywords.map(RegExp.escape).join('|');
    return RegExp(
      '(?<![\\p{L}\\p{N}_])(?:$alternatives)(?![\\p{L}\\p{N}_])',
      unicode: true,
      caseSensitive: false,
    );
  }

  /// Detection rules in priority order (most specific first).
  static final List<(String, RegExp)> _detectionRules = [
    ('BOURBON', _wholeWord(['bourbon'])),
    ('RYE', _wholeWord(['rye whiskey', 'rye whisky'])),
    ('SCOTCH', _wholeWord(['scotch'])),
    ('WHISKEY', _wholeWord(['whiskey', 'whisky'])),
    ('MEZCAL', _wholeWord(['mezcal'])),
    ('TEQUILA', _wholeWord(['tequila'])),
    ('CACHACA', _wholeWord(['cachaça', 'cachaca'])),
    ('PISCO', _wholeWord(['pisco'])),
    ('COGNAC', _wholeWord(['cognac'])),
    ('BRANDY', _wholeWord(['brandy'])),
    ('ABSINTHE', _wholeWord(['absinthe'])),
    ('AQUAVIT', _wholeWord(['aquavit'])),
    ('GIN', _wholeWord(['gin'])),
    ('VODKA', _wholeWord(['vodka'])),
    ('RUM', _wholeWord(['rum'])),
    ('SAKE', _wholeWord(['sake', 'saké'])),
    ('SOJU', _wholeWord(['soju'])),
    ('PROSECCO', _wholeWord(['prosecco'])),
    ('CHAMPAGNE', _wholeWord(['champagne'])),
    ('SPARKLING', _wholeWord(['sparkling wine'])),
    ('RED_WINE', _wholeWord(['red wine'])),
    ('WHITE_WINE', _wholeWord(['white wine'])),
    ('ROSE_WINE', _wholeWord(['rosé', 'rose wine'])),
    ('VERMOUTH', _wholeWord(['vermouth'])),
    ('SHERRY', _wholeWord(['sherry'])),
    ('PORT', _wholeWord(['port wine', 'porto'])),
    ('AMARO', _wholeWord(['amaro'])),
    ('APERITIF', _wholeWord(['aperol', 'campari'])),
    ('LIQUEUR', _wholeWord(['liqueur', 'creme de'])),
    ('BEER', _wholeWord(['beer', 'lager', 'ale'])),
    ('CIDER', _wholeWord(['cider'])),
    ('TEA', _wholeWord(['tea', 'barley tea'])),
    ('COFFEE', _wholeWord(['coffee', 'espresso'])),
  ];

  /// Detect spirit type from ingredient list
  /// Returns the most likely base spirit for a cocktail
  static String? detectFromIngredients(List<String> ingredients) {
    final text = ingredients.join(' ').toLowerCase();

    for (final (code, pattern) in _detectionRules) {
      if (pattern.hasMatch(text)) return code;
    }

    return null;
  }
}
