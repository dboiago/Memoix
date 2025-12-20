/// Text normalization utilities for consistent data entry across the app.
/// 
/// These functions ensure the same normalization is applied whether data
/// comes from OCR, URL import, or manual entry.
/// 
/// This is the SINGLE SOURCE OF TRUTH for:
/// - Name/title cleaning (Title Case with lowercase connectors)
/// - Fraction normalization (text and decimal to unicode)
/// - Garnish normalization

/// Master text normalizer used across all importers and screens.
class TextNormalizer {
  
  /// Clean a name: collapse whitespace, remove trailing punctuation, apply Title Case.
  /// 
  /// Words like 'of', 'the', 'and', 'or' stay lowercase unless first word.
  /// 
  /// Examples:
  /// - "all-purpose FLOUR" → "All-Purpose Flour"
  /// - "olive oil, " → "Olive Oil"
  /// - "juice of lemon" → "Juice of Lemon"
  static String cleanName(String name) {
    // Remove leading/trailing whitespace and collapse internal whitespace
    var cleaned = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Remove trailing punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[,;:.]+$'), '').trim();
    
    if (cleaned.isEmpty) return cleaned;
    
    // Words that should stay lowercase (unless first word)
    const lowercaseWords = {'a', 'an', 'the', 'and', 'or', 'of', 'for', 'to', 'in', 'on', 'at', 'by', 'with'};
    
    // Apply Title Case to all words
    final words = cleaned.split(' ');
    final titleCased = words.asMap().entries.map((entry) {
      final i = entry.key;
      final word = entry.value;
      if (word.isEmpty) return word;
      
      // First word always capitalized
      if (i == 0) {
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }
      
      // Keep short common words lowercase
      if (lowercaseWords.contains(word.toLowerCase())) {
        return word.toLowerCase();
      }
      
      // Capitalize first letter of other words
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    
    return titleCased;
  }
  
  /// Convert text to simple Title Case (first letter uppercase, rest lowercase).
  static String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
  
  /// Normalize fractions to unicode characters.
  /// 
  /// Handles:
  /// - Text fractions: "1/2" → "½"
  /// - Decimals: "0.5" → "½", "0.333" → "⅓"
  /// - Repeating decimals: "0.333..." → "⅓", "0.666..." → "⅔"
  /// 
  /// Examples:
  /// - "1 1/2 cups" → "1½ cups"
  /// - "0.25 lb" → "¼ lb"
  /// - "0.333 tsp" → "⅓ tsp"
  static String normalizeFractions(String? text) {
    if (text == null || text.isEmpty) return text ?? '';
    
    var result = text;
    
    // Text fraction to unicode mapping
    const textToFraction = {
      '1/2': '½', '1/4': '¼', '3/4': '¾',
      '1/3': '⅓', '2/3': '⅔',
      '1/8': '⅛', '3/8': '⅜', '5/8': '⅝', '7/8': '⅞',
      '1/5': '⅕', '2/5': '⅖', '3/5': '⅗', '4/5': '⅘',
      '1/6': '⅙', '5/6': '⅚',
    };
    
    // Replace text fractions first (before decimals to avoid conflicts)
    for (final entry in textToFraction.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    
    // Replace long decimal representations of fractions
    // Match 0.333... (1/3), 0.666... (2/3), 0.166... (1/6), 0.833... (5/6)
    result = result.replaceAllMapped(
      RegExp(r'\b0\.3{3,}\d*\b'),  // 0.333...
      (m) => '⅓',
    );
    result = result.replaceAllMapped(
      RegExp(r'\b0\.6{3,}\d*\b'),  // 0.666...
      (m) => '⅔',
    );
    result = result.replaceAllMapped(
      RegExp(r'\b0\.16{2,}\d*\b'), // 0.166...
      (m) => '⅙',
    );
    result = result.replaceAllMapped(
      RegExp(r'\b0\.83{2,}\d*\b'), // 0.833...
      (m) => '⅚',
    );
    
    // Decimal to fraction mapping for common short decimals
    const decimalToFraction = {
      '0.5': '½', '0.25': '¼', '0.75': '¾',
      '0.33': '⅓', '0.333': '⅓', '0.67': '⅔', '0.666': '⅔', '0.667': '⅔',
      '0.125': '⅛', '0.375': '⅜', '0.625': '⅝', '0.875': '⅞',
      '0.2': '⅕', '0.4': '⅖', '0.6': '⅗', '0.8': '⅘',
    };
    
    // Replace decimals
    for (final entry in decimalToFraction.entries) {
      // Only replace if it's a standalone decimal or at word boundary
      result = result.replaceAll(RegExp('(?<![\\d])${RegExp.escape(entry.key)}(?![\\d])'), entry.value);
    }
    
    return result;
  }
}

/// Normalize garnish text: remove leading articles, apply title case
/// 
/// Examples:
/// - "a lemon wedge" → "Lemon Wedge"
/// - "A sprig of mint" → "Sprig of Mint"
/// - "the orange peel." → "Orange Peel"
String normalizeGarnish(String text) {
  var cleaned = text.trim();
  
  // Remove trailing punctuation
  cleaned = cleaned.replaceAll(RegExp(r'[.,;:!?]+$'), '');
  
  // Remove leading articles (a, an, the)
  cleaned = cleaned.replaceFirst(RegExp(r'^(a|an|the)\s+', caseSensitive: false), '');
  
  // Use shared cleanName for consistent Title Case
  return TextNormalizer.cleanName(cleaned);
}
