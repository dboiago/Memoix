import 'package:flutter/material.dart';

/// Color palette for Memoix app
/// Based on spreadsheet color-coding system for recipe categories
class MemoixColors {
  MemoixColors._();

  // Primary brand colors
  static const Color primary = Color(0xFFE67C23); // Warm orange (like your header)
  static const Color primaryLight = Color(0xFFFFA726);
  static const Color primaryDark = Color(0xFFE65100);

  // Course category colors (matching spreadsheet tabs)
  static const Color mains = Color(0xFFFFB74D);       // Orange/Gold
  static const Color apps = Color(0xFF81C784);        // Green
  static const Color soups = Color(0xFF64B5F6);       // Blue
  static const Color salads = Color(0xFFA5D6A7);      // Light green
  static const Color brunch = Color(0xFFFFD54F);      // Yellow
  static const Color sides = Color(0xFFDCE775);       // Lime
  static const Color desserts = Color(0xFFF48FB1);    // Pink
  static const Color breads = Color(0xFFD7CCC8);      // Tan/Brown
  static const Color rubs = Color(0xFFBCAAA4);        // Brown
  static const Color sauces = Color(0xFFFF8A65);      // Coral
  static const Color pickles = Color(0xFFAED581);     // Lime green
  static const Color molecular = Color(0xFFCE93D8);   // Purple
  static const Color pizzas = Color(0xFFFFCC80);      // Light orange
  static const Color sandwiches = Color(0xFFFFE082);  // Light gold
  static const Color smoking = Color(0xFF90A4AE);     // Gray
  static const Color cheese = Color(0xFFFFF176);      // Light yellow
  static const Color vegan = Color(0xFF80CBC4);       // Teal
  static const Color scratch = Color(0xFFB0BEC5);     // Blue-gray
  static const Color drinks = Color(0xFF81D4FA);      // Light blue

  // Cuisine style colors (for highlighting rows like in spreadsheet)
  static const Color korean = Color(0xFFFFE082);      // Light gold
  static const Color french = Color(0xFFB3E5FC);      // Light blue
  static const Color italian = Color(0xFFC8E6C9);     // Light green
  static const Color mexican = Color(0xFFFFCCBC);     // Light coral
  static const Color japanese = Color(0xFFF8BBD9);    // Light pink
  static const Color indian = Color(0xFFFFE0B2);      // Light orange
  static const Color american = Color(0xFFE1BEE7);    // Light purple
  static const Color chinese = Color(0xFFFFECB3);     // Cream
  static const Color mediterranean = Color(0xFFB2DFDB); // Mint
  static const Color vietnamese = Color(0xFFDCEDC8);  // Light lime
  static const Color thai = Color(0xFFFFCDD2);        // Light red
  static const Color greek = Color(0xFFB2EBF2);       // Light cyan
  static const Color spanish = Color(0xFFF0F4C3);     // Light lime yellow
  static const Color german = Color(0xFFD7CCC8);      // Light brown
  static const Color lebanese = Color(0xFFE0F7FA);    // Pale cyan
  static const Color ethiopian = Color(0xFFD1C4E9);   // Light deep purple
  static const Color cuban = Color(0xFFFFF9C4);       // Light yellow
  static const Color brazilian = Color(0xFFDCEDC8);   // Light green
  static const Color peruvian = Color(0xFFFFE0B2);    // Light amber
  static const Color southern = Color(0xFFFFECB3);    // Light amber
  static const Color cajun = Color(0xFFFFCCBC);       // Light deep orange
  static const Color moroccan = Color(0xFFD7CCC8);    // Light brown
  static const Color turkish = Color(0xFFB3E5FC);     // Light blue

  // UI colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);

  /// Get color for a course category
  static Color forCourse(String course) {
    switch (course.toLowerCase()) {
      case 'mains':
        return mains;
      case 'apps':
      case 'appetizers':
        return apps;
      case 'soup':
      case 'soups':
        return soups;
      case 'salad':
      case 'salads':
        return salads;
      case 'brunch':
        return brunch;
      case 'sides':
        return sides;
      case 'desserts':
        return desserts;
      case 'breads':
        return breads;
      case 'rubs':
        return rubs;
      case 'sauces':
        return sauces;
      case 'pickles':
      case 'pickles/brines':
        return pickles;
      case 'molecular':
        return molecular;
      case 'pizzas':
        return pizzas;
      case 'sandwiches':
        return sandwiches;
      case 'smoking':
        return smoking;
      case 'cheese':
        return cheese;
      case 'veg*n':
      case 'vegan':
      case 'vegetarian':
      case 'not meat':
        return vegan;
      case 'scratch':
        return scratch;
      case 'drinks':
        return drinks;
      default:
        return primary;
    }
  }

  /// Get color for a cuisine style
  static Color forCuisine(String cuisine) {
    switch (cuisine.toLowerCase()) {
      case 'korean':
        return korean;
      case 'french':
        return french;
      case 'italian':
        return italian;
      case 'mexican':
        return mexican;
      case 'japanese':
        return japanese;
      case 'indian':
        return indian;
      case 'american':
        return american;
      case 'chinese':
        return chinese;
      case 'mediterranean':
        return mediterranean;
      case 'vietnamese':
        return vietnamese;
      case 'thai':
        return thai;
      case 'greek':
        return greek;
      case 'spanish':
        return spanish;
      case 'german':
        return german;
      case 'lebanese':
        return lebanese;
      case 'ethiopian':
        return ethiopian;
      case 'cuban':
        return cuban;
      case 'brazilian':
        return brazilian;
      case 'peruvian':
        return peruvian;
      case 'southern':
        return southern;
      case 'cajun':
        return cajun;
      case 'moroccan':
        return moroccan;
      case 'turkish':
        return turkish;
      case 'north american':
        return american;
      case 'south american':
        return brazilian;
      default:
        return Colors.grey.shade100;
    }
  }
}
