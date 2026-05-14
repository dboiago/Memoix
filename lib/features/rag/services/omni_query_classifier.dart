import '../../recipes/models/continent_mapping.dart';
import '../../recipes/models/course.dart';
import '../../recipes/models/cuisine.dart';

enum OmniQueryType { suggestion, collection }

class OmniQueryClassification {
  final OmniQueryType type;
  /// Title-cased cuisine terms detected in the query (e.g. ['Italian', 'South African']).
  final List<String>? detectedCuisines;
  final String? detectedCourse;

  const OmniQueryClassification({
    required this.type,
    this.detectedCuisines,
    this.detectedCourse,
  });

  /// Lowercased cuisine list for RPC filter_cuisine calls.
  List<String>? get cuisinesForFilter =>
      detectedCuisines?.map((c) => c.toLowerCase()).toList();
}

abstract class OmniQueryClassifier {
  OmniQueryClassification classify(String query);
}

class HeuristicQueryClassifier implements OmniQueryClassifier {
  const HeuristicQueryClassifier();

  static const List<String> _vibeMarkers = [
    'comfort', 'heavy', 'light', 'fresh', 'warm', 'rainy', 'weekend',
    'cozy', 'sick of', 'tired of', 'nothing', 'avoid',
  ];

  static const List<String> _suggestionMarkers = [
    'something', 'recommend', 'feel like', 'pick', 'surprise',
  ];

  static const List<String> _collectionMarkers = [
    'show me', 'list', 'browse', 'recipes', 'dishes',
  ];

  static const List<String> _mealContextWords = [
    'dinner', 'lunch', 'breakfast', 'brunch', 'snack', 'supper',
    'tonight', 'today', 'quick', 'easy', 'charcuterie',
  ];

  @override
  OmniQueryClassification classify(String query) {
    final q = query.toLowerCase();

    final (:cuisine, :course, :matchCount) = _scanTaxonomy(q);

    // Step 0: Cuisine-browse intent.
    // Collect ALL cuisine terms from ContinentMapping that match word boundaries.
    // If at least one matches and no meal-context word is present, return a
    // browse/collection result immediately.
    final List<String> matchedCuisines = [];
    for (final key in ContinentMapping.cuisineToCountry.keys) {
      if (_matchesBoundary(q, key)) {
        matchedCuisines.add(_toTitleCase(key));
      }
    }
    if (matchedCuisines.isNotEmpty &&
        !_mealContextWords.any((w) => _matchesBoundary(q, w))) {
      return OmniQueryClassification(
        type: OmniQueryType.collection,
        detectedCuisines: matchedCuisines,
        detectedCourse: course,
      );
    }

    // Step 1: Vibe/aversion markers → suggestion immediately.
    for (final marker in _vibeMarkers) {
      if (q.contains(marker)) {
        return OmniQueryClassification(
          type: OmniQueryType.suggestion,
          detectedCuisines: cuisine != null ? [_toTitleCase(cuisine)] : null,
          detectedCourse: course,
        );
      }
    }

    // Step 2: Suggestion-intent markers → suggestion.
    // 'a ' uses trailing space to avoid matching mid-word substrings.
    if (q.contains('a ') || _suggestionMarkers.any(q.contains)) {
      return OmniQueryClassification(
        type: OmniQueryType.suggestion,
        detectedCuisines: cuisine != null ? [_toTitleCase(cuisine)] : null,
        detectedCourse: course,
      );
    }

    // Step 3: Collection-intent markers → collection.
    // 'all' is matched as a whole word only.
    if (RegExp(r'\ball\b').hasMatch(q) || _collectionMarkers.any(q.contains)) {
      return OmniQueryClassification(
        type: OmniQueryType.collection,
        detectedCuisines: cuisine != null ? [_toTitleCase(cuisine)] : null,
        detectedCourse: course,
      );
    }

    // Step 4: Taxonomy count.
    // Exactly one distinct taxonomy value → collection with that value populated.
    // Two or more → suggestion with detected values populated where applicable.
    if (matchCount == 1) {
      return OmniQueryClassification(
        type: OmniQueryType.collection,
        detectedCuisines: cuisine != null ? [_toTitleCase(cuisine)] : null,
        detectedCourse: course,
      );
    }
    if (matchCount >= 2) {
      return OmniQueryClassification(
        type: OmniQueryType.suggestion,
        detectedCuisines: cuisine != null ? [_toTitleCase(cuisine)] : null,
        detectedCourse: course,
      );
    }

    // Step 5: Default → suggestion.
    return OmniQueryClassification(
      type: OmniQueryType.suggestion,
      detectedCuisines: cuisine != null ? [_toTitleCase(cuisine)] : null,
      detectedCourse: course,
    );
  }

  ({String? cuisine, String? course, int matchCount}) _scanTaxonomy(String q) {
    String? firstCuisine;
    String? firstCourse;
    int matchCount = 0;

    for (final c in Cuisine.all) {
      if (_matchesBoundary(q, c.name.toLowerCase())) {
        firstCuisine ??= c.name;
        matchCount++;
      }
    }

    for (final c in Course.defaults) {
      final nameMatches = _matchesBoundary(q, c.name.toLowerCase());
      final slugMatches = _matchesBoundary(q, c.slug.toLowerCase());
      if (nameMatches || slugMatches) {
        firstCourse ??= c.slug;
        matchCount++;
      }
    }

    return (cuisine: firstCuisine, course: firstCourse, matchCount: matchCount);
  }

  bool _matchesBoundary(String text, String term) {
    if (term.isEmpty) return false;
    return RegExp(r'\b' + RegExp.escape(term) + r'\b').hasMatch(text);
  }

  static String _toTitleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
