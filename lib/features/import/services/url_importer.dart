import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';

import '../../features/recipes/models/recipe.dart';

/// Service to import recipes from URLs
class UrlRecipeImporter {
  static const _uuid = Uuid();

  /// Import a recipe from a URL
  /// Supports JSON-LD schema.org Recipe format and common recipe sites
  Future<Recipe?> importFromUrl(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Memoix Recipe App/1.0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch URL: ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);

      // Try to find JSON-LD structured data first (most reliable)
      final jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
      
      for (final script in jsonLdScripts) {
        try {
          final data = jsonDecode(script.text);
          final recipe = _parseJsonLd(data, url);
          if (recipe != null) return recipe;
        } catch (_) {
          continue;
        }
      }

      // Fallback: try to parse from HTML structure
      return _parseFromHtml(document, url);
    } catch (e) {
      throw Exception('Failed to import recipe from URL: $e');
    }
  }

  /// Parse JSON-LD structured data
  Recipe? _parseJsonLd(dynamic data, String sourceUrl) {
    // Handle @graph structure
    if (data is Map && data['@graph'] != null) {
      final graph = data['@graph'] as List;
      for (final item in graph) {
        final recipe = _parseJsonLd(item, sourceUrl);
        if (recipe != null) return recipe;
      }
      return null;
    }

    // Handle array of items
    if (data is List) {
      for (final item in data) {
        final recipe = _parseJsonLd(item, sourceUrl);
        if (recipe != null) return recipe;
      }
      return null;
    }

    // Check if this is a Recipe type
    if (data is! Map) return null;
    
    final type = data['@type'];
    final isRecipe = type == 'Recipe' || 
                     (type is List && type.contains('Recipe'));
    
    if (!isRecipe) return null;

    // Parse the recipe data
    return Recipe.create(
      uuid: _uuid.v4(),
      name: _parseString(data['name']) ?? 'Untitled Recipe',
      course: _guessCourse(data),
      cuisine: _parseString(data['recipeCuisine']),
      serves: _parseYield(data['recipeYield']),
      time: _parseTime(data),
      ingredients: _parseIngredients(data['recipeIngredient']),
      directions: _parseInstructions(data['recipeInstructions']),
      notes: _parseString(data['description']),
      imageUrl: _parseImage(data['image']),
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
    );
  }

  String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim();
    if (value is List && value.isNotEmpty) return value.first.toString().trim();
    return value.toString().trim();
  }

  String? _parseYield(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num) return value.toString();
    if (value is List && value.isNotEmpty) return value.first.toString();
    return null;
  }

  String? _parseTime(Map data) {
    final times = <String>[];
    
    if (data['prepTime'] != null) {
      final prep = _parseDuration(data['prepTime']);
      if (prep != null) times.add('Prep: $prep');
    }
    
    if (data['cookTime'] != null) {
      final cook = _parseDuration(data['cookTime']);
      if (cook != null) times.add('Cook: $cook');
    }
    
    if (data['totalTime'] != null) {
      final total = _parseDuration(data['totalTime']);
      if (total != null) {
        if (times.isEmpty) return total;
        times.add('Total: $total');
      }
    }
    
    return times.isEmpty ? null : times.join(', ');
  }

  String? _parseDuration(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    
    // Parse ISO 8601 duration (e.g., PT30M, PT1H30M)
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(str);
    
    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
      
      if (hours > 0 && minutes > 0) {
        return '$hours hr $minutes min';
      } else if (hours > 0) {
        return '$hours hr';
      } else if (minutes > 0) {
        return '$minutes min';
      }
    }
    
    return str;
  }

  List<Ingredient> _parseIngredients(dynamic value) {
    if (value == null) return [];
    
    List<String> items;
    if (value is String) {
      items = [value];
    } else if (value is List) {
      items = value.map((e) => e.toString()).toList();
    } else {
      return [];
    }

    return items.map((item) {
      // Basic parsing - could be enhanced with NLP
      return Ingredient.create(name: item.trim());
    }).toList();
  }

  List<String> _parseInstructions(dynamic value) {
    if (value == null) return [];
    
    if (value is String) {
      return value.split(RegExp(r'\n+|\. (?=[A-Z])')).where((s) => s.trim().isNotEmpty).toList();
    }
    
    if (value is List) {
      return value.map((item) {
        if (item is String) return item.trim();
        if (item is Map) {
          return _parseString(item['text']) ?? _parseString(item['name']) ?? '';
        }
        return item.toString().trim();
      }).where((s) => s.isNotEmpty).toList();
    }
    
    return [];
  }

  String? _parseImage(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List && value.isNotEmpty) {
      return _parseImage(value.first);
    }
    if (value is Map) {
      return _parseString(value['url']) ?? _parseString(value['contentUrl']);
    }
    return null;
  }

  String _guessCourse(Map data) {
    final category = _parseString(data['recipeCategory'])?.toLowerCase();
    final keywords = _parseString(data['keywords'])?.toLowerCase() ?? '';
    
    if (category != null) {
      if (category.contains('dessert') || category.contains('sweet')) return 'Desserts';
      if (category.contains('appetizer') || category.contains('starter')) return 'Apps';
      if (category.contains('soup')) return 'Soups';
      if (category.contains('salad') || category.contains('side')) return 'Sides';
      if (category.contains('bread')) return 'Breads';
      if (category.contains('breakfast') || category.contains('brunch')) return 'Brunch';
      if (category.contains('main') || category.contains('dinner') || category.contains('entrée')) return 'Mains';
      if (category.contains('sauce') || category.contains('dressing')) return 'Sauces';
      if (category.contains('pizza')) return 'Pizzas';
    }
    
    if (keywords.contains('vegetarian') || keywords.contains('vegan')) return 'Not Meat';
    
    return 'Mains'; // Default
  }

  /// Fallback HTML parsing for sites without JSON-LD
  Recipe? _parseFromHtml(dynamic document, String sourceUrl) {
    // Try common selectors for recipe sites
    final title = document.querySelector('h1')?.text?.trim() ?? 
                  document.querySelector('.recipe-title')?.text?.trim() ??
                  document.querySelector('[itemprop="name"]')?.text?.trim() ??
                  'Untitled Recipe';

    final ingredientElements = document.querySelectorAll(
      '.ingredients li, .ingredient-list li, [itemprop="recipeIngredient"], .wprm-recipe-ingredient'
    );
    
    final ingredients = ingredientElements
        .map((e) => Ingredient.create(name: e.text.trim()))
        .where((i) => i.name.isNotEmpty)
        .toList();

    final instructionElements = document.querySelectorAll(
      '.instructions li, .directions li, [itemprop="recipeInstructions"] li, .wprm-recipe-instruction'
    );
    
    final directions = instructionElements
        .map((e) => e.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (ingredients.isEmpty && directions.isEmpty) {
      return null;
    }

    return Recipe.create(
      uuid: _uuid.v4(),
      name: title,
      course: 'Mains',
      ingredients: ingredients,
      directions: directions,
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
    );
  }
}
