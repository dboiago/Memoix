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

  /// Pick multiple images and extract/merge recipe text
  Future<OcrResult> scanMultipleImages(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      return OcrResult.error('No images provided');
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return OcrResult.error('OCR is not supported on desktop platforms.');
    }

    try {
      // Extract text from all images
      final allTexts = <String>[];
      final allBlocks = <String>[];
      final imageToText = <int, String>{};

      for (int i = 0; i < imagePaths.length; i++) {
        final text = await extractTextFromImage(imagePaths[i]);
        if (text.isNotEmpty) {
          allTexts.add(text);
          imageToText[i] = text;
          allBlocks.addAll(text.split('\n'));
        }
      }

      if (allTexts.isEmpty) {
        return OcrResult.error('No text found in any images');
      }

      // Merge text intelligently
      final mergedText = _mergeMultipleTexts(allTexts);
      final importResult = parseWithConfidence(mergedText, allBlocks);
      
      // Add image paths to importResult
      importResult.imagePaths = imagePaths;

      return OcrResult.success(
        rawText: mergedText,
        blocks: allBlocks,
        recipe: _parseRecipeFromText(mergedText),
        importResult: importResult,
      );
    } catch (e) {
      return OcrResult.error('Failed to process images: $e');
    }
  }

  /// Intelligently merge text from multiple images
  String _mergeMultipleTexts(List<String> texts) {
    if (texts.isEmpty) return '';
    if (texts.length == 1) return texts.first;

    // Parse each text into sections
    final sections = <Map<String, List<String>>>[];
    for (final text in texts) {
      sections.add(_extractSections(text));
    }

    // Merge sections intelligently
    final merged = <String>[];
    
    // Add title from first image
    final firstTitle = _extractTitle(texts.first);
    if (firstTitle.isNotEmpty) {
      merged.add(firstTitle);
    }

    // Merge all ingredients from all sections
    final allIngredients = <String>[];
    for (final section in sections) {
      allIngredients.addAll(section['ingredients'] ?? []);
    }
    if (allIngredients.isNotEmpty) {
      merged.add('Ingredients');
      merged.addAll(allIngredients);
    }

    // Merge all directions from all sections
    final allDirections = <String>[];
    for (final section in sections) {
      allDirections.addAll(section['directions'] ?? []);
    }
    if (allDirections.isNotEmpty) {
      merged.add('Directions');
      merged.addAll(allDirections);
    }

    // Merge all notes
    final allNotes = <String>[];
    for (final section in sections) {
      allNotes.addAll(section['notes'] ?? []);
    }
    if (allNotes.isNotEmpty) {
      merged.add('Notes');
      merged.addAll(allNotes);
    }

    return merged.join('\n');
  }

  /// Extract sections (ingredients, directions, notes) from text
  Map<String, List<String>> _extractSections(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    final sections = <String, List<String>>{
      'ingredients': [],
      'directions': [],
      'notes': [],
      'other': [],
    };

    bool inIngredients = false;
    bool inDirections = false;
    bool inNotes = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();

      // Check for section headers
      if (lowerLine.contains('ingredient')) {
        inIngredients = true;
        inDirections = false;
        inNotes = false;
        continue;
      }
      if (lowerLine.contains('direction') || 
          lowerLine.contains('instruction') || 
          lowerLine.contains('method') ||
          lowerLine.contains('steps')) {
        inIngredients = false;
        inDirections = true;
        inNotes = false;
        continue;
      }
      if (lowerLine.contains('note') || lowerLine.contains('tip')) {
        inIngredients = false;
        inDirections = false;
        inNotes = true;
        continue;
      }

      // Add to appropriate section
      if (inIngredients) {
        sections['ingredients']!.add(line);
      } else if (inDirections) {
        sections['directions']!.add(line);
      } else if (inNotes) {
        sections['notes']!.add(line);
      } else {
        sections['other']!.add(line);
      }
    }

    return sections;
  }

  /// Extract title from text
  String _extractTitle(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return '';
    
    final firstLine = lines.first;
    // Return first line if it looks like a title (not too long, not a section header)
    if (firstLine.length < 50 && 
        !firstLine.toLowerCase().contains('ingredient') &&
        !firstLine.toLowerCase().contains('direction') &&
        !RegExp(r'^\d+').hasMatch(firstLine)) {
      return firstLine;
    }
    
    return '';
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

    // ===== PHASE 1: Extract title =====
    // Look for a short line at the start that looks like a title
    // Skip lines that look like ingredients, paragraphs, or section headers
    String? name;
    double nameConfidence = 0.0;
    int titleLineIndex = 0;
    
    for (int i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();
      
      // Skip lines that look like ingredients (start with numbers + units)
      if (RegExp(r'^[\d½¼¾⅓⅔⅛]+\s*(cup|cups|tbsp|tsp|oz|lb|g|kg|ml|l|pound|ounce|teaspoon|tablespoon)', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      
      // Skip long paragraphs (likely intro text)
      if (line.length > 80) continue;
      
      // Skip lines that look like section headers
      if (lowerLine.contains('ingredient') || lowerLine.contains('direction') || 
          lowerLine.contains('instruction') || lowerLine.contains('method')) {
        continue;
      }
      
      // Good title candidate: short, no amounts, at the start
      if (line.length >= 3 && line.length < 60 && !RegExp(r'^\d+').hasMatch(line)) {
        name = line;
        titleLineIndex = i;
        nameConfidence = 0.7;
        break;
      }
    }
    
    // Fallback to first line if no good candidate found
    if (name == null && lines.isNotEmpty) {
      name = lines.first;
      nameConfidence = 0.3;
    }

    // ===== PHASE 2: Extract serves from "Makes X" or "Serves X" patterns =====
    String? serves;
    double servesConfidence = 0.0;
    final servesPatterns = [
      RegExp(r'\b(?:makes|yields?)\s+(\d+)\b', caseSensitive: false),
      RegExp(r'\b(?:serves?)\s+(\d+)\b', caseSensitive: false),
      RegExp(r'\b(\d+)\s+(?:servings?|portions?)\b', caseSensitive: false),
    ];
    
    for (final line in lines) {
      for (final pattern in servesPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          serves = match.group(1);
          servesConfidence = 0.8;
          break;
        }
      }
      if (serves != null) break;
    }

    // ===== PHASE 3: Detect course from context clues =====
    String course = 'Mains';
    double courseConfidence = 0.2;
    final allText = rawText.toLowerCase();
    
    // Dessert indicators
    final dessertKeywords = ['cupcake', 'cake', 'cookie', 'brownie', 'frosting', 
        'icing', 'sugar', 'vanilla extract', 'chocolate', 'dessert', 'sweet',
        'muffin', 'pie', 'tart', 'pastry', 'baking powder', 'baking soda'];
    final dessertCount = dessertKeywords.where((k) => allText.contains(k)).length;
    
    // Drink indicators
    final drinkKeywords = ['cocktail', 'shake', 'smoothie', 'juice', 'vodka', 
        'gin', 'rum', 'whiskey', 'liqueur', 'oz vodka', 'oz gin', 'garnish with'];
    final drinkCount = drinkKeywords.where((k) => allText.contains(k)).length;
    
    // Appetizer indicators
    final appKeywords = ['appetizer', 'starter', 'dip', 'finger food', 'hors d\'oeuvre'];
    final appCount = appKeywords.where((k) => allText.contains(k)).length;
    
    // Side indicators
    final sideKeywords = ['side dish', 'accompaniment', 'serve alongside'];
    final sideCount = sideKeywords.where((k) => allText.contains(k)).length;
    
    // Determine course based on keyword density
    if (dessertCount >= 2) {
      course = 'Desserts';
      courseConfidence = 0.6 + (dessertCount * 0.05).clamp(0.0, 0.2);
    } else if (drinkCount >= 2) {
      course = 'Drinks';
      courseConfidence = 0.6 + (drinkCount * 0.05).clamp(0.0, 0.2);
    } else if (appCount >= 1) {
      course = 'Apps';
      courseConfidence = 0.5;
    } else if (sideCount >= 1) {
      course = 'Sides';
      courseConfidence = 0.5;
    }

    // ===== PHASE 4: Identify intro paragraphs as notes =====
    String? notes;
    final introLines = <String>[];
    int contentStartIndex = titleLineIndex + 1;
    
    // Look for intro paragraphs after title - long sentences that aren't ingredients
    for (int i = titleLineIndex + 1; i < lines.length && i < titleLineIndex + 6; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();
      
      // Stop if we hit an ingredient-like line or section header
      if (RegExp(r'^[\d½¼¾⅓⅔⅛]+\s*(cup|cups|tbsp|tsp|oz|lb|g|kg|ml|l|pound|ounce|teaspoon|tablespoon)', caseSensitive: false).hasMatch(line)) {
        break;
      }
      if (lowerLine.contains('ingredient') || lowerLine.contains('direction')) {
        break;
      }
      
      // Long prose lines are likely intro/notes
      if (line.length > 60 && line.contains(' ')) {
        introLines.add(line);
        contentStartIndex = i + 1;
      } else {
        // Short line after intro - might be "Makes 24" etc, check and skip
        if (servesPatterns.any((p) => p.hasMatch(line))) {
          contentStartIndex = i + 1;
          continue;
        }
        break;
      }
    }
    
    if (introLines.isNotEmpty) {
      notes = introLines.join(' ');
    }

    // ===== PHASE 5: Parse ingredients and directions =====
    // Pattern for ingredient lines: starts with amount + unit
    final ingredientPattern = RegExp(
      r'^([\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:\s*[\d½¼¾⅓⅔⅛⅜⅝⅞/]+)?)\s*(cups?|tbsps?|tsps?|oz|lbs?|g|kg|ml|l|pounds?|ounces?|teaspoons?|tablespoons?|c\.|t\.)\s+(.+)',
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
    
    // Track paragraph-style directions to split by sentence later
    final paragraphDirections = <String>[];
    
    // Pre-process lines to handle two-column layouts
    // OCR often merges "1 CUP FLOUR    Preheat oven to 350°F" into one line
    final processedLines = <String>[];
    for (int i = contentStartIndex; i < lines.length; i++) {
      final line = lines[i];
      
      // Check if line looks like merged two-column text:
      // - Starts with amount+unit (ingredient pattern)
      // - Contains action verb later in the line
      final startsWithIngredient = ingredientPattern.hasMatch(line);
      final hasActionVerb = RegExp(
        r'\b(preheat|mix|stir|add|combine|bake|cook|heat|pour|whisk|fold|let|transfer|cut|spread|frost|store|line|place|remove|cool|serve)\b',
        caseSensitive: false,
      ).hasMatch(line);
      
      if (startsWithIngredient && hasActionVerb && line.length > 50) {
        // Try to find where ingredient ends and direction begins
        // Look for patterns like: multiple spaces, or a capital letter after ingredient
        final splitMatch = RegExp(
          r'^([\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:\s*/\s*\d+)?(?:\s*[\d½¼¾⅓⅔⅛⅜⅝⅞]+)?\s*(?:cups?|tbsps?|tsps?|oz|lbs?|g|kg|ml|l|pounds?|ounces?|teaspoons?|tablespoons?|c\.|t\.)?\s+[A-Za-z][A-Za-z\s\-,()]+?)(\s{2,}|\s+(?=[A-Z][a-z]))(.+)',
          caseSensitive: false,
        ).firstMatch(line);
        
        if (splitMatch != null) {
          final ingredientPart = splitMatch.group(1)?.trim();
          final directionPart = splitMatch.group(3)?.trim();
          if (ingredientPart != null && ingredientPart.isNotEmpty) {
            processedLines.add(ingredientPart);
          }
          if (directionPart != null && directionPart.isNotEmpty) {
            processedLines.add(directionPart);
          }
          continue;
        }
      }
      processedLines.add(line);
    }

    for (final line in processedLines) {
      final lowerLine = line.toLowerCase();
      
      // Skip serves lines
      if (servesPatterns.any((p) => p.hasMatch(line))) {
        continue;
      }

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

      // Check if line looks like an ingredient
      final ingredientMatch = ingredientPattern.firstMatch(line);
      final isNumberedStep = RegExp(r'^\d+[\.\)]\s').hasMatch(line);
      
      // Long prose lines (>80 chars with multiple sentences) are likely directions
      final isLongProse = line.length > 80 && RegExp(r'\.\s+[A-Z]').hasMatch(line);

      if (isNumberedStep) {
        // Numbered step - definitely a direction
        final cleanedStep = line.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');
        rawDirections.add(cleanedStep);
        directions.add(cleanedStep);
        inDirections = true;
        inIngredients = false;
      } else if (isLongProse) {
        // Long paragraph - collect for sentence splitting
        paragraphDirections.add(line);
        inDirections = true;
        inIngredients = false;
      } else if (ingredientMatch != null) {
        // Matched ingredient pattern - parse structured data
        final parsed = _parseIngredientLine(line);
        rawIngredients.add(parsed);
        ingredients.add(Ingredient.create(
          name: parsed.name,
          amount: parsed.amount,
          unit: parsed.unit,
        ));
        inIngredients = true;
        inDirections = false;
      } else if (inDirections) {
        // Continue in directions mode
        if (rawDirections.isNotEmpty && rawDirections.last.length < 100) {
          final updated = '${rawDirections.last} $line';
          rawDirections[rawDirections.length - 1] = updated;
          directions[directions.length - 1] = updated;
        } else {
          rawDirections.add(line);
          directions.add(line);
        }
      } else if (inIngredients) {
        // In ingredients section but no pattern match - still try to parse
        final parsed = _parseIngredientLine(line);
        rawIngredients.add(parsed);
        ingredients.add(Ingredient.create(
          name: parsed.name,
          amount: parsed.amount,
          unit: parsed.unit,
        ));
      } else {
        // Ambiguous line - use heuristics
        // Short lines with food words are probably ingredients
        // Long lines with verbs are probably directions
        final hasActionVerb = RegExp(r'\b(preheat|mix|stir|add|combine|bake|cook|heat|pour|whisk|fold|let|transfer|cut|spread|frost|store)\b', caseSensitive: false).hasMatch(lowerLine);
        
        if (hasActionVerb && line.length > 40) {
          paragraphDirections.add(line);
        } else if (line.length < 60) {
          // Assume short lines without action verbs are ingredients
          final parsed = _parseIngredientLine(line);
          rawIngredients.add(RawIngredientData(
            original: line,
            name: parsed.name,
            amount: parsed.amount,
            unit: parsed.unit,
            bakerPercent: parsed.bakerPercent,
            looksLikeIngredient: parsed.amount != null,
          ));
          ingredients.add(Ingredient.create(
            name: parsed.name,
            amount: parsed.amount,
            unit: parsed.unit,
          ));
        } else {
          paragraphDirections.add(line);
        }
      }
    }
    
    // ===== PHASE 6: Split paragraph directions into sentences =====
    if (paragraphDirections.isNotEmpty) {
      final fullText = paragraphDirections.join(' ');
      // Split on sentence boundaries: period followed by space and capital letter
      final sentences = fullText.split(RegExp(r'(?<=\.)\s+(?=[A-Z])'));
      
      for (final sentence in sentences) {
        final trimmed = sentence.trim();
        if (trimmed.isNotEmpty && trimmed.length > 10) {
          rawDirections.add(trimmed);
          directions.add(trimmed);
        }
      }
    }

    // ===== PHASE 7: Calculate confidence scores =====
    double ingredientsConfidence = 0.0;
    if (rawIngredients.isNotEmpty) {
      final withAmounts = rawIngredients.where((i) => i.looksLikeIngredient).length;
      ingredientsConfidence = (withAmounts / rawIngredients.length) * 0.6;
      if (foundIngredientHeader) ingredientsConfidence += 0.2;
    }

    double directionsConfidence = 0.0;
    if (rawDirections.isNotEmpty) {
      directionsConfidence = 0.4;
      if (foundDirectionHeader) directionsConfidence += 0.2;
      if (rawDirections.length >= 3) directionsConfidence += 0.1;
    }

    return RecipeImportResult(
      name: name,
      course: course,
      serves: serves,
      notes: notes,
      ingredients: ingredients,
      directions: directions,
      rawText: rawText,
      textBlocks: blocks,
      rawIngredients: rawIngredients,
      rawDirections: rawDirections,
      nameConfidence: nameConfidence,
      courseConfidence: courseConfidence,
      cuisineConfidence: 0.0,
      ingredientsConfidence: ingredientsConfidence,
      directionsConfidence: directionsConfidence,
      servesConfidence: servesConfidence,
      timeConfidence: 0.0,
      source: RecipeSource.ocr,
    );
  }

  /// Parse an ingredient line into structured data
  /// Handles formats like:
  /// - "1 CUP BROWN RICE FLOUR"
  /// - "½ cup potato starch"  
  /// - "1½ CUPS AGAVE NECTAR"
  /// - Baker's percentage: "All-Purpose Flour, 100% – 600g (4 1/2 Cups)"
  RawIngredientData _parseIngredientLine(String line) {
    // Try baker's percentage format first: "Name, XX% – amount (alt amount)"
    final bakerMatch = RegExp(
      r'^([^,]+),\s*([\d.]+)%\s*[–—-]\s*(\d+\s*(?:g|kg|ml|l|oz|lb)?)\s*(?:\(([^)]+)\))?',
      caseSensitive: false,
    ).firstMatch(line);
    
    if (bakerMatch != null) {
      return RawIngredientData(
        original: line,
        name: bakerMatch.group(1)?.trim() ?? line,
        bakerPercent: '${bakerMatch.group(2)}%',
        amount: bakerMatch.group(3)?.trim(),
        preparation: bakerMatch.group(4)?.trim(),
        looksLikeIngredient: true,
      );
    }
    
    // Try standard format: "amount unit name" (case insensitive)
    // Supports: 1 CUP, 1/2 cup, ½ cup, 1½ cups, etc.
    final standardMatch = RegExp(
      r'^([\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:\s*/\s*\d+)?(?:\s*[\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:/\d+)?)?)\s*(cups?|tbsps?|tsps?|oz|lbs?|g|kg|ml|l|pounds?|ounces?|teaspoons?|tablespoons?|c\.|t\.)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(line);
    
    if (standardMatch != null) {
      return RawIngredientData(
        original: line,
        amount: standardMatch.group(1)?.trim(),
        unit: _normalizeUnit(standardMatch.group(2)?.trim()),
        name: _cleanIngredientName(standardMatch.group(3)?.trim() ?? line),
        looksLikeIngredient: true,
      );
    }
    
    // Try format without explicit unit but with amount: "2 eggs", "3 cloves garlic"
    // Also handles cases where OCR might have weird spacing
    final simpleMatch = RegExp(
      r'^([\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:\s*/\s*\d+)?(?:\s*[\d½¼¾⅓⅔⅛⅜⅝⅞]+)?)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(line);
    
    if (simpleMatch != null) {
      var name = simpleMatch.group(2)?.trim() ?? line;
      String? unit;
      
      // Check if the name starts with a unit word that wasn't captured by standardMatch
      // This handles cases like "1 CUP COCONUT OIL" where spacing confused the parser
      final unitAtStartMatch = RegExp(
        r'^(cups?|tbsps?|tsps?|oz|lbs?|g|kg|ml|l|pounds?|ounces?|teaspoons?|tablespoons?|c\.|t\.)\s+(.+)',
        caseSensitive: false,
      ).firstMatch(name);
      
      if (unitAtStartMatch != null) {
        unit = _normalizeUnit(unitAtStartMatch.group(1)?.trim());
        name = unitAtStartMatch.group(2)?.trim() ?? name;
      }
      
      // Only count as ingredient if name looks like food (not a direction)
      final looksLikeFood = !RegExp(r'\b(preheat|bake|cook|stir|mix|add|pour|let|until|minutes?|degrees?|°)\b', caseSensitive: false).hasMatch(name);
      return RawIngredientData(
        original: line,
        amount: simpleMatch.group(1)?.trim(),
        unit: unit,
        name: _cleanIngredientName(name),
        looksLikeIngredient: looksLikeFood && (unit != null || name.length < 40),
      );
    }
    
    // Fallback - just use the line as name
    return RawIngredientData(
      original: line,
      name: _cleanIngredientName(line),
      looksLikeIngredient: false,
    );
  }
  
  /// Normalize unit abbreviations to standard form
  String? _normalizeUnit(String? unit) {
    if (unit == null) return null;
    final lower = unit.toLowerCase();
    
    // Map to standard abbreviations
    const unitMap = {
      'cup': 'cup',
      'cups': 'cup',
      'c.': 'cup',
      'tbsp': 'tbsp',
      'tbsps': 'tbsp',
      'tablespoon': 'tbsp',
      'tablespoons': 'tbsp',
      'tsp': 'tsp',
      'tsps': 'tsp',
      'teaspoon': 'tsp',
      'teaspoons': 'tsp',
      't.': 'tsp',
      'oz': 'oz',
      'ounce': 'oz',
      'ounces': 'oz',
      'lb': 'lb',
      'lbs': 'lb',
      'pound': 'lb',
      'pounds': 'lb',
      'g': 'g',
      'kg': 'kg',
      'ml': 'ml',
      'l': 'L',
    };
    
    return unitMap[lower] ?? unit;
  }
  
  /// Clean ingredient name (remove trailing punctuation, normalize case)
  String _cleanIngredientName(String name) {
    var cleaned = name.trim();
    // Remove trailing punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[,;:]+$'), '');
    // Convert ALL CAPS to Title Case
    if (cleaned == cleaned.toUpperCase() && cleaned.length > 2) {
      cleaned = cleaned.split(' ').map((word) {
        if (word.isEmpty) return word;
        // Keep short words lowercase (articles, prepositions)
        if (word.length <= 2 && !RegExp(r'^\d').hasMatch(word)) {
          return word.toLowerCase();
        }
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }
    return cleaned;
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
