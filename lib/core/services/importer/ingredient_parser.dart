import '../../../../features/recipes/models/recipe.dart';

class IngredientParser {
  // --- Constants ---
  static const Map<String, String> _htmlEntities = {
    '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#34;': '"',
    '&apos;': "'", '&#39;': "'", '&nbsp;': ' ', '&#160;': ' ', '&ndash;': '–',
    '&#8211;': '–', '&mdash;': '—', '&#8212;': '—', '&frac12;': '½',
    '&#189;': '½', '&frac14;': '¼', '&#188;': '¼', '&frac34;': '¾',
    '&#190;': '¾', '&frac13;': '⅓', '&frac23;': '⅔', '&deg;': '°', '&#176;': '°',
  };

  static const Map<String, String> _fractionMap = {
    '1/2': '½', '1/4': '¼', '3/4': '¾', '1/3': '⅓', '2/3': '⅔',
    '1/8': '⅛', '3/8': '⅜', '5/8': '⅝', '7/8': '⅞', '1/5': '⅕',
    '2/5': '⅖', '3/5': '⅗', '4/5': '⅘', '1/6': '⅙', '5/6': '⅚',
  };

  static final Map<RegExp, String> _measurementNormalisation = {
    RegExp(r'\btbsp\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btbs\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btbl\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btablespoon[s]?\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btsp\b', caseSensitive: false): 'tsp',
    RegExp(r'\bteaspoon[s]?\b', caseSensitive: false): 'tsp',
    RegExp(r'\bcup[s]?\b', caseSensitive: false): 'cup',
    RegExp(r'\boz\b', caseSensitive: false): 'oz',
    RegExp(r'\bounce[s]?\b', caseSensitive: false): 'oz',
    RegExp(r'\blb[s]?\b', caseSensitive: false): 'lb',
    RegExp(r'\bpound[s]?\b', caseSensitive: false): 'lb',
    RegExp(r'\bkg\b', caseSensitive: false): 'kg',
    RegExp(r'\bkilogram[s]?\b', caseSensitive: false): 'kg',
    RegExp(r'\bg\b', caseSensitive: false): 'g',
    RegExp(r'\bgram[s]?\b', caseSensitive: false): 'g',
    RegExp(r'\bml\b', caseSensitive: false): 'ml',
    RegExp(r'\bmillilitre[s]?\b', caseSensitive: false): 'ml',
    RegExp(r'\bl\b', caseSensitive: false): 'L',
    RegExp(r'\blitre[s]?\b', caseSensitive: false): 'L',
  };

  /// Main entry point to parse a list of raw ingredient strings
  List<Ingredient> parseList(List<String> rawItems) {
    if (rawItems.isEmpty) return [];

    // 1. Process section headers within the list
    final uniqueItems = _deduplicateIngredients(rawItems);
    final processedStrings = _processIngredientListItems(uniqueItems);
    final rejoined = _rejoinSplitIngredients(processedStrings);
    
    // 2. Parse individual strings
    final List<Ingredient> result = [];
    String? currentSection;

    for (final item in rejoined) {
      final decoded = decodeHtml(item.trim());
      if (decoded.isEmpty) continue;

      // Check for [Section] header
      final bracketMatch = RegExp(r'^\[(.+)\]$').firstMatch(decoded);
      if (bracketMatch != null) {
        currentSection = bracketMatch.group(1)?.trim();
        continue;
      }

      final ingredient = _parseSingle(decoded);
      
      // Apply section logic
      if (ingredient.name.isNotEmpty || ingredient.section != null) {
        final effectiveSection = ingredient.section ?? currentSection;
        if (effectiveSection != null && effectiveSection != ingredient.section) {
          // Create new ingredient with updated section
          result.add(Ingredient.create(
            name: ingredient.name,
            amount: ingredient.amount,
            unit: ingredient.unit,
            preparation: ingredient.preparation,
            alternative: ingredient.alternative,
            isOptional: ingredient.isOptional,
            section: effectiveSection,
            bakerPercent: ingredient.bakerPercent,
          ));
        } else {
          result.add(ingredient);
        }
      }
    }
    
    // 3. Sort by quantity (largest first)
    return _sortIngredientsByQuantity(result);
  }

  /// Extracts the baker's percentage string if present
  String? extractBakerPercent(String text) {
    final match = RegExp(
      r'^[^,]+,\s*([\d.]+)%\s*[–—-]', 
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1);
  }

  /// Public HTML decoder helper
  String decodeHtml(String text) {
    var result = text;
    result = result.replaceAll(RegExp(r'<[^>]+>'), ''); // Strip tags
    
    _htmlEntities.forEach((entity, char) {
      result = result.replaceAll(entity, char);
    });
    
    result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    });
    result = result.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    });

    _fractionMap.forEach((k, v) => result = result.replaceAll(k, v));
    _measurementNormalisation.forEach((p, r) {
      result = result.replaceAllMapped(p, (_) => r);
    });

    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // --- Internal Parsing Logic ---

  Ingredient _parseSingle(String text) {
    var remaining = text;
    bool isOptional = false;
    final List<String> notesParts = [];
    String? amount;
    String? inlineSection;

    // Handle "Top up with [Ingredient]"
    final topUpMatch = RegExp(r'^Top\s+(?:up\s+)?with\s+(.+)$', caseSensitive: false).firstMatch(remaining);
    if (topUpMatch != null) {
      return Ingredient.create(name: topUpMatch.group(1)?.trim() ?? '', amount: 'Top');
    }

    // Handle Colon Amount: "Seedlip: 2 oz"
    final colonAmountMatch = RegExp(
      r'^([^:]+):\s*([\d.½¼¾⅓⅔⅛⅜⅝⅞]+\s*(?:oz|ml|cl|dash|dashes|drops?|barspoons?|tsp|tbsp)\.?|Top(?:\s+up)?|to\s+taste|as\s+needed)\s*(?:/\s*([\d.½¼¾⅓⅔⅛⅜⅝⅞]+\s*(?:ml|cl|oz)\.?))?(.*)$',
      caseSensitive: false,
    ).firstMatch(remaining);

    if (colonAmountMatch != null) {
       var name = colonAmountMatch.group(1)?.trim() ?? '';
       var primaryAmount = colonAmountMatch.group(2)?.trim() ?? '';
       final metricAmount = colonAmountMatch.group(3)?.trim();
       
       name = name.replaceAll(RegExp(r'^[\*†]+|[\*†]+$'), '').trim();
       if (primaryAmount.toLowerCase().contains('top')) primaryAmount = 'Top';
       
       String? preparation;
       if (metricAmount != null) preparation = metricAmount;
       
       return Ingredient.create(name: name, amount: primaryAmount, preparation: preparation);
    }

    // Handle Baker's Percentage
    final bakerMatch = RegExp(
      r'^([^,]+),\s*([\d.]+)%\s*[–—-]\s*([\d./½¼¾⅓⅔⅛⅜⅝⅞]+\s*(?:g|kg|ml|l|tsp|tbsp|cup|oz|lb)s?\.?)\s*(?:\(([^)]+)\))?',
      caseSensitive: false,
    ).firstMatch(remaining);

    if (bakerMatch != null) {
      return Ingredient.create(
        name: bakerMatch.group(1)?.trim() ?? '',
        amount: bakerMatch.group(3)?.trim() ?? '',
        preparation: bakerMatch.group(4)?.trim(),
        bakerPercent: '${bakerMatch.group(2)?.trim()}%'
      );
    }

    // Standard "Name, Amount (notes)"
    final nameAmountMatch = RegExp(
      r'^([^,]+),\s*(\d+(?:/\d+|[½¼¾⅓⅔⅛⅜⅝⅞])?(?:\s*\d+(?:/\d+|[½¼¾⅓⅔⅛⅜⅝⅞])?)?)\s*(g|kg|ml|l|oz|lb|cup|cups|tbsp|tsp|each|whole|large|medium|small)?\.?\s*(?:\(([^)]+)\))?$',
      caseSensitive: false,
    ).firstMatch(remaining);

    if (nameAmountMatch != null) {
      final name = nameAmountMatch.group(1)?.trim() ?? '';
      var amountNum = nameAmountMatch.group(2)?.trim() ?? '';
      final unit = nameAmountMatch.group(3)?.trim() ?? '';
      final notes = nameAmountMatch.group(4)?.trim();
      
      amountNum = amountNum.replaceAllMapped(RegExp(r'(\d+)/(\d+)'), (m) => (_fractionMap['${m[1]}/${m[2]}'] ?? m[0]!));
      final fullAmount = unit.isNotEmpty ? '$amountNum $unit' : amountNum;
      
      return Ingredient.create(name: name, amount: fullAmount, preparation: notes);
    }

    // Check for inline section markers
    final inlineSectionMatch = RegExp(r'^\[([^\]]+)\]\s*|^\((?:For\s+(?:the\s+)?)?([^)]+)\)\s*', caseSensitive: false).firstMatch(remaining);
    if (inlineSectionMatch != null) {
      inlineSection = (inlineSectionMatch.group(1) ?? inlineSectionMatch.group(2))?.trim();
      remaining = remaining.substring(inlineSectionMatch.end).trim();
      if (remaining.isEmpty) return Ingredient.create(name: '', section: inlineSection);
    }

    remaining = remaining.replaceAll(RegExp(r'^[\*†]+|[\*†]+$|\[\d+\]'), '').trim();

    // Parse main amount at start
    final compoundFractionMatch = RegExp(
      r'^(\d+)\s+([½¼¾⅓⅔⅛⅜⅝⅞]|1/2|1/4|3/4|1/3|2/3|1/8|3/8|5/8|7/8)'
      r'(\s*(?:teaspoons?|tablespoons?|cups?|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm)\.?)?\s+',
      caseSensitive: false,
    ).firstMatch(remaining);

    if (compoundFractionMatch != null) {
       final whole = compoundFractionMatch.group(1) ?? '';
       var fraction = compoundFractionMatch.group(2) ?? '';
       final unit = compoundFractionMatch.group(3)?.trim() ?? '';
       fraction = _fractionMap[fraction] ?? fraction;
       amount = unit.isNotEmpty ? '$whole$fraction $unit' : '$whole$fraction';
       remaining = remaining.substring(compoundFractionMatch.end).trim();
    } else {
      // Try simple start match
      final amountMatch = RegExp(
        r'^([\d½¼¾⅓⅔⅛⅜⅝⅞\s./-]+(?:cup|tbsp|tsp|g|oz|ml|L|kg|lb|large|small)?)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(remaining);
      
      if (amountMatch != null) {
         // Check if the first part looks like a valid amount
         final rawAmt = amountMatch.group(1)!.trim();
         // Basic validation: contains digit or fraction
         if (RegExp(r'[\d½¼¾⅓⅔⅛⅜⅝⅞]').hasMatch(rawAmt)) {
             amount = rawAmt;
             remaining = amountMatch.group(2)!.trim();
         }
      }
    }

    // Check for optional
    if (RegExp(r'\(\s*optional\s*\)|,\s*optional\s*$', caseSensitive: false).hasMatch(remaining)) {
      isOptional = true;
      remaining = remaining.replaceAll(RegExp(r'\(\s*optional\s*\)|,\s*optional\s*$', caseSensitive: false), '').trim();
      notesParts.add('optional');
    }

    // Extract parentheses to notes
    final parenMatches = RegExp(r'\(([^)]+)\)').allMatches(remaining).toList();
    for (final match in parenMatches.reversed) {
      final content = match.group(1)?.trim() ?? '';
      if (!content.contains(':') && !content.toLowerCase().contains('brix')) {
         notesParts.insert(0, content);
         remaining = remaining.substring(0, match.start) + remaining.substring(match.end);
      }
    }
    remaining = remaining.replaceAll(RegExp(r'\s+'), ' ').trim();
    remaining = remaining.replaceFirst(RegExp(r'^of\s+', caseSensitive: false), '');
    remaining = remaining.replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');

    return Ingredient.create(
      name: remaining,
      amount: _normalizeFractions(amount),
      preparation: notesParts.isNotEmpty ? notesParts.join(', ') : null,
      isOptional: isOptional,
      section: inlineSection,
    );
  }

  List<String> _processIngredientListItems(List<String> items) {
    final processed = <String>[];
    int sectionCount = 0;
    for (final item in items) {
      final isLikelySectionHeader = item.endsWith(':') && 
          !RegExp(r'\d').hasMatch(item) && item.length < 60 && !RegExp(r',\s').hasMatch(item);
      
      if (isLikelySectionHeader) {
        final sectionName = item.replaceAll(RegExp(r':$'), '').trim();
        sectionCount++;
        processed.add('[$sectionName]');
      } else {
        processed.add(item);
      }
    }
    if (sectionCount == 1 && processed.isNotEmpty && processed.first.startsWith('[')) {
      processed.removeAt(0);
    }
    return processed;
  }

  String? _normalizeFractions(String? text) {
    if (text == null) return null;
    var result = text;
    _fractionMap.forEach((k, v) => result = result.replaceAll(k, v));
    return result;
  }

  List<String> _deduplicateIngredients(List<String> items) {
    var seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        seen = {}; 
        result.add(item);
        continue;
      }
      final normalized = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      result.add(item);
    }
    return result;
  }

  List<String> _rejoinSplitIngredients(List<String> items) {
    if (items.length <= 1) return items;
    final result = <String>[];
    var buffer = '';
    int openParens = 0;
    
    for (final item in items) {
      final openCount = item.split('(').length - 1;
      final closeCount = item.split(')').length - 1;
      
      final looksLikeFragment = item.length <= 3 || RegExp(r'^[\d.,°\s]+$').hasMatch(item) ||
          (buffer.isNotEmpty && openParens > 0);
          
      if (buffer.isEmpty) {
        buffer = item;
        openParens = openCount - closeCount;
      } else if (looksLikeFragment || openParens > 0) {
        buffer = '$buffer, $item';
        openParens += openCount - closeCount;
      } else {
        result.add(buffer);
        buffer = item;
        openParens = openCount - closeCount;
      }
    }
    if (buffer.isNotEmpty) result.add(buffer);
    return result;
  }

  // --- Sorting Logic (Restored Full Version) ---

  List<Ingredient> _sortIngredientsByQuantity(List<Ingredient> ingredients) {
    if (ingredients.isEmpty) return ingredients;
    
    // Don't sort if there are section headers - preserve original order
    // Section headers are ingredients with empty name but non-null section
    final hasSectionHeaders = ingredients.any((i) => i.name.isEmpty && i.section != null);
    if (hasSectionHeaders) {
      return ingredients; 
    }
    
    // Group by section
    final Map<String?, List<Ingredient>> sections = {};
    for (final ing in ingredients) {
      sections.putIfAbsent(ing.section, () => []).add(ing);
    }
    
    // Sort each section by unit priority then quantity
    final result = <Ingredient>[];
    for (final section in sections.keys) {
      final sectionItems = sections[section]!;
      sectionItems.sort((a, b) {
        final aScore = _getIngredientSortScore(a.amount);
        final bScore = _getIngredientSortScore(b.amount);
        return bScore.compareTo(aScore); // Descending (largest first)
      });
      result.addAll(sectionItems);
    }
    
    return result;
  }

  double _getIngredientSortScore(String? amount) {
    if (amount == null || amount.isEmpty) return 0;
    
    final text = amount.toLowerCase();
    
    // Unit priority multipliers - weight first, then volume, then small measures
    double unitMultiplier = 1.0;
    
    // Weight units - highest priority
    if (text.contains('kg') || text.contains('kilogram')) {
      unitMultiplier = 10000.0; // kg - largest weight
    } else if (text.contains('lb') || text.contains('pound')) {
      unitMultiplier = 8000.0;
    } else if (RegExp(r'\bg\b').hasMatch(text) || text.contains('gram')) {
      unitMultiplier = 5000.0; // grams
    } else if (text.contains('oz') || text.contains('ounce')) {
      unitMultiplier = 4000.0;
    }
    // Whole items (pure numbers like "1 onion") - high priority
    else if (!RegExp(r'[a-zA-Z]').hasMatch(text)) {
      unitMultiplier = 3000.0;
    }
    // Volume units - medium priority
    else if (text.contains('l') && (text.contains(' l') || text.endsWith('l') || text.contains('liter') || text.contains('litre'))) {
      unitMultiplier = 2000.0; // liters
    } else if (text.contains('ml') || text.contains('milliliter')) {
      unitMultiplier = 1500.0;
    } else if (text.contains('cup') || RegExp(r'\bc\b').hasMatch(text)) {
      unitMultiplier = 1000.0; // cups
    }
    // Small measurements - lower priority
    else if (text.contains('tbsp') || text.contains('tablespoon')) {
      unitMultiplier = 100.0;
    } else if (text.contains('tsp') || text.contains('teaspoon')) {
      unitMultiplier = 10.0;
    } else if (text.contains('in') || text.contains('inch') || text.contains('"')) {
      unitMultiplier = 5.0; // length measurements
    }
    
    // Extract numeric quantity
    final quantity = _extractNumericQuantity(amount);
    
    return quantity * unitMultiplier;
  }

  double _extractNumericQuantity(String? amount) {
    if (amount == null || amount.isEmpty) return 0;
    
    final fractionValues = {
      '½': 0.5, '¼': 0.25, '¾': 0.75,
      '⅓': 0.33, '⅔': 0.67,
      '⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
      '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8,
      '⅙': 0.167, '⅚': 0.833,
    };
    
    var text = amount;
    double total = 0;
    
    // Replace unicode fractions with values
    fractionValues.forEach((k, v) {
      if (text.contains(k)) {
        total += v;
        text = text.replaceAll(k, '');
      }
    });
    
    // Try to find integer or range
    final numMatch = RegExp(r'(\d+)(?:\s*[-–]\s*(\d+))?').firstMatch(text);
    if (numMatch != null) {
      final first = double.tryParse(numMatch.group(1) ?? '') ?? 0;
      final second = double.tryParse(numMatch.group(2) ?? '');
      // Use the higher number in a range
      total += second ?? first;
    }
    
    return total;
  }
}
