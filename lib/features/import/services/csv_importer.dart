import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';

/// Service to import recipes from CSV files exported from Google Sheets.
/// 
/// Expected format (Memoix Google Sheets structure):
/// - Cuisine headers: "Asian,,,,,," or "Chinese,,,,,,"
/// - Recipe name rows: "Name,,Serves,Time,Pairs With,Notes,Directions"
/// - Ingredient rows: "Ingredient Name,Amount,,,,Notes,Direction step"
/// - Section headers: "Sauce,,,,,," or "Seasoning,,,,,,"
/// - Empty rows as separators
class CsvRecipeImporter {
  static const _uuid = Uuid();

  /// Import recipes from a CSV file
  Future<List<Recipe>> importFromCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return [];
    }

    final file = result.files.first;
    String csvContent;

    if (file.path != null) {
      csvContent = await File(file.path!).readAsString();
    } else if (file.bytes != null) {
      csvContent = utf8.decode(file.bytes!);
    } else {
      throw Exception('Could not read file');
    }

    // Extract course from filename (e.g., "Recipes - Mains.csv" -> "Mains")
    String? courseFromFilename;
    final filename = file.name;
    if (filename.isNotEmpty) {
      courseFromFilename = _extractCourseFromFilename(filename);
    }

    return parseCSV(csvContent, defaultCourse: courseFromFilename);
  }

  /// Extract course name from filename like "Recipes - Mains.csv"
  String? _extractCourseFromFilename(String filename) {
    // Remove extension
    final nameWithoutExt = filename.replaceAll(RegExp(r'\.(csv|txt)$', caseSensitive: false), '');
    
    // Try pattern "Recipes - Course"
    final dashMatch = RegExp(r'[-–]\s*(.+)$').firstMatch(nameWithoutExt);
    if (dashMatch != null) {
      final coursePart = dashMatch.group(1)!.trim();
      final normalised = _normaliseCourse(coursePart);
      if (normalised != coursePart || _isCourse(coursePart)) {
        return normalised;
      }
    }
    
    // Try if filename itself is a course name
    final normalised = _normaliseCourse(nameWithoutExt);
    if (normalised != nameWithoutExt || _isCourse(nameWithoutExt)) {
      return normalised;
    }
    
    return null;
  }

  /// Parse CSV content into recipes
  /// [defaultCourse] - course extracted from filename, used if not found in content
  List<Recipe> parseCSV(String csvContent, {String? defaultCourse}) {
    final lines = const LineSplitter().convert(csvContent);
    final recipes = <Recipe>[];
    
    String? currentCuisine;
    String? currentCourse = defaultCourse;
    Recipe? currentRecipe;
    String? currentSection;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final cells = _parseCSVLine(line);
      
      // Skip completely empty lines
      if (cells.every((c) => c.isEmpty)) {
        continue;
      }
      
      final firstCell = cells.isNotEmpty ? cells[0].trim() : '';
      final secondCell = cells.length > 1 ? cells[1].trim() : '';
      
      // Check if this is a cuisine/region/course header (single cell with rest empty)
      if (firstCell.isNotEmpty && 
          cells.skip(1).every((c) => c.isEmpty) &&
          !_isRecipeNameRow(cells) &&
          !_looksLikeIngredient(firstCell, secondCell) &&
          !_isSectionHeader(firstCell, cells)) {
        
        // Determine if this is a course or cuisine
        if (_isCourse(firstCell)) {
          currentCourse = _normaliseCourse(firstCell);
          // Don't reset cuisine when changing course
        } else if (_isCuisineOrRegion(firstCell)) {
          currentCuisine = _normaliseCuisine(firstCell);
        }
        currentSection = null;
        continue;
      }
      
      // Check if this is a recipe "Name" row header
      if (firstCell.toLowerCase() == 'name' && 
          (cells.length < 3 || cells[2].toLowerCase() == 'serves' || cells[2].isEmpty)) {
        // This is a header row, skip it
        continue;
      }
      
      // Check if this is a section header (e.g., "Sauce", "Seasoning", "Filling")
      if (_isSectionHeader(firstCell, cells)) {
        currentSection = firstCell;
        continue;
      }
      
      // Check if this looks like a new recipe name row
      if (_isRecipeNameRow(cells)) {
        // Save current recipe if exists
        if (currentRecipe != null && currentRecipe.name.isNotEmpty) {
          recipes.add(currentRecipe);
        }
        
        // Start new recipe
        currentRecipe = Recipe.create(
          uuid: _uuid.v4(),
          name: firstCell,
          course: currentCourse ?? 'Mains',
          cuisine: currentCuisine,
          serves: cells.length > 2 ? _cleanCell(cells[2]) : null,
          time: cells.length > 3 ? _cleanCell(cells[3]) : null,
          pairsWith: cells.length > 4 ? _parsePairsWith(cells[4]) : [],
          notes: cells.length > 5 ? _cleanCell(cells[5]) : null,
          ingredients: [],
          directions: [],
          source: RecipeSource.imported,
        );
        currentSection = null;
        
        // Check if there's a direction in column 6
        if (cells.length > 6 && cells[6].isNotEmpty) {
          currentRecipe.directions.add(_cleanDirection(cells[6]));
        }
        continue;
      }
      
      // This must be an ingredient row
      if (currentRecipe != null && firstCell.isNotEmpty) {
        final ingredient = Ingredient.create(
          name: firstCell,
          amount: secondCell.isNotEmpty ? secondCell : null,
          section: currentSection,
        );
        
        // Parse notes (column 5) for alternatives or other info
        if (cells.length > 5 && cells[5].isNotEmpty) {
          final notes = cells[5];
          if (notes.toLowerCase().startsWith('alt:')) {
            ingredient.alternative = notes.substring(4).trim();
          } else {
            // Store in preparation field
            ingredient.preparation = notes;
          }
        }
        
        currentRecipe.ingredients.add(ingredient);
        
        // Check for direction in column 6
        if (cells.length > 6 && cells[6].isNotEmpty) {
          currentRecipe.directions.add(_cleanDirection(cells[6]));
        }
      }
    }
    
    // Don't forget the last recipe
    if (currentRecipe != null && currentRecipe.name.isNotEmpty) {
      recipes.add(currentRecipe);
    }
    
    return recipes;
  }
  
  /// Parse a CSV line handling quoted fields
  List<String> _parseCSVLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    
    result.add(buffer.toString());
    return result;
  }
  
  String? _cleanCell(String cell) {
    final cleaned = cell.trim();
    return cleaned.isEmpty ? null : cleaned;
  }
  
  String _cleanDirection(String direction) {
    var cleaned = direction.trim();
    // Remove leading "- " if present
    if (cleaned.startsWith('- ')) {
      cleaned = cleaned.substring(2);
    }
    return cleaned;
  }
  
  List<String> _parsePairsWith(String cell) {
    if (cell.isEmpty) return [];
    return cell
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.toLowerCase() != 'pairs with')
        .toList();
  }
  
  bool _isRecipeNameRow(List<String> cells) {
    if (cells.isEmpty) return false;
    final first = cells[0].trim();
    final second = cells.length > 1 ? cells[1].trim() : '';
    
    // Recipe name rows have a name in first column but NO amount in second
    // OR second column is empty and there's data in serves/time columns
    if (first.isEmpty) return false;
    if (first.toLowerCase() == 'name') return false;
    
    // If this looks like a cuisine or course header, it's NOT a recipe
    if (_isCuisineOrRegion(first) || _isCourse(first)) return false;
    
    // If second column looks like an amount, this is an ingredient row
    if (_looksLikeAmount(second)) return false;
    
    // Check if there's data in the "serves" or "time" position that looks right
    final serves = cells.length > 2 ? cells[2].trim() : '';
    final time = cells.length > 3 ? cells[3].trim() : '';
    
    if (serves.isNotEmpty || time.isNotEmpty) {
      // Likely a recipe row if serves/time look valid
      if (_looksLikeServes(serves) || _looksLikeTime(time)) {
        return true;
      }
    }
    
    // If the name contains typical ingredient words, it's probably not a recipe name
    if (_looksLikeIngredient(first, second)) return false;
    
    // Single-word entries with all other columns empty are likely headers, not recipes
    if (!first.contains(' ') && cells.skip(1).every((c) => c.trim().isEmpty)) {
      return false;
    }
    
    // Heuristic: recipe names are usually 2+ words or proper nouns
    return second.isEmpty;
  }
  
  bool _looksLikeAmount(String s) {
    if (s.isEmpty) return false;
    // Amounts typically start with numbers or fractions
    return RegExp(r'^[\d½¼¾⅓⅔⅛]').hasMatch(s) ||
           s.toLowerCase().contains('tbsp') ||
           s.toLowerCase().contains('tsp') ||
           s.toLowerCase().contains('cup') ||
           s.toLowerCase().contains('pinch') ||
           s.toLowerCase().contains('to taste');
  }
  
  bool _looksLikeServes(String s) {
    if (s.isEmpty) return true;
    return RegExp(r'^\d+(-\d+)?( people)?$', caseSensitive: false).hasMatch(s) ||
           s.toLowerCase().contains('serves');
  }
  
  bool _looksLikeTime(String s) {
    if (s.isEmpty) return true;
    return s.toLowerCase().contains('min') ||
           s.toLowerCase().contains('hr') ||
           s.toLowerCase().contains('hour') ||
           RegExp(r'^\d+\s*(m|h|min|hr)').hasMatch(s.toLowerCase());
  }
  
  bool _looksLikeIngredient(String name, String amount) {
    final nameLower = name.toLowerCase();
    // Common ingredient indicators
    final ingredientWords = [
      'oil', 'sauce', 'salt', 'pepper', 'sugar', 'flour', 'butter',
      'garlic', 'onion', 'egg', 'water', 'stock', 'broth', 'vinegar',
      'powder', 'paste', 'leaves', 'seeds', 'juice', 'zest',
    ];
    
    if (ingredientWords.any((w) => nameLower.contains(w))) {
      return true;
    }
    
    // If there's an amount, it's likely an ingredient
    if (_looksLikeAmount(amount)) {
      return true;
    }
    
    return false;
  }
  
  bool _isSectionHeader(String cell, List<String> allCells) {
    if (cell.isEmpty) return false;
    
    // Section headers are single words/phrases with the rest empty
    // and typically describe groups: Sauce, Seasoning, Filling, Topping, etc.
    final sectionKeywords = [
      'sauce', 'seasoning', 'filling', 'topping', 'glaze', 'marinade',
      'dressing', 'base', 'soup base', 'broth', 'stock',
    ];
    
    final cellLower = cell.toLowerCase();
    
    // Must have rest of row empty (or mostly empty)
    final restEmpty = allCells.skip(1).every((c) => c.trim().isEmpty);
    
    if (restEmpty && sectionKeywords.any((k) => cellLower.contains(k))) {
      return true;
    }
    
    // Also check for specific patterns like "Katsu-don Sauce" or "Tonkatsu Sauce"
    if (restEmpty && cellLower.endsWith('sauce')) {
      return true;
    }
    
    return false;
  }
  
  bool _isCourse(String cell) {
    final courseLower = cell.toLowerCase();
    return [
      'mains', 'main', 'apps', 'appetizers', 'appetiser', 'soups', 'soup',
      'salads', 'salad', 'sides', 'side', 'desserts', 'dessert', 'breads',
      'bread', 'brunch', 'breakfast', 'sauces', 'drinks', 'drink', 'beverages',
      'pizzas', 'pizza', 'rubs', 'rub', 'not meat', 'vegetarian', 'vegan',
      'sandwiches', 'sandwich', 'sandwhiches', 'sandwhich',
    ].contains(courseLower);
  }
  
  bool _isCuisineOrRegion(String cell) {
    final cellLower = cell.toLowerCase();
    // Known cuisines and regions
    final cuisines = [
      'asian', 'chinese', 'japanese', 'korean', 'vietnamese', 'thai', 'indian',
      'french', 'italian', 'spanish', 'german', 'greek', 'turkish',
      'mexican', 'brazilian', 'peruvian', 'cuban',
      'american', 'southern', 'cajun',
      'middle eastern', 'lebanese', 'moroccan', 'ethiopian',
      'european', 'americas', 'north', 'south',
    ];
    return cuisines.contains(cellLower);
  }
  
  String _normaliseCuisine(String cuisine) {
    // Use cuisine style names (adjectives), not country names
    // e.g., "Chinese" not "China", because it's "Chinese food" not "China food"
    final mapping = {
      'asian': null, // Too broad, will be overridden by specific
      'european': null,
      'americas': null,
      'north': 'North American',
      'south': 'South American',
      'chinese': 'Chinese',
      'china': 'Chinese',
      'japanese': 'Japanese',
      'japan': 'Japanese',
      'korean': 'Korean',
      'korea': 'Korean',
      'vietnamese': 'Vietnamese',
      'vietnam': 'Vietnamese',
      'thai': 'Thai',
      'thailand': 'Thai',
      'indian': 'Indian',
      'india': 'Indian',
      'french': 'French',
      'france': 'French',
      'italian': 'Italian',
      'italy': 'Italian',
      'spanish': 'Spanish',
      'spain': 'Spanish',
      'german': 'German',
      'germany': 'German',
      'greek': 'Greek',
      'greece': 'Greek',
      'turkish': 'Turkish',
      'turkey': 'Turkish',
      'mexican': 'Mexican',
      'mexico': 'Mexican',
      'brazilian': 'Brazilian',
      'brazil': 'Brazilian',
      'peruvian': 'Peruvian',
      'peru': 'Peruvian',
      'cuban': 'Cuban',
      'cuba': 'Cuban',
      'american': 'American',
      'usa': 'American',
      'southern': 'Southern',
      'cajun': 'Cajun',
      'lebanese': 'Lebanese',
      'lebanon': 'Lebanese',
      'moroccan': 'Moroccan',
      'morocco': 'Moroccan',
      'ethiopian': 'Ethiopian',
      'ethiopia': 'Ethiopian',
    };
    
    final normalised = mapping[cuisine.toLowerCase()];
    return normalised ?? cuisine;
  }
  
  String _normaliseCourse(String course) {
    final mapping = {
      'main': 'Mains',
      'mains': 'Mains',
      'app': 'Apps',
      'apps': 'Apps',
      'appetizer': 'Apps',
      'appetizers': 'Apps',
      'appetiser': 'Apps',
      'soup': 'Soup',
      'soups': 'Soup',
      'salad': 'Salad',
      'salads': 'Salad',
      'side': 'Sides',
      'sides': 'Sides',
      'dessert': 'Desserts',
      'desserts': 'Desserts',
      'bread': 'Breads',
      'breads': 'Breads',
      'brunch': 'Brunch',
      'breakfast': 'Brunch',
      'sauce': 'Sauces',
      'sauces': 'Sauces',
      'drink': 'Drinks',
      'drinks': 'Drinks',
      'beverages': 'Drinks',
      'pizza': 'Pizzas',
      'pizzas': 'Pizzas',
      'rub': 'Rubs',
      'rubs': 'Rubs',
      'not meat': 'Veg\'n',
      'not-meat': 'Veg\'n',
      'vegetarian': 'Veg\'n',
      'vegan': 'Veg\'n',
      'veg\'n': 'Veg\'n',
      'veg*n': 'Veg\'n',
      'sandwich': 'Sandwiches',
      'sandwiches': 'Sandwiches',
      'sandwhich': 'Sandwiches',
      'sandwhiches': 'Sandwiches',
      'cheese': 'Cheese',
      'pickles': 'Pickles',
      'pickles/brines': 'Pickles',
      'brines': 'Pickles',
      'smoking': 'Smoking',
      'smoked': 'Smoking',
      'molecular': 'Modernist',
      'modernist': 'Modernist',
    };
    
    return mapping[course.toLowerCase()] ?? course;
  }
}

// Provider
final csvImporterProvider = Provider<CsvRecipeImporter>((ref) {
  return CsvRecipeImporter();
});
