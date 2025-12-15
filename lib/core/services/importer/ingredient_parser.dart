import '../../recipes/models/recipe.dart'; // Import your Ingredient model

class IngredientParser {
  // --- Constants (Moved from monolith) ---
  static const _htmlEntities = { '&amp;': '&', '&lt;': '<', '&gt;': '>', '&frac12;': '½', /* ... add rest */ };
  static const _fractionMap = { '1/2': '½', '1/4': '¼', /* ... add rest */ };
  
  // --- Public API ---

  /// Cleans and parses a list of raw strings into Ingredient objects
  List<Ingredient> parseList(List<String> rawItems) {
    if (rawItems.isEmpty) return [];
    
    // 1. Deduplicate
    final uniqueItems = _deduplicate(rawItems);
    
    // 2. Rejoin split lines (fixing comma splits)
    final rejoined = _rejoinSplitIngredients(uniqueItems);
    
    // 3. Parse individual strings
    return rejoined.map(_parseSingle).toList();
  }

  /// Parses a single string into an Ingredient object
  Ingredient _parseSingle(String raw) {
    String clean = decodeHtml(raw);
    
    // ... [Insert logic from _parseIngredientString here] ...
    // This includes the regex for amounts, units, and sections
    
    // For brevity of this refactor example, returning a stub. 
    // You will move your existing _parseIngredientString logic here.
    return Ingredient.create(name: clean, amount: null); 
  }

  /// Shared HTML decoding used by all parsers
  String decodeHtml(String text) {
    var result = text;
    // ... [Insert logic from _decodeHtml here] ...
    return result.trim();
  }

  // --- Internal Helpers ---
  List<String> _deduplicate(List<String> items) { /* ... logic from _deduplicateIngredients ... */ return items; }
  List<String> _rejoinSplitIngredients(List<String> items) { /* ... logic from _rejoinSplitIngredients ... */ return items; }
}
