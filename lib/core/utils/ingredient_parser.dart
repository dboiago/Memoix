/// Shared ingredient parsing utilities used by both URL and OCR importers.
/// 
/// This consolidates ingredient parsing logic to ensure consistent behavior
/// across all import methods and reduce code duplication.

/// Result of parsing an ingredient line into structured components
class ParsedIngredient {
  /// The original line text (for display purposes)
  final String original;
  
  /// The ingredient name (e.g., "all-purpose flour")
  final String name;
  
  /// The amount (e.g., "2", "1½", "1/2")
  final String? amount;
  
  /// The unit (e.g., "cup", "tbsp", "oz")
  final String? unit;
  
  /// Preparation notes (e.g., "divided", "room temperature", "diced")
  final String? preparation;
  
  /// Baker's percentage for bread recipes (e.g., "100%", "75%")
  final String? bakerPercent;
  
  /// Alternative ingredient (e.g., "or store-bought")
  final String? alternative;
  
  /// Section name if this line represents a section header (e.g., "For the Crust")
  final String? sectionName;
  
  /// Whether this line is a section header (vs a regular ingredient)
  final bool isSection;
  
  /// Whether this looks like a valid ingredient (vs a direction or prose)
  final bool looksLikeIngredient;
  
  const ParsedIngredient({
    this.original = '',
    required this.name,
    this.amount,
    this.unit,
    this.preparation,
    this.bakerPercent,
    this.alternative,
    this.sectionName,
    this.isSection = false,
    this.looksLikeIngredient = true,
  });
  
  /// Empty/invalid ingredient
  static const empty = ParsedIngredient(name: '', looksLikeIngredient: false);
}

/// Shared ingredient parsing logic used by both URL and OCR importers.
/// 
/// Handles various formats:
/// - Standard: "1 cup flour"
/// - Without unit: "2 eggs"
/// - Baker's percentage: "All-Purpose Flour, 100% – 600g"
/// - "X of Y": "Juice of 1 lemon"
/// - Modifiers: "2 eggs, beaten"
/// - Alternatives: "butter or margarine"
class IngredientParser {
  
  /// Unicode fraction characters for parsing
  static const unicodeFractions = 'ยฝยผยพโ…"โ…"โ…›โ…œโ…โ…ž';
  
  /// Fraction conversion map (text to unicode)
  static const fractionMap = <String, String>{
    '1/2': 'ยฝ',
    '1/4': 'ยผ',
    '3/4': 'ยพ',
    '1/3': 'โ…"',
    '2/3': 'โ…"',
    '1/8': 'โ…›',
    '3/8': 'โ…œ',
    '5/8': 'โ…',
    '7/8': 'โ…ž',
    '1/5': 'โ…•',
    '2/5': 'โ…–',
    '3/5': 'โ…—',
    '4/5': 'โ…˜',
    '1/6': 'โ…™',
    '5/6': 'โ…š',
  };
  
  /// Word numbers to digits
  static const wordNumbers = <String, String>{
    'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
    'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10',
    'eleven': '11', 'twelve': '12', 'a': '1', 'an': '1',
    'half': 'ยฝ', 'quarter': 'ยผ',
  };
  
  /// Parse an ingredient line into structured components.
  /// 
  /// This is the main entry point for ingredient parsing.
  /// Both URL and OCR importers should use this method.
  static ParsedIngredient parse(String line) {
    if (line.trim().isEmpty) return ParsedIngredient.empty;
    
    final original = line.trim();
    var workingLine = original;
    String? preparation;
    String? alternative;
    String? sectionName;
    
    // Check for section markers like "[Sauce]" or "(For the sauce)"
    final sectionMatch = RegExp(
      r'^\[([^\]]+)\]\s*$|^\((?:For\s+(?:the\s+)?)?([^)]+)\)\s*$',
      caseSensitive: false,
    ).firstMatch(workingLine);
    if (sectionMatch != null) {
      sectionName = (sectionMatch.group(1) ?? sectionMatch.group(2))?.trim();
      return ParsedIngredient(
        original: original,
        name: '',
        sectionName: sectionName,
        isSection: true,
        looksLikeIngredient: false,
      );
    }
    
    // Extract leading section markers that have content after them
    final inlineSectionMatch = RegExp(
      r'^\[([^\]]+)\]\s+|^\((?:For\s+(?:the\s+)?)?([^)]+)\)\s+',
      caseSensitive: false,
    ).firstMatch(workingLine);
    if (inlineSectionMatch != null) {
      sectionName = (inlineSectionMatch.group(1) ?? inlineSectionMatch.group(2))?.trim();
      workingLine = workingLine.substring(inlineSectionMatch.end).trim();
    }
    
    // Extract parenthetical content like "(page 78)" or "(optional)"
    final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(workingLine);
    if (parenMatch != null) {
      final parenContent = parenMatch.group(1)?.toLowerCase() ?? '';
      if (parenContent.contains('page') || 
          parenContent.contains('optional') ||
          parenContent.contains('see') ||
          parenContent.contains('about')) {
        preparation = parenMatch.group(1)?.trim();
        workingLine = workingLine.replaceFirst(parenMatch.group(0)!, '').trim();
      }
    }
    
    // Extract trailing modifiers like ", divided", ", softened"
    final modifierMatch = RegExp(
      r',\s*(divided|softened|melted|chilled|room temperature|at room temp|cold|warm|hot|cooled|beaten|lightly beaten|well beaten|sifted|packed|firmly packed|loosely packed|drained|rinsed|thawed|frozen|fresh|dried|chopped|minced|diced|sliced|grated|shredded|crushed|crumbled|cubed|quartered|halved|peeled|cored|seeded|pitted|trimmed|washed|cleaned|to taste|as needed)\s*$',
      caseSensitive: false,
    ).firstMatch(workingLine);
    if (modifierMatch != null) {
      final modifier = modifierMatch.group(1)?.trim();
      if (modifier != null) {
        preparation = preparation != null ? '$preparation; $modifier' : modifier;
        workingLine = workingLine.substring(0, modifierMatch.start).trim();
      }
    }
    
    // Extract "or ..." alternatives
    final orMatch = RegExp(r'\s+or\s+(.+)$', caseSensitive: false).firstMatch(workingLine);
    if (orMatch != null) {
      alternative = orMatch.group(1)?.trim();
      workingLine = workingLine.substring(0, orMatch.start).trim();
    }
    
    // Remove footnote markers like [1], *, โ€ 
    workingLine = workingLine.replaceAll(RegExp(r'^[\*โ€ ]+|[\*โ€ ]+$|\[\d+\]'), '').trim();
    
    // Convert word numbers to digits
    final wordNumberMatch = RegExp(
      r'^(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|a|an|half|quarter)\b\s*',
      caseSensitive: false,
    ).firstMatch(workingLine);
    if (wordNumberMatch != null) {
      final word = wordNumberMatch.group(1)!.toLowerCase();
      final digit = wordNumbers[word] ?? word;
      workingLine = digit + workingLine.substring(wordNumberMatch.end);
    }
    
    // Try baker's percentage format: "Name, XX% โ€" amount"
    final bakerMatch = RegExp(
      r'^([^,]+),\s*([\d.]+)%\s*[โ€"โ€"-]\s*(\d+\s*(?:g|kg|ml|l|oz|lb)?)\s*(?:\(([^)]+)\))?',
      caseSensitive: false,
    ).firstMatch(workingLine);
    if (bakerMatch != null) {
      return ParsedIngredient(
        original: original,
        name: _cleanName(bakerMatch.group(1)?.trim() ?? workingLine),
        bakerPercent: '${bakerMatch.group(2)}%',
        amount: bakerMatch.group(3)?.trim(),
        preparation: preparation ?? bakerMatch.group(4)?.trim(),
        alternative: alternative,
        sectionName: sectionName,
        looksLikeIngredient: true,
      );
    }
    
    // Try standard format: "amount unit name"
    // Includes metric units (g, kg, ml, gram, grams, kilogram, etc.) and
    // common cooking units (cloves, pinch, dash, bunch, head, sprig, etc.)
    final standardMatch = RegExp(
      r'^([\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:\s*/\s*\d+)?(?:\s*[\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:/\d+)?)?)\s*(cups?\.?|tbsps?\.?|tsps?\.?|oz\.?|lbs?\.?|g\.?|grams?|kg\.?|kilograms?|ml\.?|milliliters?|millilitres?|cl\.?|centiliters?|centilitres?|l\.?|liters?|litres?|pounds?\.?|ounces?\.?|teaspoons?\.?|tablespoons?\.?|parts?\.?|cloves?|heads?|bunch(?:es)?|sprigs?|slices?|pieces?|pinch(?:es)?|dash(?:es)?|stalks?|cans?|packages?|pkgs?\.?|c\.|t\.)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(workingLine);
    if (standardMatch != null) {
      final amount = standardMatch.group(1)?.trim();
      final unit = normalizeUnit(standardMatch.group(2)?.trim());
      return ParsedIngredient(
        original: original,
        name: _cleanName(standardMatch.group(3)?.trim() ?? workingLine),
        amount: amount,
        unit: pluralizeUnit(unit, amount),
        preparation: preparation,
        alternative: alternative,
        sectionName: sectionName,
        looksLikeIngredient: true,
      );
    }
    
    // Try format without explicit unit: "2 eggs", "3 cloves garlic"
    final simpleMatch = RegExp(
      r'^([\dยฝยผยพโ…"โ…"โ…›โ…œโ…โ…ž]+(?:\s*/\s*\d+)?(?:\s*[\dยฝยผยพโ…"โ…"โ…›โ…œโ…โ…ž]+)?)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(workingLine);
    if (simpleMatch != null) {
      var name = simpleMatch.group(2)?.trim() ?? workingLine;
      String? unit;
      final amount = simpleMatch.group(1)?.trim();
      
      // Check if name starts with a unit word
      final unitAtStartMatch = RegExp(
        r'^(cups?\.?|tbsps?\.?|tsps?\.?|oz\.?|lbs?\.?|g\.?|grams?|kg\.?|kilograms?|ml\.?|milliliters?|millilitres?|cl\.?|centiliters?|centilitres?|l\.?|liters?|litres?|pounds?\.?|ounces?\.?|teaspoons?\.?|tablespoons?\.?|parts?\.?|cloves?|heads?|bunch(?:es)?|sprigs?|slices?|pieces?|pinch(?:es)?|dash(?:es)?|stalks?|cans?|packages?|pkgs?\.?|c\.|t\.)\s+(.+)',
        caseSensitive: false,
      ).firstMatch(name);
      if (unitAtStartMatch != null) {
        unit = normalizeUnit(unitAtStartMatch.group(1)?.trim());
        unit = pluralizeUnit(unit, amount);
        name = unitAtStartMatch.group(2)?.trim() ?? name;
      }
      
      // Check if this looks like food (not a direction)
      final looksLikeFood = !RegExp(
        r'\b(preheat|bake|cook|stir|mix|add|pour|let|until|minutes?|degrees?|ยฐ)\b',
        caseSensitive: false,
      ).hasMatch(name);
      
      return ParsedIngredient(
        original: original,
        name: _cleanName(name),
        amount: amount,
        unit: unit,
        preparation: preparation,
        alternative: alternative,
        sectionName: sectionName,
        looksLikeIngredient: looksLikeFood && (unit != null || name.length < 40),
      );
    }
    
    // Try "X of Y" patterns: "Juice of 1 lemon"
    final ofPatternMatch = RegExp(
      r'^(juice|zest|rind|peel)\s+of\s+([\dยฝยผยพโ…"โ…"โ…›โ…œโ…โ…ž]+)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(workingLine);
    if (ofPatternMatch != null) {
      final part = ofPatternMatch.group(1)?.trim() ?? '';
      final amount = ofPatternMatch.group(2)?.trim();
      final ingredient = ofPatternMatch.group(3)?.trim() ?? '';
      // Reformat as "Ingredient Part" e.g., "Lemon Juice"
      final formattedName = '${_cleanName(ingredient)} ${_toTitleCase(part)}';
      return ParsedIngredient(
        original: original,
        name: formattedName,
        amount: amount,
        preparation: preparation,
        alternative: alternative,
        sectionName: sectionName,
        looksLikeIngredient: true,
      );
    }
    
    // Fallback - just use the line as name
    return ParsedIngredient(
      original: original,
      name: _cleanName(workingLine),
      preparation: preparation,
      alternative: alternative,
      sectionName: sectionName,
      looksLikeIngredient: workingLine.length < 60 && 
          !RegExp(r'\b(preheat|bake|cook|stir|mix|pour|until)\b', caseSensitive: false).hasMatch(workingLine),
    );
  }
  
  /// Normalize unit abbreviations to standard form.
  /// 
  /// Examples:
  /// - "tablespoons" โ†' "tbsp"
  /// - "cups" โ†' "cup"
  /// - "lbs." โ†' "lb"
  static String? normalizeUnit(String? unit) {
    if (unit == null) return null;
    final lower = unit.toLowerCase().replaceAll('.', '');
    
    const unitMap = <String, String>{
      'cup': 'cup',
      'cups': 'cup',
      'c': 'cup',
      'tbsp': 'tbsp',
      'tbsps': 'tbsp',
      'tablespoon': 'tbsp',
      'tablespoons': 'tbsp',
      'tsp': 'tsp',
      'tsps': 'tsp',
      'teaspoon': 'tsp',
      'teaspoons': 'tsp',
      't': 'tsp',
      'oz': 'oz',
      'ounce': 'oz',
      'ounces': 'oz',
      'lb': 'lb',
      'lbs': 'lb',
      'pound': 'lb',
      'pounds': 'lb',
      'g': 'g',
      'gram': 'g',
      'grams': 'g',
      'kg': 'kg',
      'kilogram': 'kg',
      'kilograms': 'kg',
      'ml': 'ml',
      'milliliter': 'ml',
      'milliliters': 'ml',
      'millilitre': 'ml',
      'millilitres': 'ml',
      'cl': 'cl',
      'centiliter': 'cl',
      'centiliters': 'cl',
      'centilitre': 'cl',
      'centilitres': 'cl',
      'l': 'L',
      'liter': 'L',
      'liters': 'L',
      'litre': 'L',
      'litres': 'L',
      'part': 'part',
      'parts': 'parts',
      'clove': 'clove',
      'cloves': 'cloves',
      'head': 'head',
      'heads': 'heads',
      'bunch': 'bunch',
      'bunches': 'bunches',
      'sprig': 'sprig',
      'sprigs': 'sprigs',
      'slice': 'slice',
      'slices': 'slices',
      'piece': 'piece',
      'pieces': 'pieces',
      'pinch': 'pinch',
      'pinches': 'pinches',
      'dash': 'dash',
      'dashes': 'dashes',
      'stalk': 'stalk',
      'stalks': 'stalks',
      'can': 'can',
      'cans': 'cans',
      'package': 'package',
      'packages': 'packages',
      'pkg': 'package',
      'pkgs': 'packages',
    };
    
    return unitMap[lower] ?? unit;
  }
  
  /// Get the appropriate unit form based on amount (singular vs plural).
  static String? pluralizeUnit(String? unit, String? amount) {
    if (unit == null) return null;
    if (amount == null) return unit;
    
    // Parse amount to determine if plural needed
    final numMatch = RegExp(r'^([\d.]+)').firstMatch(amount);
    if (numMatch != null) {
      final num = double.tryParse(numMatch.group(1) ?? '');
      if (num != null && num > 1) {
        if (unit == 'part') return 'parts';
        if (unit == 'cup') return 'cups';
        if (unit == 'lb') return 'lbs';
        // oz, tbsp, tsp, g, kg, ml, L stay the same
      }
    }
    
    // Check for fractions > 1 like "1ยฝ" or "2"
    if (amount.contains('ยฝ') || amount.contains('ยผ') || amount.contains('ยพ')) {
      final firstChar = amount.isNotEmpty ? amount[0] : '0';
      final firstNum = int.tryParse(firstChar);
      if (firstNum != null && firstNum >= 1 && amount.length > 1) {
        if (unit == 'part') return 'parts';
        if (unit == 'cup') return 'cups';
        if (unit == 'lb') return 'lbs';
      }
    }
    
    return unit;
  }
  
  /// Convert text fractions to unicode characters.
  /// 
  /// Examples:
  /// - "1/2 cup" โ†' "ยฝ cup"
  /// - "1 1/2 cups" โ†' "1ยฝ cups"
  static String normalizeFractions(String text) {
    var result = text;
    for (final entry in fractionMap.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
  
  /// Clean an ingredient name (remove extra whitespace, apply Title Case).
  /// 
  /// Applies Title Case to all words.
  /// Words like 'of', 'the', 'and', 'or' stay lowercase unless first word.
  static String _cleanName(String name) {
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
  
  /// Convert text to Title Case.
  static String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
