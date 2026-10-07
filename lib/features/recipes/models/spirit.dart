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

  /// Get all unique categories
  static List<String> get categories => 
    all.map((s) => s.category).toSet().toList();

  /// Get spirits grouped by category
  static Map<String, List<Spirit>> get byCategory {
    final grouped = <String, List<Spirit>>{};
    for (final spirit in all) {
      grouped.putIfAbsent(spirit.category, () => []);
      grouped[spirit.category]!.add(spirit);
    }
    return grouped;
  }

  /// Find spirit by code
  static Spirit? byCode(String code) {
    final upper = code.toUpperCase().trim();
    try {
      return all.firstWhere((s) => s.code == upper);
    } catch (_) {
      return null;
    }
  }

  /// Find spirit by name (case-insensitive)
  static Spirit? byName(String name) {
    final lower = name.toLowerCase().trim();
    try {
      return all.firstWhere((s) => s.name.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

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

  /// Detect spirit type from ingredient list
  /// Returns the most likely base spirit for a cocktail
  static String? detectFromIngredients(List<String> ingredients) {
    final text = ingredients.join(' ').toLowerCase();
    
    // Check each spirit by priority (most specific first)
    if (text.contains('bourbon')) return 'BOURBON';
    if (text.contains('rye whiskey') || text.contains('rye whisky')) return 'RYE';
    if (text.contains('scotch')) return 'SCOTCH';
    if (text.contains('whiskey') || text.contains('whisky')) return 'WHISKEY';
    if (text.contains('mezcal')) return 'MEZCAL';
    if (text.contains('tequila')) return 'TEQUILA';
    if (text.contains('cachaça') || text.contains('cachaca')) return 'CACHACA';
    if (text.contains('pisco')) return 'PISCO';
    if (text.contains('cognac')) return 'COGNAC';
    if (text.contains('brandy')) return 'BRANDY';
    if (text.contains('absinthe')) return 'ABSINTHE';
    if (text.contains('aquavit')) return 'AQUAVIT';
    if (text.contains('gin')) return 'GIN';
    if (text.contains('vodka')) return 'VODKA';
    if (text.contains('rum')) return 'RUM';
    if (text.contains('sake') || text.contains('saké')) return 'SAKE';
    if (text.contains('soju')) return 'SOJU';
    if (text.contains('prosecco')) return 'PROSECCO';
    if (text.contains('champagne')) return 'CHAMPAGNE';
    if (text.contains('sparkling wine')) return 'SPARKLING';
    if (text.contains('red wine')) return 'RED_WINE';
    if (text.contains('white wine')) return 'WHITE_WINE';
    if (text.contains('rosé') || text.contains('rose wine')) return 'ROSE_WINE';
    if (text.contains('vermouth')) return 'VERMOUTH';
    if (text.contains('sherry')) return 'SHERRY';
    if (text.contains('port wine') || text.contains('porto')) return 'PORT';
    if (text.contains('amaro')) return 'AMARO';
    if (text.contains('aperol') || text.contains('campari')) return 'APERITIF';
    if (text.contains('liqueur') || text.contains('creme de')) return 'LIQUEUR';
    if (text.contains('beer') || text.contains('lager') || text.contains('ale')) return 'BEER';
    if (text.contains('cider')) return 'CIDER';
    if (text.contains('tea') || text.contains('barley tea')) return 'TEA';
    if (text.contains('coffee') || text.contains('espresso')) return 'COFFEE';
    
    return null;
  }
}
