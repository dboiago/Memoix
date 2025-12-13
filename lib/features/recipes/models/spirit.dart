import 'package:flutter/material.dart';

/// Spirit/base category for drinks and cocktails
/// Similar to how Cuisine works for food, Spirit categorizes drinks by their base
class Spirit {
  final String code;       // Short code (e.g., 'GIN', 'VODKA')
  final String name;       // Display name (e.g., 'Gin', 'Vodka')
  final String category;   // Grouping (e.g., 'Spirits', 'Wine', 'Non-Alcoholic')
  final Color colour;      // Associated color for UI

  const Spirit({
    required this.code,
    required this.name,
    required this.category,
    required this.colour,
  });

  /// Check if this spirit is alcoholic
  bool get isAlcoholic => category != 'Non-Alcoholic';

  /// All spirits organized by category
  /// Categories: Spirits (base liquors), Wine/Fortified, Beer, Non-Alcoholic
  static List<Spirit> get all => [
    // === SPIRITS (Base Liquors) ===
    const Spirit(code: 'GIN', name: 'Gin', category: 'Spirits', colour: Color(0xFF7EB8C4)),
    const Spirit(code: 'VODKA', name: 'Vodka', category: 'Spirits', colour: Color(0xFFB8C4D4)),
    const Spirit(code: 'WHISKEY', name: 'Whiskey', category: 'Spirits', colour: Color(0xFFD4A574)),
    const Spirit(code: 'BOURBON', name: 'Bourbon', category: 'Spirits', colour: Color(0xFFBF8A54)),
    const Spirit(code: 'RYE', name: 'Rye', category: 'Spirits', colour: Color(0xFFC49A6C)),
    const Spirit(code: 'SCOTCH', name: 'Scotch', category: 'Spirits', colour: Color(0xFFB08050)),
    const Spirit(code: 'RUM', name: 'Rum', category: 'Spirits', colour: Color(0xFFD4956E)),
    const Spirit(code: 'TEQUILA', name: 'Tequila', category: 'Spirits', colour: Color(0xFFE8C878)),
    const Spirit(code: 'MEZCAL', name: 'Mezcal', category: 'Spirits', colour: Color(0xFFD4B878)),
    const Spirit(code: 'BRANDY', name: 'Brandy', category: 'Spirits', colour: Color(0xFFC4876E)),
    const Spirit(code: 'COGNAC', name: 'Cognac', category: 'Spirits', colour: Color(0xFFB47858)),
    const Spirit(code: 'PISCO', name: 'Pisco', category: 'Spirits', colour: Color(0xFFE8D8A8)),
    const Spirit(code: 'CACHACA', name: 'Cachaça', category: 'Spirits', colour: Color(0xFFD8C888)),
    const Spirit(code: 'ABSINTHE', name: 'Absinthe', category: 'Spirits', colour: Color(0xFF8EB878)),
    const Spirit(code: 'AQUAVIT', name: 'Aquavit', category: 'Spirits', colour: Color(0xFFA8C4B8)),
    const Spirit(code: 'SAKE', name: 'Sake', category: 'Spirits', colour: Color(0xFFF0E8D8)),
    const Spirit(code: 'SOJU', name: 'Soju', category: 'Spirits', colour: Color(0xFFE8F0E8)),
    
    // === LIQUEURS & AMARI ===
    const Spirit(code: 'LIQUEUR', name: 'Liqueur', category: 'Liqueurs', colour: Color(0xFFC898B8)),
    const Spirit(code: 'AMARO', name: 'Amaro', category: 'Liqueurs', colour: Color(0xFF987858)),
    const Spirit(code: 'APERITIF', name: 'Aperitif', category: 'Liqueurs', colour: Color(0xFFE87858)),
    
    // === WINE & FORTIFIED ===
    const Spirit(code: 'PROSECCO', name: 'Prosecco', category: 'Wine', colour: Color(0xFFF8E8A0)),
    const Spirit(code: 'CHAMPAGNE', name: 'Champagne', category: 'Wine', colour: Color(0xFFF0E090)),
    const Spirit(code: 'SPARKLING', name: 'Sparkling Wine', category: 'Wine', colour: Color(0xFFF0E8B0)),
    const Spirit(code: 'RED_WINE', name: 'Red Wine', category: 'Wine', colour: Color(0xFF983058)),
    const Spirit(code: 'WHITE_WINE', name: 'White Wine', category: 'Wine', colour: Color(0xFFF0E8C0)),
    const Spirit(code: 'ROSE_WINE', name: 'Rosé Wine', category: 'Wine', colour: Color(0xFFF0B8B0)),
    const Spirit(code: 'VERMOUTH', name: 'Vermouth', category: 'Wine', colour: Color(0xFFB89878)),
    const Spirit(code: 'SHERRY', name: 'Sherry', category: 'Wine', colour: Color(0xFFC8A068)),
    const Spirit(code: 'PORT', name: 'Port', category: 'Wine', colour: Color(0xFF882848)),
    
    // === BEER ===
    const Spirit(code: 'BEER', name: 'Beer', category: 'Beer', colour: Color(0xFFD8A850)),
    const Spirit(code: 'CIDER', name: 'Cider', category: 'Beer', colour: Color(0xFFD8C870)),
    
    // === NON-ALCOHOLIC ===
    const Spirit(code: 'TEA', name: 'Tea', category: 'Non-Alcoholic', colour: Color(0xFF8EB878)),
    const Spirit(code: 'COFFEE', name: 'Coffee', category: 'Non-Alcoholic', colour: Color(0xFF6F4E37)),
    const Spirit(code: 'MOCKTAIL', name: 'Mocktail', category: 'Non-Alcoholic', colour: Color(0xFF7EB8A8)),
    const Spirit(code: 'SMOOTHIE', name: 'Smoothie', category: 'Non-Alcoholic', colour: Color(0xFFF098A8)),
    const Spirit(code: 'JUICE', name: 'Juice', category: 'Non-Alcoholic', colour: Color(0xFFF8A858)),
    const Spirit(code: 'SODA', name: 'Soda/Tonic', category: 'Non-Alcoholic', colour: Color(0xFFA8D8E8)),
    const Spirit(code: 'HOT_CHOC', name: 'Hot Chocolate', category: 'Non-Alcoholic', colour: Color(0xFF8B5A2B)),
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
