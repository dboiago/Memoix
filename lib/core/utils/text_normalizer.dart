/// Text normalization utilities for consistent data entry across the app.
/// 
/// These functions ensure the same normalization is applied whether data
/// comes from OCR, URL import, or manual entry.

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
  
  // Title case each word (except small words like "of", "and", "with")
  const smallWords = {'of', 'and', 'with', 'or', 'a', 'an', 'the', 'in', 'on'};
  final words = cleaned.split(' ');
  final titleCased = words.asMap().entries.map((entry) {
    final index = entry.key;
    final word = entry.value;
    if (word.isEmpty) return word;
    
    final lower = word.toLowerCase();
    // Always capitalize first word, otherwise check if it's a small word
    if (index == 0 || !smallWords.contains(lower)) {
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }
    return lower;
  }).join(' ');
  
  return titleCased;
}
