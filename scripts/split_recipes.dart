#!/usr/bin/env dart
/// Utility script to split a recipe export JSON into course-based files
/// 
/// Usage: dart run scripts/split_recipes.dart path/to/export.json
/// 
/// This will read the exported recipes and split them into the appropriate
/// JSON files in the recipes/ folder based on their course.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run scripts/split_recipes.dart path/to/export.json');
    exit(1);
  }

  final inputFile = File(args[0]);
  if (!await inputFile.exists()) {
    print('Error: File not found: ${args[0]}');
    exit(1);
  }

  final content = await inputFile.readAsString();
  final data = jsonDecode(content);
  
  // Handle both formats: {"recipes": [...]} or just [...]
  final List<dynamic> recipes = data is List ? data : (data['recipes'] ?? []);
  
  print('Found ${recipes.length} recipes');

  // Group recipes by course
  final Map<String, List<Map<String, dynamic>>> byCourse = {};
  
  for (final recipe in recipes) {
    final course = _normaliseCourse(recipe['course'] as String? ?? 'mains');
    byCourse.putIfAbsent(course, () => []);
    byCourse[course]!.add(recipe as Map<String, dynamic>);
  }

  // Write each course file
  final recipesDir = Directory('recipes');
  if (!await recipesDir.exists()) {
    await recipesDir.create(recursive: true);
  }

  for (final entry in byCourse.entries) {
    final filename = '${entry.key}.json';
    final file = File('recipes/$filename');
    final output = jsonEncode({
      'recipes': entry.value,
    });
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonDecode(output)));
    print('Wrote ${entry.value.length} recipes to $filename');
  }

  // Update index.json
  final indexFile = File('recipes/index.json');
  final existingFiles = byCourse.keys.map((c) => '$c.json').toList()..sort();
  await indexFile.writeAsString(const JsonEncoder.withIndent('  ').convert({
    'files': existingFiles,
  }));
  print('Updated index.json');

  print('Done!');
}

String _normaliseCourse(String course) {
  final mapping = {
    'main': 'mains',
    'mains': 'mains',
    'app': 'apps',
    'apps': 'apps',
    'appetizer': 'apps',
    'appetizers': 'apps',
    'soup': 'soup',
    'soups': 'soup',
    'salad': 'salad',
    'salads': 'salad',
    'side': 'sides',
    'sides': 'sides',
    'dessert': 'desserts',
    'desserts': 'desserts',
    'bread': 'breads',
    'breads': 'breads',
    'brunch': 'brunch',
    'breakfast': 'brunch',
    'sauce': 'sauces',
    'sauces': 'sauces',
    'drink': 'drinks',
    'drinks': 'drinks',
    'pizza': 'pizzas',
    'pizzas': 'pizzas',
    'rub': 'rubs',
    'rubs': 'rubs',
    'not meat': 'vegan',
    'not-meat': 'vegan',
    'vegetarian': 'vegan',
    'vegan': 'vegan',
    'veg*n': 'vegan',
    'sandwich': 'sandwiches',
    'sandwiches': 'sandwiches',
    'cheese': 'cheese',
    'pickles': 'pickles',
    'pickles/brines': 'pickles',
    'brines': 'pickles',
    'smoking': 'smoking',
    'smoked': 'smoking',
    'molecular': 'molecular',
    'scratch': 'scratch',
  };
  
  return mapping[course.toLowerCase()] ?? course.toLowerCase();
}
