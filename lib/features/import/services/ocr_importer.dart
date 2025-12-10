import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../recipes/models/recipe.dart';

/// Service to import recipes from photos using OCR
class OcrRecipeImporter {
  static const _uuid = Uuid();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick an image and extract recipe text
  Future<OcrResult> scanFromCamera() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image == null) {
      return OcrResult.cancelled();
    }
    return _processImage(image.path);
  }

  /// Pick an image from gallery and extract recipe text
  Future<OcrResult> scanFromGallery() async {
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

      return OcrResult.success(
        rawText: recognizedText.text,
        blocks: recognizedText.blocks.map((b) => b.text).toList(),
        recipe: _parseRecipeFromText(recognizedText.text),
      );
    } catch (e) {
      return OcrResult.error('Failed to process image: $e');
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

  OcrResult._({
    required this.success,
    this.cancelled = false,
    this.error,
    this.rawText,
    this.blocks,
    this.recipe,
  });

  factory OcrResult.success({
    required String rawText,
    required List<String> blocks,
    Recipe? recipe,
  }) {
    return OcrResult._(
      success: true,
      rawText: rawText,
      blocks: blocks,
      recipe: recipe,
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
