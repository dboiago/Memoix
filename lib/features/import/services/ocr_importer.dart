import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../recipes/models/recipe.dart';
import '../models/recipe_import_result.dart';

/// Service to import recipes from photos using OCR
class OcrRecipeImporter {
  static const _uuid = Uuid();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick an image and extract recipe text
  Future<OcrResult> scanFromCamera() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return OcrResult.error('OCR is not supported on desktop platforms.');
    }
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image == null) {
      return OcrResult.cancelled();
    }
    return _processImage(image.path);
  }

  /// Pick an image from gallery and extract recipe text
  Future<OcrResult> scanFromGallery() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return OcrResult.error('OCR is not supported on desktop platforms.');
    }
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return OcrResult.cancelled();
    }
    return _processImage(image.path);
  }

  /// Process an image file and extract text
  Future<OcrResult> _processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (recognizedText.text.isEmpty) {
        return OcrResult.error('No text found in image');
      }

      final blocks = recognizedText.blocks.map((b) => b.text).toList();
      final importResult = parseWithConfidence(recognizedText.text, blocks);

      return OcrResult.success(
        rawText: recognizedText.text,
        blocks: blocks,
        recipe: _parseRecipeFromText(recognizedText.text),
        importResult: importResult,
      );
    } catch (e) {
      return OcrResult.error('Failed to process image: $e');
    }
  }

  /// Extract text from an image file (simple text extraction)
  Future<String> extractTextFromImage(String imagePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      throw Exception('OCR is not supported on desktop platforms.');
    }
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      throw Exception('Failed to extract text from image: $e');
    }
  }

  /// Attempt to parse structured recipe from raw OCR text
  Recipe? _parseRecipeFromText(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    if (lines.isEmpty) return null;

    // First non-empty line is usually the title
    final name = lines.first;
    
    // Try to identify ingredients (lines with amounts/measurements)
    final ingredientPattern = RegExp(
      r'^[\d½¼¾⅓⅔⅛]+\s*(?:cup|cups|tbsp|tsp|oz|lb|g|kg|ml|l|pound|ounce|teaspoon|tablespoon|c\.|t\.)?s?\s+',
      caseSensitive: false,
    );
    
    final ingredients = <Ingredient>[];
    final directions = <String>[];
    bool inIngredients = false;
    bool inDirections = false;
    
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();
      
      // Check for section headers
      if (lowerLine.contains('ingredient')) {
        inIngredients = true;
        inDirections = false;
        continue;
      }
      if (lowerLine.contains('direction') || 
          lowerLine.contains('instruction') || 
          lowerLine.contains('method') ||
          lowerLine.contains('steps')) {
        inIngredients = false;
        inDirections = true;
        continue;
      }
      
      // Parse based on context or pattern
      if (inDirections || RegExp(r'^\d+[\.\)]\s').hasMatch(line)) {
        // Looks like a numbered step
        directions.add(line.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), ''));
      } else if (inIngredients || ingredientPattern.hasMatch(line)) {
        ingredients.add(Ingredient.create(name: line));
      } else if (directions.isNotEmpty) {
        // Continue previous direction if no clear pattern
        if (directions.last.length < 100) {
          directions[directions.length - 1] += ' $line';
        } else {
          directions.add(line);
        }
      } else if (ingredients.isEmpty && directions.isEmpty) {
        // Ambiguous - add as ingredient for now
        ingredients.add(Ingredient.create(name: line));
      }
    }

    return Recipe.create(
      uuid: _uuid.v4(),
      name: name,
      course: 'Mains', // User can categorize later
      ingredients: ingredients,
      directions: directions,
      source: RecipeSource.ocr,
    );
  }

  /// Parse OCR text into RecipeImportResult with confidence scoring
  RecipeImportResult parseWithConfidence(String rawText, List<String> blocks) {
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    if (lines.isEmpty) {
      return RecipeImportResult(
        rawText: rawText,
        textBlocks: blocks,
        source: RecipeSource.ocr,
      );
    }

    // First non-empty line is usually the title - but low confidence for OCR
    String? name;
    double nameConfidence = 0.0;
    
    if (lines.isNotEmpty) {
      name = lines.first;
      // Higher confidence if it looks like a title (not too long, no amounts)
      final looksLikeTitle = name.length < 50 && 
          !RegExp(r'^\d+').hasMatch(name) &&
          !name.toLowerCase().contains('ingredient');
      nameConfidence = looksLikeTitle ? 0.6 : 0.3;
    }

    // Try to identify ingredients vs directions
    final ingredientPattern = RegExp(
      r'^[\d½¼¾⅓⅔⅛]+\s*(?:cup|cups|tbsp|tsp|oz|lb|g|kg|ml|l|pound|ounce|teaspoon|tablespoon|c\.|t\.)?s?\s+',
      caseSensitive: false,
    );

    final rawIngredients = <RawIngredientData>[];
    final rawDirections = <String>[];
    final ingredients = <Ingredient>[];
    final directions = <String>[];
    
    bool inIngredients = false;
    bool inDirections = false;
    bool foundIngredientHeader = false;
    bool foundDirectionHeader = false;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();

      // Check for section headers
      if (lowerLine.contains('ingredient')) {
        inIngredients = true;
        inDirections = false;
        foundIngredientHeader = true;
        continue;
      }
      if (lowerLine.contains('direction') || 
          lowerLine.contains('instruction') || 
          lowerLine.contains('method') ||
          lowerLine.contains('steps')) {
        inIngredients = false;
        inDirections = true;
        foundDirectionHeader = true;
        continue;
      }

      // Classify the line
      final isNumberedStep = RegExp(r'^\d+[\.\)]\s').hasMatch(line);
      final hasAmount = ingredientPattern.hasMatch(line);

      if (inDirections || isNumberedStep) {
        final cleanedStep = line.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');
        rawDirections.add(cleanedStep);
        directions.add(cleanedStep);
      } else if (inIngredients || hasAmount) {
        rawIngredients.add(RawIngredientData(
          original: line,
          name: line,
          looksLikeIngredient: hasAmount,
        ));
        ingredients.add(Ingredient.create(name: line));
      } else if (directions.isNotEmpty && !inIngredients) {
        // Continue previous direction
        if (rawDirections.last.length < 100) {
          final updated = '${rawDirections.last} $line';
          rawDirections[rawDirections.length - 1] = updated;
          directions[directions.length - 1] = updated;
        } else {
          rawDirections.add(line);
          directions.add(line);
        }
      } else {
        // Ambiguous - track as potential ingredient
        rawIngredients.add(RawIngredientData(
          original: line,
          name: line,
          looksLikeIngredient: false, // Uncertain
        ));
        ingredients.add(Ingredient.create(name: line));
      }
    }

    // Calculate confidence scores
    // OCR is inherently less reliable, so base scores are lower
    double ingredientsConfidence = 0.0;
    if (rawIngredients.isNotEmpty) {
      final withAmounts = rawIngredients.where((i) => i.looksLikeIngredient).length;
      ingredientsConfidence = (withAmounts / rawIngredients.length) * 0.5;
      if (foundIngredientHeader) ingredientsConfidence += 0.2;
    }

    double directionsConfidence = 0.0;
    if (rawDirections.isNotEmpty) {
      directionsConfidence = 0.4; // Base confidence
      if (foundDirectionHeader) directionsConfidence += 0.2;
      // More steps = more confidence
      if (rawDirections.length >= 3) directionsConfidence += 0.1;
    }

    return RecipeImportResult(
      name: name,
      course: 'Mains', // Always needs review for OCR
      ingredients: ingredients,
      directions: directions,
      rawText: rawText,
      textBlocks: blocks,
      rawIngredients: rawIngredients,
      rawDirections: rawDirections,
      nameConfidence: nameConfidence,
      courseConfidence: 0.2, // Very low - OCR can't detect course
      cuisineConfidence: 0.0,
      ingredientsConfidence: ingredientsConfidence,
      directionsConfidence: directionsConfidence,
      servesConfidence: 0.0,
      timeConfidence: 0.0,
      source: RecipeSource.ocr,
    );
  }

  /// Dispose resources
  void dispose() {
    _textRecognizer.close();
  }
}

/// Result of OCR scanning
class OcrResult {
  final bool success;
  final bool cancelled;
  final String? error;
  final String? rawText;
  final List<String>? blocks;
  final Recipe? recipe;
  final RecipeImportResult? importResult;

  OcrResult._({
    required this.success,
    this.cancelled = false,
    this.error,
    this.rawText,
    this.blocks,
    this.recipe,
    this.importResult,
  });

  factory OcrResult.success({
    required String rawText,
    required List<String> blocks,
    Recipe? recipe,
    RecipeImportResult? importResult,
  }) {
    return OcrResult._(
      success: true,
      rawText: rawText,
      blocks: blocks,
      recipe: recipe,
      importResult: importResult,
    );
  }

  factory OcrResult.error(String message) {
    return OcrResult._(success: false, error: message);
  }

  factory OcrResult.cancelled() {
    return OcrResult._(success: false, cancelled: true);
  }
}

// ============ PROVIDERS ============

final ocrImporterProvider = Provider<OcrRecipeImporter>((ref) {
  final importer = OcrRecipeImporter();
  ref.onDispose(() => importer.dispose());
  return importer;
});
