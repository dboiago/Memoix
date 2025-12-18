/// Utility for normalizing measurement units to their abbreviations
class UnitNormalizer {
  /// Map of common unit variations to their normalized abbreviation
  static const Map<String, String> _unitMap = {
    // Volume - cups
    'cup': 'C',
    'cups': 'C',
    'c': 'C',
    
    // Volume - tablespoons
    'tablespoon': 'Tbsp',
    'tablespoons': 'Tbsp',
    'tbs': 'Tbsp',
    'tb': 'Tbsp',
    't': 'Tbsp', // Only uppercase T, lowercase t is teaspoon
    
    // Volume - teaspoons
    'teaspoon': 'tsp',
    'teaspoons': 'tsp',
    'ts': 'tsp',
    
    // Volume - fluid ounces
    'fluid ounce': 'fl oz',
    'fluid ounces': 'fl oz',
    'fl. oz': 'fl oz',
    'fl.oz': 'fl oz',
    'floz': 'fl oz',
    
    // Volume - liters
    'liter': 'L',
    'liters': 'L',
    'litre': 'L',
    'litres': 'L',
    'l': 'L',
    
    // Volume - milliliters
    'milliliter': 'ml',
    'milliliters': 'ml',
    'millilitre': 'ml',
    'millilitres': 'ml',
    'mls': 'ml',
    
    // Weight - grams
    'gram': 'g',
    'grams': 'g',
    'gr': 'g',
    'gm': 'g',
    'gms': 'g',
    
    // Weight - kilograms
    'kilogram': 'kg',
    'kilograms': 'kg',
    'kilo': 'kg',
    'kilos': 'kg',
    'kgs': 'kg',
    
    // Weight - milligrams
    'milligram': 'mg',
    'milligrams': 'mg',
    'mgs': 'mg',
    
    // Weight - ounces
    'ounce': 'oz',
    'ounces': 'oz',
    
    // Weight - pounds
    'pound': 'lb',
    'pounds': 'lb',
    'lbs': 'lb',
    
    // Common cooking units
    'can': 'can',
    'cans': 'cans',
    'bunch': 'bunch',
    'bunches': 'bunches',
    'clove': 'clove',
    'cloves': 'cloves',
    'pinch': 'pinch',
    'pinches': 'pinches',
    'dash': 'dash',
    'dashes': 'dashes',
    'slice': 'slice',
    'slices': 'slices',
    'piece': 'pc',
    'pieces': 'pcs',
    'pcs': 'pcs',
    'pc': 'pc',
    'sprig': 'sprig',
    'sprigs': 'sprigs',
    'stalk': 'stalk',
    'stalks': 'stalks',
    'head': 'head',
    'heads': 'heads',
    'package': 'pkg',
    'packages': 'pkgs',
    'pkg': 'pkg',
    'pkgs': 'pkgs',
    'stick': 'stick',
    'sticks': 'sticks',
    'drop': 'drop',
    'drops': 'drops',
    'handful': 'handful',
    'handfuls': 'handfuls',
    'pint': 'pt',
    'pints': 'pt',
    'pt': 'pt',
    'quart': 'qt',
    'quarts': 'qt',
    'qt': 'qt',
    'gallon': 'gal',
    'gallons': 'gal',
    'gal': 'gal',
  };
  
  /// Normalize a unit string to its abbreviation
  /// Returns the original string if no match is found
  static String normalize(String? unit) {
    if (unit == null || unit.isEmpty) return '';
    
    var trimmed = unit.trim();
    
    // Strip trailing period (e.g., "tsp." -> "tsp")
    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    
    final lower = trimmed.toLowerCase();
    
    // Check for exact match in map
    if (_unitMap.containsKey(lower)) {
      return _unitMap[lower]!;
    }
    
    // Check if it's already a normalized abbreviation (preserve case)
    final normalizedValues = _unitMap.values.toSet();
    if (normalizedValues.contains(trimmed)) {
      return trimmed;
    }
    
    // Return original if no match
    return trimmed;
  }
  
  /// Check if a string is a recognized unit
  static bool isRecognizedUnit(String? unit) {
    if (unit == null || unit.isEmpty) return false;
    final lower = unit.toLowerCase().trim();
    return _unitMap.containsKey(lower) || 
           _unitMap.values.contains(unit.trim());
  }
  
  /// Get all possible unit options for autocomplete
  static List<String> get allUnits {
    return _unitMap.values.toSet().toList()..sort();
  }
  
  /// Get common units for display in UI
  static const List<String> commonUnits = [
    'C',
    'Tbsp',
    'tsp',
    'oz',
    'lb',
    'g',
    'kg',
    'ml',
    'L',
    'can',
    'clove',
    'bunch',
    'pinch',
    'dash',
    'slice',
    'pc',
  ];

  /// Normalize units for all items in a list that have a unit field
  /// Works with List<Ingredient>, List<SmokingSeasoning>, List<ModernistIngredient>, etc.
  static void normalizeUnitsInList(List list) {
    for (final item in list) {
      // Use dynamic to access unit field regardless of type
      final dynamic itemWithUnit = item;
      if (itemWithUnit.unit != null && itemWithUnit.unit is String) {
        final unit = itemWithUnit.unit as String;
        if (unit.isNotEmpty) {
          itemWithUnit.unit = normalize(unit);
        }
      }
    }
  }

  /// Normalize time strings to compact format (e.g., "4h 30m", "1d", "45m")
  /// Handles various input formats: "1 hour", "30 minutes", "1 day 2 hours", etc.
  static String normalizeTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    
    final trimmed = timeStr.trim().toLowerCase();
    
    // Parse components
    int totalMinutes = 0;
    
    // Match days
    final dayMatch = RegExp(r'(\d+)\s*(?:days?|d\b)').firstMatch(trimmed);
    if (dayMatch != null) {
      totalMinutes += int.parse(dayMatch.group(1)!) * 1440;
    }
    
    // Match hours
    final hourMatch = RegExp(r'(\d+)\s*(?:hours?|hrs?|h\b)').firstMatch(trimmed);
    if (hourMatch != null) {
      totalMinutes += int.parse(hourMatch.group(1)!) * 60;
    }
    
    // Match minutes
    final minMatch = RegExp(r'(\d+)\s*(?:minutes?|mins?|m\b)').firstMatch(trimmed);
    if (minMatch != null) {
      totalMinutes += int.parse(minMatch.group(1)!);
    }
    
    // If nothing parsed, return original
    if (totalMinutes == 0) return timeStr;
    
    return formatMinutes(totalMinutes);
  }

  /// Format total minutes as compact string (e.g., "4h 30m", "1d", "45m")
  static String formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    
    final days = totalMinutes ~/ 1440;
    final remAfterDays = totalMinutes % 1440;
    final hours = remAfterDays ~/ 60;
    final mins = remAfterDays % 60;
    
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (mins > 0) parts.add('${mins}m');
    
    return parts.join(' ');
  }

  /// Normalize serves string to just numbers (e.g., "Serves 4" -> "4", "4 people" -> "4")
  static String normalizeServes(String? serves) {
    if (serves == null || serves.isEmpty) return '';
    
    // Extract just the number(s)
    final match = RegExp(r'(\d+(?:\s*[-–]\s*\d+)?)').firstMatch(serves);
    if (match != null) {
      return match.group(1)!.replaceAll(RegExp(r'\s+'), '');
    }
    
    return serves.trim();
  }
}