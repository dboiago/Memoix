import 'smoking_recipe.dart';

/// Result of importing a smoking recipe from URL
/// Contains both parsed data and raw extracted data for user review
class SmokingImportResult {
  /// Parsed recipe fields (best guess)
  final String? name;
  final String? temperature;
  final String? time;
  final String? wood;
  final List<SmokingSeasoning> seasonings;
  final List<String> directions;
  final String? notes;
  final String? imageUrl;

  /// Raw extracted data for user mapping
  final List<RawIngredient> rawIngredients;
  final List<String> detectedTemperatures;
  final List<String> detectedWoods;
  final List<String> rawDirections;

  /// Confidence scores (0.0 - 1.0)
  final double nameConfidence;
  final double temperatureConfidence;
  final double timeConfidence;
  final double woodConfidence;
  final double seasoningsConfidence;
  final double directionsConfidence;

  /// Source URL
  final String sourceUrl;

  SmokingImportResult({
    this.name,
    this.temperature,
    this.time,
    this.wood,
    this.seasonings = const [],
    this.directions = const [],
    this.notes,
    this.imageUrl,
    this.rawIngredients = const [],
    this.detectedTemperatures = const [],
    this.detectedWoods = const [],
    this.rawDirections = const [],
    this.nameConfidence = 0.0,
    this.temperatureConfidence = 0.0,
    this.timeConfidence = 0.0,
    this.woodConfidence = 0.0,
    this.seasoningsConfidence = 0.0,
    this.directionsConfidence = 0.0,
    required this.sourceUrl,
  });

  /// Overall confidence score (weighted average)
  double get overallConfidence {
    // Weight the most important fields higher
    const weights = {
      'name': 0.15,
      'temperature': 0.20,
      'time': 0.15,
      'wood': 0.15,
      'seasonings': 0.15,
      'directions': 0.20,
    };

    return (nameConfidence * weights['name']!) +
        (temperatureConfidence * weights['temperature']!) +
        (timeConfidence * weights['time']!) +
        (woodConfidence * weights['wood']!) +
        (seasoningsConfidence * weights['seasonings']!) +
        (directionsConfidence * weights['directions']!);
  }

  /// Whether this result needs user review (confidence below threshold)
  bool get needsUserReview => overallConfidence < 0.7;

  /// Whether we have enough data to create a recipe
  bool get hasMinimumData =>
      name != null && name!.isNotEmpty && directions.isNotEmpty;

  /// Fields that need attention (low confidence)
  List<String> get fieldsNeedingAttention {
    final fields = <String>[];
    if (temperatureConfidence < 0.5) fields.add('temperature');
    if (woodConfidence < 0.5) fields.add('wood');
    if (seasoningsConfidence < 0.5) fields.add('seasonings');
    if (timeConfidence < 0.5) fields.add('time');
    return fields;
  }

  /// Convert to a SmokingRecipe (for high-confidence imports)
  SmokingRecipe toRecipe(String uuid) {
    return SmokingRecipe.create(
      uuid: uuid,
      name: name ?? 'Untitled',
      temperature: temperature ?? '225°F',
      time: time ?? '',
      wood: wood ?? '',
      seasonings: seasonings,
      directions: directions,
      notes: notes,
      imageUrl: imageUrl,
      source: SmokingSource.imported,
    );
  }
}

/// A raw ingredient from the URL, before classification
class RawIngredient {
  final String original;
  final String? amount;
  final String name;
  final bool isSeasoning; // Our guess
  final bool isMainProtein; // Likely the meat being smoked
  final bool isLiquid; // Broth, sauce, etc.

  RawIngredient({
    required this.original,
    this.amount,
    required this.name,
    this.isSeasoning = false,
    this.isMainProtein = false,
    this.isLiquid = false,
  });

  /// Convert to SmokingSeasoning if marked as seasoning
  SmokingSeasoning toSeasoning() {
    return SmokingSeasoning.create(
      name: _titleCase(name),
      amount: _normalizeUnits(amount),
    );
  }

  String _titleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String? _normalizeUnits(String? amt) {
    if (amt == null || amt.isEmpty) return amt;
    var a = amt;
    a = a.replaceAll(RegExp(r'\btablespoons?\b', caseSensitive: false), 'Tbsp');
    a = a.replaceAll(RegExp(r'\btables?\b', caseSensitive: false), 'Tbsp');
    a = a.replaceAll(RegExp(r'\btsp\b', caseSensitive: false), 'tsp');
    a = a.replaceAll(RegExp(r'\bteaspoons?\b', caseSensitive: false), 'tsp');
    a = a.replaceAll(RegExp(r'\bcups?\b', caseSensitive: false), 'cup');
    a = a.replaceAll(RegExp(r'\blbs?\b', caseSensitive: false), 'lb');
    a = a.replaceAll(RegExp(r'\bpounds?\b', caseSensitive: false), 'lb');
    a = a.replaceAll(RegExp(r'\boz(?:\.|es)?\b', caseSensitive: false), 'oz');
    return a;
  }
}
