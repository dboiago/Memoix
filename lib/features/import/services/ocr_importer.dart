import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/text_normalizer.dart';
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
    // Pre-process raw text to fix common OCR artifacts
    final cleanedText = _fixOcrArtifacts(rawText);
    final lines = cleanedText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    if (lines.isEmpty) {
      return RecipeImportResult(
        rawText: rawText,
        textBlocks: blocks,
        source: RecipeSource.ocr,
      );
    }

    // ===== PHASE 1: Extract title =====
    // Look for short lines at the start that look like a title
    // May need to combine multiple short lines (e.g., "healthy" + "hostess")
    String? name;
    double nameConfidence = 0.0;
    int titleLineIndex = 0;
    final titleParts = <String>[];
    
    for (int i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();
      
      // Skip lines that look like ingredients (start with numbers + units)
      if (RegExp(r'^[\d½¼¾⅓⅔⅛v/]+\s*(cup|cups|tbsp|tsp|oz|lb|g|kg|ml|l|pound|ounce|teaspoon|tablespoon)', caseSensitive: false).hasMatch(line)) {
        break; // Hit ingredients, stop looking for title
      }
      
      // Skip long paragraphs (likely intro text)
      if (line.length > 80) {
        if (titleParts.isNotEmpty) break; // Already have title parts
        continue;
      }
      
      // Skip lines that look like section headers
      if (lowerLine.contains('ingredient') || lowerLine.contains('direction') || 
          lowerLine.contains('instruction') || lowerLine.contains('method')) {
        break;
      }
      
      // Skip "Makes X" lines
      if (RegExp(r'\b(?:makes|yields?|serves?)\s+\d+', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      
      // Short line (under 40 chars) without amounts could be title or title part
      if (line.length >= 2 && line.length < 40 && !RegExp(r'^\d+').hasMatch(line)) {
        titleParts.add(line);
        titleLineIndex = i;
        // If we have two short lines in a row, they might form the title
        if (titleParts.length >= 2) break;
      } else if (titleParts.isNotEmpty) {
        // Hit a non-title line after collecting parts
        break;
      }
    }
    
    // Combine title parts
    if (titleParts.isNotEmpty) {
      name = titleParts.join(' ');
      nameConfidence = titleParts.length == 1 ? 0.7 : 0.6;
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
      RegExp(r'\bmakes\s+(\d+)\b', caseSensitive: false),
      RegExp(r'\byields?\s+(\d+)\b', caseSensitive: false),
      RegExp(r'\bserves?\s+(\d+)\b', caseSensitive: false),
      RegExp(r'\b(\d+)\s+servings?\b', caseSensitive: false),
      RegExp(r'\b(\d+)\s+portions?\b', caseSensitive: false),
    ];
    
    // Search through all text for serves pattern
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
    
    // Also check the raw text in case it's on a weird line
    if (serves == null) {
      for (final pattern in servesPatterns) {
        final match = pattern.firstMatch(cleanedText);
        if (match != null) {
          serves = match.group(1);
          servesConfidence = 0.7;
          break;
        }
      }
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
    // Allow optional space between number and unit (OCR fix adds space, but pattern should handle both)
    // Include common OCR misreadings like cUP, CUP, TEASPOON, TABLESPOON
    // Include "part/parts" for cocktail recipes
    final ingredientPattern = RegExp(
      r'^([\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:\s*[\d½¼¾⅓⅔⅛⅜⅝⅞/]+)?)\s*(cups?|tbsps?|tsps?|oz|lbs?|g|kg|ml|l|pounds?|ounces?|teaspoons?|tablespoons?|parts?|c\.|t\.)\s+(.+)',
      caseSensitive: false,
    );

    final rawIngredients = <RawIngredientData>[];
    final rawDirections = <String>[];
    final ingredients = <Ingredient>[];
    final directions = <String>[];
    final garnish = <String>[];
    
    bool inIngredients = false;
    bool inDirections = false;
    bool foundIngredientHeader = false;
    bool foundDirectionHeader = false;
    
    // Track paragraph-style directions to split by sentence later
    final paragraphDirections = <String>[];
    
    // Pre-process lines:
    // 1. Handle two-column layouts (ingredient + direction on same line)
    // 2. Merge continuation lines (multi-line ingredients)
    final processedLines = <String>[];
    String? pendingIngredient;
    
    for (int i = contentStartIndex; i < lines.length; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();
      
      // Check if this line is a continuation of a previous ingredient
      // Continuation lines typically:
      // - Don't start with a number
      // - Are short (< 40 chars)
      // - Contain food-related words or "or", "page", parentheses
      final isLikelyContinuation = pendingIngredient != null &&
          !RegExp(r'^[\d½¼¾⅓⅔⅛]').hasMatch(line) &&
          line.length < 50 &&
          (lowerLine.contains('or ') || 
           lowerLine.contains('page') || 
           lowerLine.startsWith('(') ||
           lowerLine.contains('unsweetened') ||
           lowerLine.contains('homemade') ||
           lowerLine.contains('store-bought') ||
           lowerLine.contains('optional') ||
           // ALL CAPS short lines are likely ingredient continuations
           (line == line.toUpperCase() && line.length < 40 && !RegExp(r'\b(preheat|bake|mix|pour|stir)\b', caseSensitive: false).hasMatch(line)));
      
      // Check if line looks like a direction fragment (not a valid ingredient)
      final isDirectionFragment = RegExp(
        r'\b(frosting on|layer and|the top|cupcake|and set|rack for|on it|with another|an extra|fill a|pastry bag|onto each|store the|in the center|in an|airtight container)\b',
        caseSensitive: false,
      ).hasMatch(line);
      
      if (isLikelyContinuation && !isDirectionFragment) {
        // Merge with pending ingredient
        pendingIngredient = '$pendingIngredient $line';
        continue;
      }
      
      // If we have a pending ingredient, add it before processing current line
      if (pendingIngredient != null) {
        processedLines.add(pendingIngredient);
        pendingIngredient = null;
      }
      
      // Check if current line starts an ingredient that might continue
      final startsWithIngredient = ingredientPattern.hasMatch(line);
      
      // Check if line looks like merged two-column text
      final hasActionVerb = RegExp(
        r'\b(preheat|mix|stir|add|combine|bake|cook|heat|pour|whisk|fold|let|transfer|cut|spread|frost|store|line|place|remove|cool|serve)\b',
        caseSensitive: false,
      ).hasMatch(line);
      
      if (startsWithIngredient && hasActionVerb && line.length > 50) {
        // Try to split merged line
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
      
      // If this looks like start of multi-line ingredient, hold it
      if (startsWithIngredient && !hasActionVerb) {
        pendingIngredient = line;
      } else {
        processedLines.add(line);
      }
    }
    
    // Don't forget last pending ingredient
    if (pendingIngredient != null) {
      processedLines.add(pendingIngredient);
    }

    for (final line in processedLines) {
      final lowerLine = line.toLowerCase();
      
      // Skip serves lines
      if (servesPatterns.any((p) => p.hasMatch(line))) {
        continue;
      }

      // Check for section headers
      // Use word boundaries and position to avoid matching "Combine the ingredients"
      if (RegExp(r'^ingredients?[:\s]*$|^ingredients?\s*\(', caseSensitive: false).hasMatch(lowerLine.trim()) ||
          (lowerLine.trim() == 'ingredients')) {
        inIngredients = true;
        inDirections = false;
        foundIngredientHeader = true;
        continue;
      }
      if (RegExp(r'^(directions?|instructions?|method|steps?)[:\s]*$', caseSensitive: false).hasMatch(lowerLine.trim()) ||
          lowerLine.trim() == 'directions' ||
          lowerLine.trim() == 'instructions' ||
          lowerLine.trim() == 'method') {
        inIngredients = false;
        inDirections = true;
        foundDirectionHeader = true;
        continue;
      }
      
      // Check for garnish line: "To garnish: ..." or "Garnish: ..."
      final garnishMatch = RegExp(
        r'^(?:to\s+)?garnish[:\s]+(.+)',
        caseSensitive: false,
      ).firstMatch(line);
      if (garnishMatch != null) {
        final garnishText = garnishMatch.group(1)?.trim() ?? '';
        if (garnishText.isNotEmpty) {
          // Normalize garnish: remove leading articles, title case
          final normalized = normalizeGarnish(garnishText);
          garnish.add(normalized);
        }
        continue; // Don't add as ingredient
      }
      
      // Check if line is clearly prose/narrative (not ingredient or direction)
      // Prose indicators: historical references, story words, long complex sentences
      final isProseNarrative = RegExp(
        r'\b(earliest|known|history|century|centuries|combined at|winter of|thames|froze|walking|streets|baskets|hogarth|included|etching|lane|british|book|contain|began|combination|strikes|beginnings|modern|flavor|pairing|mostly|because|really|good|if you add|spiraled|between|inside|hint|becomes|substitute)\b',
        caseSensitive: false,
      ).allMatches(lowerLine).length >= 2; // Need 2+ prose words to trigger

      // Check if line looks like an ingredient
      final ingredientMatch = ingredientPattern.firstMatch(line);
      final isNumberedStep = RegExp(r'^\d+[\.\)]\s').hasMatch(line);
      
      // Long prose lines (>80 chars with multiple sentences) are likely directions
      final isLongProse = line.length > 80 && RegExp(r'\.\s+[A-Z]').hasMatch(line);
      
      // Check if line STARTS with an action verb (strong direction indicator)
      final startsWithAction = RegExp(
        r'^(preheat|in a|line|place|pour|bake|cook|heat|let|transfer|cut|spread|frost|store|remove|serve|bring|add the|add|stir|whisk|combine|mix|garnish|shake|muddle|strain|fill|chill|lift|top with|float|rim|squeeze|express|dry shake)',
        caseSensitive: false,
      ).hasMatch(lowerLine);
      
      // Check if line contains multiple cooking action words (likely a direction)
      final actionVerbCount = RegExp(
        r'\b(preheat|mix|stir|add|combine|bake|cook|heat|pour|whisk|fold|let|transfer|cut|spread|frost|store|remove|serve|bring|minutes?|degrees?|°F|°C|oven|rack|bowl|until|batter)\b',
        caseSensitive: false,
      ).allMatches(lowerLine).length;
      
      // Check if line is clearly a direction fragment (partial sentence from directions)
      final isDirectionFragment = RegExp(
        r'\b(frosting on|layer and|the top of|cupcake back|and set|on it\b|with another|an extra|fill a|pastry bag|onto each|store the|in the center|airtight container|wire rack|cool completely|come out clean|bounce back|pressure is applied|center rack|paper liners|muffin tins?|thick batter|dry ingredients|continue mixing)\b',
        caseSensitive: false,
      ).hasMatch(lowerLine);
      
      final isLikelyDirection = actionVerbCount >= 2 || startsWithAction || isDirectionFragment;
      
      // Check if this looks like a prose fragment (tips, variations, narrative)
      // This check needs to happen BEFORE inIngredients check to avoid false positives
      final isProseFragment = RegExp(
        r'\b(if you|you add|you can|becomes a|it becomes|substitute|spiraled|between the|inside of|hint[-—]?put|whole lemon|lemon peel|lemon for|for lime|horse.s neck|foghorn)\b',
        caseSensitive: false,
      ).hasMatch(lowerLine);
      
      // Check if this looks like a direction continuation (not a standalone ingredient)
      // "with a lemon wedge" is part of "Garnish with a lemon wedge"
      final isDirectionContinuation = RegExp(
        r'^(with a|with the|in a|in an|on a|on the|into a|into the|over the|highball|cocktail|martini|rocks glass|coupe)\b',
        caseSensitive: false,
      ).hasMatch(lowerLine);
      
      // Skip prose narrative and fragments entirely
      if (isProseNarrative || isProseFragment) {
        continue;
      }
      
      // Direction continuations should be appended to previous direction
      if (isDirectionContinuation && rawDirections.isNotEmpty) {
        final updated = '${rawDirections.last} $line';
        rawDirections[rawDirections.length - 1] = updated;
        directions[directions.length - 1] = updated;
        inDirections = true;
        inIngredients = false;
        continue;
      }

      if (isNumberedStep) {
        // Numbered step - definitely a direction
        final cleanedStep = line.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');
        rawDirections.add(cleanedStep);
        directions.add(cleanedStep);
        inDirections = true;
        inIngredients = false;
      } else if (startsWithAction) {
        // Line STARTS with an action verb - definitely a direction
        // Add directly to rawDirections, not paragraphDirections
        rawDirections.add(line);
        directions.add(line);
        inDirections = true;
        inIngredients = false;
      } else if (isLongProse || (isLikelyDirection && line.length > 15)) {
        // Long paragraph or line with cooking verbs - treat as direction
        // Lowered threshold to 15 chars to catch short direction lines
        paragraphDirections.add(line);
        inDirections = true;
        inIngredients = false;
      } else if (ingredientMatch != null && !isLikelyDirection) {
        // Matched ingredient pattern AND doesn't look like a direction
        final parsed = _parseIngredientLine(line);
        rawIngredients.add(parsed);
        ingredients.add(Ingredient.create(
          name: parsed.name,
          amount: parsed.amount,
          unit: parsed.unit,
        ));
        inIngredients = true;
        inDirections = false;
      } else if (inDirections || isLikelyDirection) {
        // In directions mode or line looks like a direction
        if (rawDirections.isNotEmpty && rawDirections.last.length < 100 && !startsWithAction) {
          final updated = '${rawDirections.last} $line';
          rawDirections[rawDirections.length - 1] = updated;
          directions[directions.length - 1] = updated;
        } else {
          paragraphDirections.add(line);
        }
        inDirections = true;
        inIngredients = false;
      } else if (inIngredients || ingredientMatch != null) {
        // In ingredients section or has ingredient pattern
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
        final hasActionVerb = RegExp(r'\b(preheat|mix|stir|add|combine|bake|cook|heat|pour|whisk|fold|let|transfer|cut|spread|frost|store|lift|garnish|serve|shake|muddle|strain|fill)\b', caseSensitive: false).hasMatch(lowerLine);
        
        if (hasActionVerb) {
          // Line with action verb - treat as direction
          paragraphDirections.add(line);
        } else if (line.length < 60) {
          // Assume short lines without action verbs are ingredients
          final parsed = _parseIngredientLine(line);
          // Only add if it has an amount or looks like an ingredient
          if (parsed.amount != null || parsed.looksLikeIngredient) {
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
          }
        } else {
          // Long lines without action verbs - probably prose, skip
        }
      }
    }
    
    // ===== PHASE 6: Split paragraph directions into sentences =====
    if (paragraphDirections.isNotEmpty) {
      final fullText = paragraphDirections.join(' ');
      // Split on sentence boundaries: period followed by space and capital letter
      final sentences = fullText.split(RegExp(r'(?<=\.)\s+(?=[A-Z])'));
      
      // Prose words that indicate historical/narrative text, not actual directions
      final prosePattern = RegExp(
        r'\b(earliest|history|century|combined at|winter of|thames|froze|walking|streets|baskets|hogarth|etching|lane|british|book|contain|began|combination|strikes|beginnings|modern|flavor|pairing|1730s|1751|1715|frost fairs?|sellers?|wares|characters?|dotted|tents?|gingerbread|geneva|offering)\b',
        caseSensitive: false,
      );
      
      for (final sentence in sentences) {
        final trimmed = sentence.trim();
        final lowerSentence = trimmed.toLowerCase();
        
        // Skip prose/historical narrative sentences
        if (prosePattern.allMatches(lowerSentence).length >= 1) {
          continue;
        }
        
        // Skip tips/variations (these contain prose fragment patterns)
        final isTipOrVariation = RegExp(
          r'\b(if you|you can|becomes a|it becomes|substitute|hint|horse.s neck|foghorn)\b',
          caseSensitive: false,
        ).hasMatch(lowerSentence);
        
        if (isTipOrVariation) {
          continue;
        }
        
        // Include short sentences or sentences with action verbs
        // Short direct instructions like "Lift instead of stir" should be included
        final hasAction = RegExp(
          r'\b(combine|stir|mix|add|pour|bake|cook|heat|garnish|serve|lift|shake|muddle|strain|fill|chill|refrigerate|freeze|instead)\b',
          caseSensitive: false,
        ).hasMatch(lowerSentence);
        
        if (trimmed.isNotEmpty && trimmed.length > 5 && (hasAction || trimmed.length < 50)) {
          rawDirections.add(trimmed);
          directions.add(trimmed);
        }
      }
    }

    // ===== PHASE 6.5: Post-process directions - split on periods, filter prose =====
    // Directions may have been concatenated; split them into individual steps
    final processedDirections = <String>[];
    final proseFragmentPattern = RegExp(
      r'\b(if you|you add|you can|becomes a|it becomes|substitute|spiraled|between the|inside of|hint|the drink|horse.s neck|foghorn|it in before)\b',
      caseSensitive: false,
    );
    
    for (final direction in rawDirections) {
      // Split on period followed by space and capital letter, or period at end
      final sentences = direction.split(RegExp(r'(?<=\.)\s+(?=[A-Z])|(?<=\.)\s*$'));
      
      for (final sentence in sentences) {
        final trimmed = sentence.trim();
        if (trimmed.isEmpty || trimmed.length < 5) continue;
        
        // Skip prose fragments
        if (proseFragmentPattern.hasMatch(trimmed.toLowerCase())) {
          continue;
        }
        
        processedDirections.add(trimmed);
      }
    }
    
    // Replace rawDirections and directions with processed versions
    rawDirections.clear();
    directions.clear();
    rawDirections.addAll(processedDirections);
    directions.addAll(processedDirections);

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
      garnish: garnish,
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
  /// - "1 CUP HOMEMADE APPLESAUCE (PAGE 78) OR STORE-BOUGHT UNSWEETENED APPLESAUCE"
  /// - Baker's percentage: "All-Purpose Flour, 100% – 600g (4 1/2 Cups)"
  RawIngredientData _parseIngredientLine(String line) {
    // First, extract parenthetical notes and "or" alternatives
    var workingLine = line;
    String? preparation;
    String? alternative;
    
    // Extract parenthetical content like "(page 78)" or "(optional)"
    final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(workingLine);
    if (parenMatch != null) {
      final parenContent = parenMatch.group(1)?.toLowerCase() ?? '';
      // Check if it's a page reference, optional marker, or other note
      if (parenContent.contains('page') || 
          parenContent.contains('optional') ||
          parenContent.contains('see') ||
          parenContent.contains('about')) {
        preparation = parenMatch.group(1)?.trim();
        workingLine = workingLine.replaceFirst(parenMatch.group(0)!, '').trim();
      }
    }
    
    // Extract "or ..." alternatives
    final orMatch = RegExp(r'\s+or\s+(.+)$', caseSensitive: false).firstMatch(workingLine);
    if (orMatch != null) {
      alternative = orMatch.group(1)?.trim();
      workingLine = workingLine.substring(0, orMatch.start).trim();
    }
    
    // Try baker's percentage format first: "Name, XX% – amount (alt amount)"
    final bakerMatch = RegExp(
      r'^([^,]+),\s*([\d.]+)%\s*[–—-]\s*(\d+\s*(?:g|kg|ml|l|oz|lb)?)\s*(?:\(([^)]+)\))?',
      caseSensitive: false,
    ).firstMatch(workingLine);
    
    if (bakerMatch != null) {
      return RawIngredientData(
        original: line,
        name: bakerMatch.group(1)?.trim() ?? line,
        bakerPercent: '${bakerMatch.group(2)}%',
        amount: bakerMatch.group(3)?.trim(),
        preparation: preparation ?? bakerMatch.group(4)?.trim(),
        alternative: alternative,
        looksLikeIngredient: true,
      );
    }
    
    // Try standard format: "amount unit name" (case insensitive)
    // Supports: 1 CUP, 1/2 cup, ½ cup, 1½ cups, 2 parts, etc.
    final standardMatch = RegExp(
      r'^([\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:\s*/\s*\d+)?(?:\s*[\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:/\d+)?)?)\s*(cups?|tbsps?|tsps?|oz|lbs?|g|kg|ml|l|pounds?|ounces?|teaspoons?|tablespoons?|parts?|c\.|t\.)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(workingLine);
    
    if (standardMatch != null) {
      final amount = standardMatch.group(1)?.trim();
      final normalizedUnit = _normalizeUnit(standardMatch.group(2)?.trim());
      return RawIngredientData(
        original: line,
        amount: amount,
        unit: _pluralizeUnit(normalizedUnit, amount),
        name: _cleanIngredientName(standardMatch.group(3)?.trim() ?? workingLine),
        preparation: preparation,
        alternative: alternative,
        looksLikeIngredient: true,
      );
    }
    
    // Try format without explicit unit but with amount: "2 eggs", "3 cloves garlic"
    // Also handles cases where OCR might have weird spacing
    final simpleMatch = RegExp(
      r'^([\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:\s*/\s*\d+)?(?:\s*[\d½¼¾⅓⅔⅛⅜⅝⅞]+)?)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(workingLine);
    
    if (simpleMatch != null) {
      var name = simpleMatch.group(2)?.trim() ?? workingLine;
      String? unit;
      final amount = simpleMatch.group(1)?.trim();
      
      // Check if the name starts with a unit word that wasn't captured by standardMatch
      // This handles cases like "1 CUP COCONUT OIL" where spacing confused the parser
      final unitAtStartMatch = RegExp(
        r'^(cups?|tbsps?|tsps?|oz|lbs?|g|kg|ml|l|pounds?|ounces?|teaspoons?|tablespoons?|parts?|c\.|t\.)\s+(.+)',
        caseSensitive: false,
      ).firstMatch(name);
      
      if (unitAtStartMatch != null) {
        final normalizedUnit = _normalizeUnit(unitAtStartMatch.group(1)?.trim());
        unit = _pluralizeUnit(normalizedUnit, amount);
        name = unitAtStartMatch.group(2)?.trim() ?? name;
      }
      
      // Only count as ingredient if name looks like food (not a direction)
      final looksLikeFood = !RegExp(r'\b(preheat|bake|cook|stir|mix|add|pour|let|until|minutes?|degrees?|°)\b', caseSensitive: false).hasMatch(name);
      return RawIngredientData(
        original: line,
        amount: amount,
        unit: unit,
        name: _cleanIngredientName(name),
        preparation: preparation,
        alternative: alternative,
        looksLikeIngredient: looksLikeFood && (unit != null || name.length < 40),
      );
    }
    
    // Fallback - just use the line as name (after extracting notes/alternatives)
    return RawIngredientData(
      original: line,
      name: _cleanIngredientName(workingLine),
      preparation: preparation,
      alternative: alternative,
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
      'part': 'part',
      'parts': 'parts',
    };
    
    return unitMap[lower] ?? unit;
  }
  
  /// Get the appropriate unit form based on amount (singular vs plural)
  String? _pluralizeUnit(String? unit, String? amount) {
    if (unit == null) return null;
    if (amount == null) return unit;
    
    // Parse amount to determine if plural
    final numMatch = RegExp(r'^([\d.]+)').firstMatch(amount);
    if (numMatch != null) {
      final num = double.tryParse(numMatch.group(1) ?? '');
      if (num != null && num > 1) {
        // Pluralize
        if (unit == 'part') return 'parts';
        if (unit == 'cup') return 'cups';
        if (unit == 'lb') return 'lbs';
        if (unit == 'oz') return 'oz'; // oz stays same
      }
    }
    // Check for fractions > 1 like "1½" or "2"
    if (amount.contains('½') || amount.contains('¼') || amount.contains('¾')) {
      final firstChar = amount.isNotEmpty ? amount[0] : '0';
      final firstNum = int.tryParse(firstChar);
      if (firstNum != null && firstNum >= 1 && amount.length > 1) {
        // Like "1½" - more than 1, pluralize
        if (unit == 'part') return 'parts';
        if (unit == 'cup') return 'cups';
        if (unit == 'lb') return 'lbs';
      }
    }
    return unit;
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
  
  /// Fix common OCR artifacts and misreadings
  String _fixOcrArtifacts(String text) {
    var fixed = text;
    
    // Fix fraction misreadings:
    // OCR often reads ¼ as "v4", "V4", "/4", "14" (without space)
    // OCR often reads ½ as "v2", "V2", "/2", "12" 
    // OCR often reads ¾ as "v4" (3/4), "/4" with context
    
    // Fix "v4" or "V4" -> ¼ (when at start of word/line or after space/number)
    fixed = fixed.replaceAllMapped(
      RegExp(r'(\d\s*)[vV]4\b'),
      (m) => '${m.group(1)}¼',
    );
    fixed = fixed.replaceAllMapped(
      RegExp(r'^[vV]4\b', multiLine: true),
      (m) => '¼',
    );
    fixed = fixed.replaceAllMapped(
      RegExp(r'\s[vV]4\b'),
      (m) => ' ¼',
    );
    
    // Fix "/4" -> ¼ (standalone or after number)
    fixed = fixed.replaceAllMapped(
      RegExp(r'(\d\s*)/4\b'),
      (m) => '${m.group(1)}¼',
    );
    fixed = fixed.replaceAllMapped(
      RegExp(r'^/4\b', multiLine: true),
      (m) => '¼',
    );
    fixed = fixed.replaceAllMapped(
      RegExp(r'\s/4\b'),
      (m) => ' ¼',
    );
    
    // Fix "3/4" or "3v4" or "3V4" -> ¾
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b3\s*[/vV]\s*4\b'),
      (m) => '¾',
    );
    
    // Fix "94" at start of line or after space followed by unit -> ¾ (OCR reads ¾ as 94)
    // Handle mixed case units
    fixed = fixed.replaceAllMapped(
      RegExp(r'(^|\s)94\s*(c[uU][pP]|cups?|teaspoons?|tsp|tablespoons?|tbsp)\b', caseSensitive: false, multiLine: true),
      (m) => '${m.group(1)}¾ ${m.group(2)}',
    );
    
    // Fix "1/4" -> ¼
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b1\s*/\s*4\b'),
      (m) => '¼',
    );
    
    // Fix "Ya" or "ya" followed by unit -> ¼ (OCR reads ¼ as Ya)
    // Handle mixed case like "YacUP", "YaCUP", "Yacup"
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b[Yy]a\s*(c[uU][pP]|cups?|teaspoons?|tsp|tablespoons?|tbsp)\b', caseSensitive: false),
      (m) => '¼ ${m.group(1)}',
    );
    
    // Fix "Ve" or "ve" followed by unit -> ½ (OCR reads ½ as Ve)
    // Handle mixed case like "VecUP", "VeCUP", "Vecup"
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b[Vv]e\s*(c[uU][pP]|cups?|teaspoons?|tsp|tablespoons?|tbsp)\b', caseSensitive: false),
      (m) => '½ ${m.group(1)}',
    );
    
    // Fix "v2" or "V2" or "/2" -> ½
    fixed = fixed.replaceAllMapped(
      RegExp(r'(\d\s*)[vV/]2\b'),
      (m) => '${m.group(1)}½',
    );
    fixed = fixed.replaceAllMapped(
      RegExp(r'^[vV/]2\b', multiLine: true),
      (m) => '½',
    );
    fixed = fixed.replaceAllMapped(
      RegExp(r'\s[vV/]2\b'),
      (m) => ' ½',
    );
    
    // Fix "12" that should be "1½" when followed by unit (OCR reads 1½ as 12)
    // Only apply when at start of line or after newline
    fixed = fixed.replaceAllMapped(
      RegExp(r'(^|\n)12\s+(cups?|teaspoons?|tsp|tablespoons?|tbsp)', caseSensitive: false, multiLine: true),
      (m) => '${m.group(1)}1½ ${m.group(2)}',
    );
    
    // Fix "1/2" -> ½
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b1\s*/\s*2\b'),
      (m) => '½',
    );
    
    // Fix "1/3" -> ⅓
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b1\s*/\s*3\b'),
      (m) => '⅓',
    );
    
    // Fix "2/3" -> ⅔
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b2\s*/\s*3\b'),
      (m) => '⅔',
    );
    
    // Fix number+unit with no space: "7CUP" -> "7 CUP", "1CUP" -> "1 CUP"
    fixed = fixed.replaceAllMapped(
      RegExp(r'(\d)(cup|cups|teaspoon|teaspoons|tsp|tablespoon|tablespoons|tbsp|oz|lb|lbs|pound|pounds|ounce|ounces)\b', caseSensitive: false),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    
    // Normalize mixed-case units to lowercase: "cUP" -> "cup", "TEASPOON" -> "teaspoon"
    // This ensures consistent parsing downstream
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b(c[uU][pP]s?|[tT][eE][aA][sS][pP][oO][oO][nN]s?|[tT][aA][bB][lL][eE][sS][pP][oO][oO][nN]s?)\b'),
      (m) => m.group(0)!.toLowerCase(),
    );
    
    // Fix stylized bullets being read as numbers in cocktail/drink recipes
    // "4 2 parts" -> "2 parts" (decorative bullet read as "4")
    // "P4 parts" -> "4 parts" ("P" from stylized character)
    // "A 2 parts" -> "2 parts" (various OCR artifacts)
    // Handle at start of line OR after newline
    fixed = fixed.replaceAllMapped(
      RegExp(r'(^|\n)[A-Za-z]\s*(\d+\s+parts?)\b', multiLine: true, caseSensitive: false),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    
    // Fix "P4" pattern where P is directly attached to number ("P4 parts" -> "4 parts")
    fixed = fixed.replaceAllMapped(
      RegExp(r'(^|\n)[Pp](\d+\s+parts?)\b', multiLine: true, caseSensitive: false),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    
    // Fix "4 2 parts" pattern (number-space-number-parts)
    fixed = fixed.replaceAllMapped(
      RegExp(r'(^|\n)\d\s+(\d+\s+parts?)\b', multiLine: true, caseSensitive: false),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    
    return fixed;
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
