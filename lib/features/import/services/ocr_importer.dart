import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ingredient_parser.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../../core/utils/unit_normalizer.dart';
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

  /// Pick an image from camera without processing (for use with external cropping)
  /// Returns the image path or null if cancelled
  Future<String?> pickImageFromCamera() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return null;
    }
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    return image?.path;
  }

  /// Pick an image from gallery without processing (for use with external cropping)
  /// Returns the image path or null if cancelled
  Future<String?> pickImageFromGallery() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return null;
    }
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    return image?.path;
  }

  /// Process an image from a given path (public method for use after cropping)
  Future<OcrResult> processImageFromPath(String imagePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return OcrResult.error('OCR is not supported on desktop platforms.');
    }
    return _processImage(imagePath);
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
    
    // Common cookbook chapter/section headers to skip
    final chapterHeaderPattern = RegExp(
      r'^(fish\s*(and|&)\s*seafood|appetizers?|soups?\s*(and|&)\s*stews?|salads?|main\s*(courses?|dishes?)|mains?|desserts?|breads?|breakfast|brunch|beverages?|drinks?|cocktails?|sides?|vegetables?|pasta|poultry|meats?|beef|pork|lamb|chicken|sauces?|baking|cakes?|cookies?|pies?|puddings?|snacks?)\s*$',
      caseSensitive: false,
    );
    
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
      
      // Skip cookbook chapter headers (e.g., "Fish and Seafood", "Appetizers")
      if (chapterHeaderPattern.hasMatch(line)) {
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

    // ===== PHASE 2.5: Extract time from various patterns =====
    String? time;
    double timeConfidence = 0.0;
    
    // Pattern 1: "HANDS ON X minutes BAKE Y minutes" (cookbook format)
    final handsOnBakeMatch = RegExp(
      r'hands\s*on\s*(\d+)\s*(?:minutes?|mins?).*?bake\s*(\d+)\s*(?:minutes?|mins?)',
      caseSensitive: false,
    ).firstMatch(cleanedText);
    if (handsOnBakeMatch != null) {
      final handsOn = int.tryParse(handsOnBakeMatch.group(1) ?? '') ?? 0;
      final bake = int.tryParse(handsOnBakeMatch.group(2) ?? '') ?? 0;
      final totalMinutes = handsOn + bake;
      if (totalMinutes > 0) {
        if (totalMinutes >= 60) {
          final hours = totalMinutes ~/ 60;
          final mins = totalMinutes % 60;
          time = mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
        } else {
          time = '$totalMinutes min';
        }
        timeConfidence = 0.85;
      }
    }
    
    // Pattern 2: "Prep X min" + "Cook Y min" or similar
    if (time == null) {
      int totalMinutes = 0;
      final prepMatch = RegExp(r'prep(?:aration)?[:\s]*(\d+)\s*(?:minutes?|mins?|m\b)', caseSensitive: false).firstMatch(cleanedText);
      final cookMatch = RegExp(r'cook(?:ing)?[:\s]*(\d+)\s*(?:minutes?|mins?|m\b)', caseSensitive: false).firstMatch(cleanedText);
      if (prepMatch != null) totalMinutes += int.tryParse(prepMatch.group(1) ?? '') ?? 0;
      if (cookMatch != null) totalMinutes += int.tryParse(cookMatch.group(1) ?? '') ?? 0;
      if (totalMinutes > 0) {
        if (totalMinutes >= 60) {
          final hours = totalMinutes ~/ 60;
          final mins = totalMinutes % 60;
          time = mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
        } else {
          time = '$totalMinutes min';
        }
        timeConfidence = 0.75;
      }
    }

    // ===== PHASE 3: Detect course from context clues =====
    String course = 'Mains';
    double courseConfidence = 0.2;
    final allText = cleanedText.toLowerCase();  // Use cleanedText for OCR-fixed keywords
    
    // Dessert indicators
    final dessertKeywords = ['cupcake', 'cake', 'cookie', 'brownie', 'frosting', 
        'icing', 'sugar', 'vanilla extract', 'chocolate', 'dessert', 'sweet',
        'muffin', 'pie', 'tart', 'pastry', 'baking powder', 'baking soda',
        'shortbread', 'biscotti', 'scone', 'macaron', 'truffle', 'fudge',
        'meringue', 'pudding', 'custard', 'mousse', 'cheesecake', 'ice cream'];
    final dessertCount = dessertKeywords.where((k) => allText.contains(k)).length;
    
    // Drink indicators - check for spirits, beer/wine, and cocktail-specific terms
    final drinkKeywords = ['cocktail', 'shake', 'smoothie', 'juice', 'vodka', 
        'gin', 'rum', 'whiskey', 'whisky', 'bourbon', 'tequila', 'mezcal',
        'liqueur', 'liquor', 'vermouth', 'bitters', 'triple sec', 'cointreau',
        'amaretto', 'kahlua', 'baileys', 'schnapps', 'absinthe', 'campari',
        'aperol', 'chambord', 'cassis', 'crรจme de', 'creme de',
        'beer', 'wheat beer', 'lager', 'ale', 'stout', 'wine', 'prosecco',
        'champagne', 'sparkling', 'soda water', 'tonic', 'club soda',
        'parts', '1 part', '2 parts', '3 parts', '4 parts', // cocktail measurements
        'oz vodka', 'oz gin', 'oz rum', 'oz whiskey', 'oz tequila',
        'garnish with', 'to garnish', 'highball', 'martini glass', 'coupe',
        'rocks glass', 'collins glass', 'shaker', 'muddle', 'strain',
        'sipsmith', 'london dry', 'angostura'];
    final drinkCount = drinkKeywords.where((k) => allText.contains(k)).length;
    
    // Mains/food indicators - if these are present, it's likely NOT a drink
    // Used to override false positive drink detection when wine/spirits are cooking ingredients
    // Food keywords that indicate MAIN dish content (proteins, substantial ingredients)
    // IMPORTANT: Do NOT include cooking verbs (bake, roast, fry) - those don't indicate food content
    // Do NOT include vegetables here - they are checked separately for Sides detection
    final foodKeywords = ['chicken', 'beef', 'pork', 'lamb', 'fish', 'salmon', 'shrimp',
        'pasta', 'rice',
        'breast', 'thigh', 'leg', 'loin', 'steak', 'fillet', 'filet',
        'main course', 'entrée',
        'mozzarella', 'parmesan', 'cheddar', 'breadcrumb'];
    final foodCount = foodKeywords.where((k) => allText.contains(k)).length;
    
    // Appetizer indicators - require full word matching to avoid false positives
    final appKeywords = ['appetizer', 'starter', 'finger food', 'hors d\'oeuvre', 'antipasto', 'antipasti'];
    final appCount = appKeywords.where((k) => RegExp('\\b${RegExp.escape(k)}\\b', caseSensitive: false).hasMatch(allText)).length;
    
    // Side indicators - vegetables as main ingredient often indicate sides
    final sideKeywords = ['side dish', 'accompaniment', 'serve alongside', 'serve with', 
        'fried fennel', 'fried zucchini', 'fried eggplant', 'roasted vegetables',
        'sautéed', 'sauteed', 'steamed', 'braised', 'glazed'];
    final sideCount = sideKeywords.where((k) => allText.contains(k)).length;
    
    // Salad indicators
    final saladKeywords = ['salad', 'insalata', 'salade', 'ensalada', 'lettuce', 
        'mixed greens', 'arugula', 'spinach salad', 'caesar', 'vinaigrette',
        'dressing', 'toss gently', 'bed of lettuce', 'salad greens'];
    final saladCount = saladKeywords.where((k) => allText.contains(k)).length;
    
    // Vegetable-centric dishes (no meat protein) are likely sides
    final vegetableKeywords = ['fennel', 'zucchini', 'eggplant', 'asparagus', 'broccoli',
        'cauliflower', 'brussels sprouts', 'green beans', 'spinach', 'kale', 'chard',
        'artichoke', 'mushroom', 'potato', 'sweet potato', 'carrot', 'beet', 'turnip',
        'parsnip', 'squash', 'pumpkin', 'corn', 'peas', 'cabbage', 'leek', 'onion'];
    final vegetableCount = vegetableKeywords.where((k) => allText.contains(k)).length;
    
    // Protein keywords that indicate this is likely a main, not a side
    final proteinKeywords = ['chicken', 'beef', 'pork', 'lamb', 'veal', 'fish', 'salmon',
        'shrimp', 'lobster', 'crab', 'scallop', 'duck', 'turkey', 'steak', 'chop',
        'roast', 'breast', 'thigh', 'leg', 'loin', 'tenderloin', 'rib'];
    final proteinCount = proteinKeywords.where((k) => allText.contains(k)).length;
    
    // Determine course based on keyword density
    // Food indicators override drink/app detection when there's clear main dish content
    if (dessertCount >= 2) {
      course = 'Desserts';
      courseConfidence = 0.6 + (dessertCount * 0.05).clamp(0.0, 0.2);
    } else if (drinkCount >= 2 && foodCount < 3) {
      // Only classify as Drinks if we have drink keywords AND not many food keywords
      // This prevents false positives when wine/spirits are cooking ingredients
      course = 'Drinks';
      courseConfidence = 0.6 + (drinkCount * 0.05).clamp(0.0, 0.2);
    } else if (saladCount >= 2) {
      // Salad detection - multiple salad keywords
      course = 'Salads';
      courseConfidence = 0.6 + (saladCount * 0.05).clamp(0.0, 0.2);
    } else if (appCount >= 1 && foodCount < 3) {
      // Only classify as Apps if there aren't many main dish indicators
      course = 'Apps';
      courseConfidence = 0.5;
    } else if (sideCount >= 1 && foodCount < 3) {
      course = 'Sides';
      courseConfidence = 0.5;
    } else if (vegetableCount >= 1 && proteinCount == 0 && foodCount < 3) {
      // Vegetable-centric dish with no protein = likely a side dish
      // e.g., "Fried Fennel", "Roasted Asparagus"
      course = 'Sides';
      courseConfidence = 0.5;
    } else if (foodCount >= 2) {
      // If we have substantial food keywords, default to Mains
      course = 'Mains';
      courseConfidence = 0.5 + (foodCount * 0.02).clamp(0.0, 0.2);
    }

    // ===== PHASE 4: Identify intro paragraphs as notes =====
    // Also skip subtitle lines (translations, alternate names) after the title
    String? notes;
    final introLines = <String>[];
    int contentStartIndex = titleLineIndex + 1;
    
    // Look for intro paragraphs after title - long sentences that aren't ingredients
    // Also detect and skip subtitle lines (short descriptive lines after title)
    for (int i = titleLineIndex + 1; i < lines.length && i < titleLineIndex + 12; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();
      
      // Stop if we hit an ingredient-like line (starts with amount + unit)
      // Include "parts" for cocktail recipes
      if (RegExp(r'^[\d½¼¾⅓⅔⅛]+\s*(cup|cups|tbsp|tsp|oz|lb|g|kg|ml|l|pound|ounce|teaspoon|tablespoon|parts?)', caseSensitive: false).hasMatch(line)) {
        break;
      }
      
      // Stop if we hit the "Ingredients" section header
      if (lowerLine.trim() == 'ingredients' || lowerLine.trim() == 'ingredients:' ||
          RegExp(r'^ingredients?\s*[:\(]', caseSensitive: false).hasMatch(lowerLine.trim())) {
        contentStartIndex = i + 1;
        break;
      }
      
      // Stop if we hit "Directions" or similar
      if (lowerLine.contains('direction') || lowerLine.contains('instruction') || 
          lowerLine.contains('method:') || lowerLine.trim() == 'method') {
        break;
      }
      
      // Check if this looks like a subtitle (short, Title Case or ALL CAPS, no amounts)
      // Examples: "Grilled Salmon Steaks with Hollandaise Sauce"
      final looksLikeSubtitle = line.length >= 10 && line.length < 60 &&
          !RegExp(r'^[\d½¼¾⅓⅔⅛]').hasMatch(line) &&
          !RegExp(r'\b(cup|tbsp|tsp|oz|lb|kg|ml|minutes?|degrees?)\b', caseSensitive: false).hasMatch(line) &&
          (line == line.toUpperCase() || // ALL CAPS
           RegExp(r'^[A-Z]').hasMatch(line)); // Starts with capital
      
      // Check if this is a prose/intro line (contains complete sentences or descriptive text)
      final isProseIntro = line.length > 20 && line.contains(' ') &&
          !RegExp(r'^[\d½¼¾⅓⅔⅛]').hasMatch(line) &&
          // Contains prose words or sentence patterns
          (RegExp(r'\b(this|you|can|the|is|are|an|excellent|way|will|your|or|delicious|authentic|original|recipe|dish|make|it|fact|want|eat|every|last|crumb|also|so|in|cheese)\b', caseSensitive: false).hasMatch(lowerLine) ||
           line.contains('.') || // Contains periods (sentences)
           line.contains(',')) && // Contains commas (complex text)
          // NOT a line that looks like directions or ingredients
          !RegExp(r'^(preheat|in a|place|pour|bake|cook|heat|let|transfer|cut|slice|mix|stir|add|combine|ingredients?|directions?)', caseSensitive: false).hasMatch(lowerLine);
      
      // Skip "Makes X", "Serves X" lines
      if (servesPatterns.any((p) => p.hasMatch(line))) {
        contentStartIndex = i + 1;
        continue;
      }
      
      if (looksLikeSubtitle) {
        // Subtitle - add to notes and continue looking
        introLines.add(line);
        contentStartIndex = i + 1;
        continue;
      }
      
      if (isProseIntro) {
        // Intro paragraph line - add to notes
        introLines.add(line);
        contentStartIndex = i + 1;
        continue;
      }
      
      // Check if this is a short trailing word from the previous intro line
      // (OCR sometimes splits the last word of a paragraph onto its own line)
      // Examples: "grilling.", "sauce", "recipe."
      final isTrailingWord = line.length < 20 && 
          !RegExp(r'^[\d½¼¾⅓⅔⅛]').hasMatch(line) &&
          !line.contains(' ') && // Single word
          introLines.isNotEmpty; // We already have intro text
      
      if (isTrailingWord) {
        // Append to the last intro line instead of adding as new line
        if (introLines.isNotEmpty) {
          introLines[introLines.length - 1] = '${introLines.last} $line';
        }
        contentStartIndex = i + 1;
        continue;
      }
      
      // If we get here, it's something else - might be start of ingredients
      // Only break if we've already collected some intro text
      if (introLines.isNotEmpty) {
        break;
      }
      // Otherwise, skip this line and keep looking (might be a stray short line)
      contentStartIndex = i + 1;
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
    
    // Secondary pattern for ingredients without units: "½ corn starch", "2 eggs"
    // Matches fraction/number followed directly by ingredient name (no unit)
    // Allow hyphens in ingredient names (e.g., "all-purpose")
    final ingredientNoUnitPattern = RegExp(
      r"^([\d½¼¾⅓⅔⅛⅜⅝⅞]+)\s+([a-zA-Z][a-zA-Z\s\-']+)$",
      caseSensitive: false,
    );
    
    // Tertiary pattern: just a fraction/number followed by any text (most permissive)
    // Used as fallback to catch things like "½ corn starch" with trailing spaces/chars
    final ingredientFractionStartPattern = RegExp(
      r'^([\d½¼¾⅓⅔⅛⅜⅝⅞]+)\s+(.+)$',
      caseSensitive: false,
    );

    final rawIngredients = <RawIngredientData>[];
    final rawDirections = <String>[];
    final ingredients = <Ingredient>[];
    final directions = <String>[];
    final garnish = <String>[];
    
    // Track nutrition info from OCR
    int? parsedCalories;
    double? parsedFat;
    double? parsedCarbs;
    double? parsedProtein;
    double? parsedFiber;
    double? parsedSodium;
    double? parsedSugar;
    String? parsedServingSize;
    
    bool inIngredients = false;
    bool inDirections = false;
    bool inMetricSection = false;
    bool foundIngredientHeader = false;
    bool foundDirectionHeader = false;
    
    // Track metric values for two-column cookbook layouts
    // These will be paired with ingredients by position after parsing
    final metricValues = <String>[];
    
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
      // BUT NOT if the line is a garnish line or looks like a direction
      final looksLikeGarnish = RegExp(r'(?:to\s+)?garnish[:\s]', caseSensitive: false).hasMatch(lowerLine);
      final looksLikeDirection = RegExp(r'\b(preheat|bake|cook|roast|grill|broil|fry|saute|sauté|simmer|boil|steam|mix|combine|stir|whisk|beat|fold|pour|spread|let|place|remove|set|turn|cover|refrigerate|chill|freeze|cool|rest|allow|serve|slice|dice|chop|mince|cut|trim|peel|core|pit|seed|hull|julienne|brunoise|until|into|degrees?|°F|°C|minutes?|mins?|oven|thickness)\b', caseSensitive: false).hasMatch(lowerLine);
      final isLikelyContinuation = pendingIngredient != null &&
          !looksLikeGarnish &&
          !looksLikeDirection &&
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
           (line == line.toUpperCase() && line.length < 40));
      
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
      // Check both patterns: with unit, without unit, and fallback fraction-start
      final startsWithIngredient = ingredientPattern.hasMatch(line) || 
          ingredientNoUnitPattern.hasMatch(line) ||
          ingredientFractionStartPattern.hasMatch(line);
      
      // Split lines that have embedded "To garnish:" or "Garnish:" patterns
      // OCR often merges ingredient line with garnish line: "4 parts wheat beerTo garnish: orange"
      // Also handles "Wheat beer To garnish:" where ingredient name comes first
      final garnishSplitMatch = RegExp(
        r'^(.+?)\s*((?:to\s+)?garnish[:\s].+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (garnishSplitMatch != null) {
        final beforeGarnish = garnishSplitMatch.group(1)?.trim();
        final garnishPart = garnishSplitMatch.group(2)?.trim();
        if (beforeGarnish != null && beforeGarnish.isNotEmpty && 
            garnishPart != null && garnishPart.isNotEmpty &&
            beforeGarnish.length > 3) {  // Ensure we have meaningful content before garnish
          // Always split if we found a garnish pattern mid-line
          processedLines.add(beforeGarnish);
          processedLines.add(garnishPart);
          continue;
        }
      }
      
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
    
    // ===== PRE-PHASE 5.5: Pair standalone ingredient names with amounts =====
    // OCR sometimes reads ingredient name and amount on separate lines
    // Pattern A: "lemons" followed by "2" -> "2 lemons"
    // Pattern B: "2" followed by "lemons" -> "2 lemons"
    final pairedLines = <String>[];
    final standaloneNumberPattern = RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞]+\s*$');
    final standaloneFoodPattern = RegExp(
      r'^(lemon|lime|orange|egg|onion|apple|banana|tomato|potato|clove|head|bunch|stalk|rib|sprig|slice|zest|butter|sugar|flour|salt|pepper|garlic|ginger|corn\s*starch|starch|vanilla|cinnamon)s?\s*$',
      caseSensitive: false,
    );
    
    int i = 0;
    while (i < processedLines.length) {
      final line = processedLines[i].trim();
      final hasNextLine = i + 1 < processedLines.length;
      final nextLine = hasNextLine ? processedLines[i + 1].trim() : '';
      
      final isStandaloneFoodWord = standaloneFoodPattern.hasMatch(line);
      final isStandaloneNumber = standaloneNumberPattern.hasMatch(line);
      final nextIsStandaloneFoodWord = standaloneFoodPattern.hasMatch(nextLine);
      final nextIsStandaloneNumber = standaloneNumberPattern.hasMatch(nextLine);
      
      // Check if next line is a food word that could pair with current number/fraction
      // This handles "½" + "corn starch" -> "½ corn starch"
      // Trim whitespace and be permissive - allow letters, spaces, hyphens
      final nextTrimmed = nextLine.trim();
      final nextCouldBeIngredientName = hasNextLine && 
          nextTrimmed.isNotEmpty &&
          !standaloneNumberPattern.hasMatch(nextTrimmed) &&
          RegExp(r'^[a-zA-Z][a-zA-Z\s\-]*$').hasMatch(nextTrimmed) &&
          nextTrimmed.length > 2 && nextTrimmed.length < 40;
      
      if (isStandaloneFoodWord && nextIsStandaloneNumber) {
        // Pattern A: "lemons" + "2" -> "2 lemons"
        pairedLines.add('$nextLine $line');
        i += 2; // Skip both lines
      } else if (isStandaloneNumber && nextIsStandaloneFoodWord) {
        // Pattern B: "2" + "lemons" -> "2 lemons"
        pairedLines.add('$line $nextLine');
        i += 2; // Skip both lines
      } else if (isStandaloneNumber && nextCouldBeIngredientName) {
        // Pattern C: "½" + "corn starch" -> "½ corn starch"
        pairedLines.add('$line $nextLine');
        i += 2; // Skip both lines
      } else {
        pairedLines.add(line);
        i++;
      }
    }

    for (final line in pairedLines) {
      final lowerLine = line.toLowerCase();
      
      // Skip serves lines
      if (servesPatterns.any((p) => p.hasMatch(line))) {
        continue;
      }
      
      // Skip lines that look like recipe titles or chapter headers
      // (ALL CAPS short lines without amounts, or Title Case short lines)
      // These should have been filtered by contentStartIndex but might slip through
      final looksLikeTitle = line.length > 5 && line.length < 50 &&
          !RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞]').hasMatch(line) &&
          (line == line.toUpperCase() || // ALL CAPS
           RegExp(r'^[A-Z][a-z]+(\s+[A-Z][a-z]+)+$').hasMatch(line)) && // Title Case
          !RegExp(r'\b(cup|cups|tbsp|tsp|oz|lb|g|kg|ml|clove|pinch|dash)\b', caseSensitive: false).hasMatch(line);
      if (looksLikeTitle && !inIngredients && !inDirections) {
        // Likely a title or section header, skip
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
      
      // Detect "Metric" section header (cookbook two-column format)
      // Lines after this are metric equivalents that we'll pair with ingredients
      // Also detect metric column headers like "g", "kg", "ml" alone
      if (lowerLine.trim() == 'metric' || lowerLine.trim() == 'metric:' ||
          lowerLine.trim() == 'g' || lowerLine.trim() == 'kg' || lowerLine.trim() == 'ml') {
        inIngredients = false;
        inDirections = false;
        inMetricSection = true;
        continue;
      }
      
      // Collect standalone metric values (just a number with optional metric unit)
      // These are the right column in two-column cookbook layouts
      // Examples: "1 kg", "235 ml", "470 ml", "1", "2", "500g", "250 g"
      // Also match metric values that might appear after ingredients have been collected
      final isStandaloneMetric = RegExp(
        r'^[\d½¼¾⅓⅔⅛⅜⅝⅞]+\s*(kg|g|ml|l|liters?|litres?|cl)?\s*$',
        caseSensitive: false,
      ).hasMatch(line.trim());
      if (isStandaloneMetric && line.trim().length < 12) {
        // If we're in metric section OR we already have ingredients collected
        // (metric values often appear right after ingredients in two-column layouts)
        if (inMetricSection || (rawIngredients.isNotEmpty && !inDirections)) {
          metricValues.add(line.trim());
          // Auto-enter metric section if we have ingredients and see metric values
          if (!inMetricSection && rawIngredients.isNotEmpty) {
            inMetricSection = true;
          }
        }
        // Skip adding as ingredient either way
        continue;
      }
      
      // Exit metric section when we hit a non-metric line (like directions)
      if (inMetricSection && !isStandaloneMetric) {
        inMetricSection = false;
      }
      
      // Parse and collect nutrition information (PER BAR, PER SERVING, cal, carb, sodium, etc.)
      // Extract values instead of just skipping
      final isNutritionLine = RegExp(
        r'\b(per\s+(?:bar|serving|portion)|cal(?:ories)?[,\s]|\d+\s*g?\s*(?:fat|carb|protein|fiber|fibre|sodium|chol|cholesterol|sat(?:urated)?|trans|sugars?|pro)\b|mg\s+(?:sodium|chol)|g\s+(?:fat|carb|fiber|sugars?|pro))',
        caseSensitive: false,
      ).hasMatch(lowerLine);
      if (isNutritionLine) {
        // Extract serving size if present
        final servingSizeMatch = RegExp(r'per\s+(bar|serving|portion)', caseSensitive: false).firstMatch(lowerLine);
        if (servingSizeMatch != null) {
          parsedServingSize = '1 ${servingSizeMatch.group(1)}';
        }
        
        // Extract calories: "120 cal", "120 calories", "cal 120"
        final calMatch = RegExp(r'(\d+)\s*cal(?:ories)?|cal(?:ories)?\s*(\d+)', caseSensitive: false).firstMatch(line);
        if (calMatch != null) {
          final calValue = calMatch.group(1) ?? calMatch.group(2);
          if (calValue != null) parsedCalories = int.tryParse(calValue);
        }
        
        // Extract fat: "5g fat", "5 g fat", "fat 5g"
        final fatMatch = RegExp(r'(\d+\.?\d*)\s*g?\s*(?:total\s+)?fat|fat\s*(\d+\.?\d*)\s*g?', caseSensitive: false).firstMatch(line);
        if (fatMatch != null) {
          final fatValue = fatMatch.group(1) ?? fatMatch.group(2);
          if (fatValue != null) parsedFat = double.tryParse(fatValue);
        }
        
        // Extract carbs: "20g carb", "carbohydrate 20g"
        final carbMatch = RegExp(r'(\d+\.?\d*)\s*g?\s*carb(?:ohydrate)?s?|carb(?:ohydrate)?s?\s*(\d+\.?\d*)\s*g?', caseSensitive: false).firstMatch(line);
        if (carbMatch != null) {
          final carbValue = carbMatch.group(1) ?? carbMatch.group(2);
          if (carbValue != null) parsedCarbs = double.tryParse(carbValue);
        }
        
        // Extract protein: "5g protein", "pro 5g"
        final proteinMatch = RegExp(r'(\d+\.?\d*)\s*g?\s*(?:protein|pro)|(?:protein|pro)\s*(\d+\.?\d*)\s*g?', caseSensitive: false).firstMatch(line);
        if (proteinMatch != null) {
          final protValue = proteinMatch.group(1) ?? proteinMatch.group(2);
          if (protValue != null) parsedProtein = double.tryParse(protValue);
        }
        
        // Extract fiber: "3g fiber"
        final fiberMatch = RegExp(r'(\d+\.?\d*)\s*g?\s*fib(?:er|re)|fib(?:er|re)\s*(\d+\.?\d*)\s*g?', caseSensitive: false).firstMatch(line);
        if (fiberMatch != null) {
          final fiberValue = fiberMatch.group(1) ?? fiberMatch.group(2);
          if (fiberValue != null) parsedFiber = double.tryParse(fiberValue);
        }
        
        // Extract sodium: "150mg sodium"
        final sodiumMatch = RegExp(r'(\d+\.?\d*)\s*mg?\s*sodium|sodium\s*(\d+\.?\d*)\s*mg?', caseSensitive: false).firstMatch(line);
        if (sodiumMatch != null) {
          final sodiumValue = sodiumMatch.group(1) ?? sodiumMatch.group(2);
          if (sodiumValue != null) parsedSodium = double.tryParse(sodiumValue);
        }
        
        // Extract sugar: "10g sugar"
        final sugarMatch = RegExp(r'(\d+\.?\d*)\s*g?\s*sugars?|sugars?\s*(\d+\.?\d*)\s*g?', caseSensitive: false).firstMatch(line);
        if (sugarMatch != null) {
          final sugarValue = sugarMatch.group(1) ?? sugarMatch.group(2);
          if (sugarValue != null) parsedSugar = double.tryParse(sugarValue);
        }
        
        continue; // Don't add nutrition line as ingredient
      }
      
      // Check for garnish line: "To garnish: ..." or "Garnish: ..."
      final garnishMatch = RegExp(
        r'^(?:to\s+)?garnish[:\s]+(.+)',
        caseSensitive: false,
      ).firstMatch(line);
      if (garnishMatch != null) {
        final garnishText = garnishMatch.group(1)?.trim() ?? '';
        if (garnishText.isNotEmpty) {
          // Parse garnish options (handle "X or Y" patterns)
          // "An orange twist or fresh berries" -> add both as options
          final garnishOptions = garnishText.split(RegExp(r'\s+or\s+', caseSensitive: false));
          for (final opt in garnishOptions) {
            final normalized = normalizeGarnish(opt.trim());
            if (normalized.isNotEmpty) {
              garnish.add(normalized);
            }
          }
        }
        continue; // Don't add as ingredient
      }
      
      // Check if line is clearly prose/narrative (not ingredient or direction)
      // Prose indicators: historical references, story words, long complex sentences
      final isProseNarrative = RegExp(
        r'\b(earliest|known|history|century|centuries|combined at|winter of|thames|froze|walking|streets|baskets|hogarth|included|etching|lane|british|book|contain|began|combination|strikes|beginnings|modern|flavor|pairing|mostly|because|really|good|if you add|spiraled|between|inside|hint|becomes|substitute)\b',
        caseSensitive: false,
      ).allMatches(lowerLine).length >= 2; // Need 2+ prose words to trigger

      // Check if line looks like an ingredient (with or without unit)
      final ingredientMatch = ingredientPattern.firstMatch(line);
      final ingredientNoUnitMatch = ingredientNoUnitPattern.firstMatch(line);
      final ingredientFractionMatch = ingredientFractionStartPattern.firstMatch(line);
      final hasIngredientPattern = ingredientMatch != null || ingredientNoUnitMatch != null || ingredientFractionMatch != null;
      final isNumberedStep = RegExp(r'^\d+[\.\)]\s').hasMatch(line);
      
      // Long prose lines (>80 chars with multiple sentences) are likely directions
      final isLongProse = line.length > 80 && RegExp(r'\.\s+[A-Z]').hasMatch(line);
      
      // Check if line STARTS with an action verb (strong direction indicator)
      final startsWithAction = RegExp(
        r'^(preheat|in a|line|place|pour|bake|cook|heat|let|transfer|cut|slice|dice|chop|mince|spread|frost|store|remove|serve|bring|add the|add|stir|whisk|combine|mix|garnish|shake|muddle|strain|fill|chill|lift|top with|float|rim|squeeze|express|dry shake|flatten|dredge|sauté|saute|fry|grill|roast|broil|steam|simmer|boil|layer|dot|lay|season|toss|coat|dust|brush|drizzle|beat|fold|knead|roll|shape|form|trim|melt|peel|core|seed|pit|hull|wash|rinse|drain|pat|dry|marinate|soak|bloom|proof|rise|rest|cool|warm|reserve|set aside|arrange|sprinkle|scatter|cover|wrap|refrigerate|freeze)',
        caseSensitive: false,
      ).hasMatch(lowerLine);
      
      // Check if line contains multiple cooking action words (likely a direction)
      final actionVerbCount = RegExp(
        r'\b(preheat|mix|stir|add|combine|bake|cook|heat|pour|whisk|fold|let|transfer|cut|slice|dice|chop|spread|frost|store|remove|serve|bring|minutes?|degrees?|°F|°C|oven|rack|bowl|until|batter|sauté|saute|fry|grill|roast|simmer|boil|steam|dredge|flatten|dip|layer|thickness)\b',
        caseSensitive: false,
      ).allMatches(lowerLine).length;
      
      // Check if line is clearly a direction fragment (partial sentence from directions)
      // This includes lines that have numbers/units but are clearly parts of directions
      // Examples: "meanwhile, remove 1", "Tbsp. zest and", "juice from lemons. In a medium"
      final isDirectionFragment = RegExp(
        r'\b(frosting on|layer and|the top of|cupcake back|and set|on it\b|with another|an extra|fill a|pastry bag|onto each|store the|in the center|airtight container|wire rack|cool completely|come out clean|bounce back|pressure is applied|center rack|paper liners|muffin tins?|thick batter|dry ingredients|continue mixing|meanwhile|from lemons|from limes|from oranges|zest and|juice and|zest from|juice from|in a medium|in a large|in a small|into a bowl)\b',
        caseSensitive: false,
      ).hasMatch(lowerLine);
      
      // Detect lines that LOOK like ingredients but are partial directions
      // "Tbsp. zest and" - starts with unit but continues with "and"
      // "1/2 of the mixture" - measurement but refers to "the mixture"
      // "remove 1" - action + number
      final looksLikeIngredientButIsDirection = RegExp(
        r'(^(tbsp|tsp|cup|oz|lb)s?\.?\s+\w+\s+and\b|the\s+(mixture|batter|dough|frosting|filling)|remove\s+\d|add\s+\d|use\s+\d|set\s+aside|remaining\s+\d|half\s+of\s+the|rest\s+of\s+the)',
        caseSensitive: false,
      ).hasMatch(lowerLine);
      
      final isLikelyDirection = actionVerbCount >= 2 || startsWithAction || isDirectionFragment || looksLikeIngredientButIsDirection;
      
      // Check if this looks like a prose fragment (tips, variations, narrative)
      // This check needs to happen BEFORE inIngredients check to avoid false positives
      final isProseFragment = RegExp(
        r'\b(if you|you add|you can|becomes a|it becomes|substitute|spiraled|between the|inside of|hint[-—]?put|whole lemon|lemon peel|lemon for|for lime)\b',
        caseSensitive: false,
      ).hasMatch(lowerLine);
      
      // Check if this looks like a direction continuation (not a standalone ingredient)
      // "with a lemon wedge" is part of "Garnish with a lemon wedge"
      // Also catch lines that continue a previous sentence (start lowercase, or start with common continuation patterns)
      // NOTE: "to X minutes" patterns are handled separately below as orphan time fragments
      final isDirectionContinuation = RegExp(
        r'^(with a|with the|in a|in an|on a|on the|into a|into the|over the|highball|cocktail|martini|rocks glass|coupe|marinate|covered|liquid|turn|and\s|or\s)',
        caseSensitive: false,
      ).hasMatch(lowerLine) ||
      // Line starts with lowercase letter (continuation of previous sentence)
      (line.isNotEmpty && line[0] == line[0].toLowerCase() && RegExp(r'^[a-z]').hasMatch(line));
      
      // Detect orphan time fragments like "to 60 minutes or until browned"
      // These are parts of directions that got split by OCR reading columns out of order
      // We SKIP these entirely - don't try to join them as they often join to the wrong direction
      final isOrphanTimeFragment = RegExp(
        r'^to\s+\d+\s*(minutes?|hours?|mins?|hrs?|seconds?|secs?)',
        caseSensitive: false,
      ).hasMatch(lowerLine);
      
      // Skip prose narrative, fragments, and orphan time fragments entirely
      if (isProseNarrative || isProseFragment || isOrphanTimeFragment) {
        continue;
      }
      
      // Direction continuations should be appended to previous direction
      // If there's no previous direction, SKIP the fragment entirely (it's orphaned OCR garbage)
      if (isDirectionContinuation) {
        if (rawDirections.isNotEmpty) {
          // Join to the last direction
          final updated = '${rawDirections.last} $line';
          rawDirections[rawDirections.length - 1] = updated;
          directions[directions.length - 1] = updated;
          inDirections = true;
          inIngredients = false;
        }
        // If no directions yet, just skip this orphan fragment
        continue;
      }

      if (isNumberedStep) {
        // Numbered step - definitely a direction
        // KEEP the number prefix for now - sorting happens in Phase 6.5
        final cleanedLine = _cleanDirectionLine(line);
        rawDirections.add(cleanedLine);
        directions.add(cleanedLine);
        inDirections = true;
        inIngredients = false;
      } else if (startsWithAction) {
        // Line STARTS with an action verb - definitely a direction
        final cleanedLine = _cleanDirectionLine(line);
        rawDirections.add(cleanedLine);
        directions.add(cleanedLine);
        inDirections = true;
        inIngredients = false;
      } else if (isLongProse || (isLikelyDirection && line.length > 15)) {
        // Long paragraph or line with cooking verbs - treat as direction
        // Lowered threshold to 15 chars to catch short direction lines
        paragraphDirections.add(line);
        inDirections = true;
        inIngredients = false;
      } else if (hasIngredientPattern && !isLikelyDirection) {
        // Matched ingredient pattern (with or without unit) AND doesn't look like a direction
        final parsed = _parseIngredientLine(line);
        // Skip garbage ingredients that are just metric column values
        // These have no real name (name is empty, just a unit, or just numbers)
        if (_isValidIngredient(parsed)) {
          rawIngredients.add(parsed);
          ingredients.add(Ingredient.create(
            name: parsed.name,
            amount: parsed.amount,
            unit: parsed.unit,
            preparation: parsed.preparation,
            alternative: parsed.alternative,
          ));
        }
        inIngredients = true;
        inDirections = false;
      } else if (inDirections || isLikelyDirection) {
        // In directions mode or line looks like a direction
        // Join to previous if: previous line doesn't end with sentence-ending punctuation,
        // or current line looks like a continuation (starts lowercase or with continuation word)
        final shouldJoinToPrevious = rawDirections.isNotEmpty && 
            !startsWithAction &&
            (
              // Previous line doesn't end with sentence-ending punctuation
              !RegExp(r'[.!?]$').hasMatch(rawDirections.last.trim()) ||
              // Current line starts lowercase (continuation)
              (line.isNotEmpty && RegExp(r'^[a-z]').hasMatch(line)) ||
              // Previous line is short (likely incomplete)
              rawDirections.last.length < 60
            );
        
        if (shouldJoinToPrevious) {
          final updated = '${rawDirections.last} $line';
          rawDirections[rawDirections.length - 1] = updated;
          directions[directions.length - 1] = updated;
        } else {
          paragraphDirections.add(line);
        }
        inDirections = true;
        inIngredients = false;
      } else if (inIngredients || hasIngredientPattern) {
        // In ingredients section or has ingredient pattern (with or without unit)
        final parsed = _parseIngredientLine(line);
        // Skip garbage ingredients that are just metric column values
        if (_isValidIngredient(parsed)) {
          rawIngredients.add(parsed);
          ingredients.add(Ingredient.create(
            name: parsed.name,
            amount: parsed.amount,
            unit: parsed.unit,
            preparation: parsed.preparation,
            alternative: parsed.alternative,
          ));
        }
      } else {
        // Ambiguous line - use heuristics
        // Short lines with food words are probably ingredients
        // Long lines with verbs are probably directions
        final hasActionVerb = RegExp(r'\b(preheat|mix|stir|add|combine|bake|cook|heat|pour|whisk|fold|let|transfer|cut|spread|frost|store|lift|garnish|serve|shake|muddle|strain|fill)\b', caseSensitive: false).hasMatch(lowerLine);
        
        // Fallback check: lines starting with fractions are almost always ingredients
        // This catches cases where patterns don't match due to encoding issues
        final startsWithFraction = RegExp(r'^[½¼¾⅓⅔⅛⅜⅝⅞1-9]').hasMatch(line.trim());
        
        if (startsWithFraction && !hasActionVerb && line.length < 60) {
          // Line starts with a fraction/number and has no action verb - treat as ingredient
          final parsed = _parseIngredientLine(line);
          // Skip garbage ingredients that are just metric column values
          if (_isValidIngredient(parsed)) {
            rawIngredients.add(parsed);
            ingredients.add(Ingredient.create(
              name: parsed.name,
              amount: parsed.amount,
              unit: parsed.unit,
              preparation: parsed.preparation,
              alternative: parsed.alternative,
            ));
            inIngredients = true;
          }
        } else if (hasActionVerb) {
          // Line with action verb - treat as direction
          paragraphDirections.add(line);
        } else if (line.length < 60) {
          // Assume short lines without action verbs are ingredients
          final parsed = _parseIngredientLine(line);
          // Only add if it has an amount or looks like an ingredient AND is valid
          if ((parsed.amount != null || parsed.looksLikeIngredient) && _isValidIngredient(parsed)) {
            rawIngredients.add(RawIngredientData(
              original: line,
              name: parsed.name,
              amount: parsed.amount,
              unit: parsed.unit,
              bakerPercent: parsed.bakerPercent,
              alternative: parsed.alternative,
              looksLikeIngredient: parsed.amount != null,
            ));
            ingredients.add(Ingredient.create(
              name: parsed.name,
              amount: parsed.amount,
              unit: parsed.unit,
              preparation: parsed.preparation,
              alternative: parsed.alternative,
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
          r'\b(if you|you can|becomes a|it becomes|substitute|hint)\b',
          caseSensitive: false,
        ).hasMatch(lowerSentence);
        
        if (isTipOrVariation) {
          continue;
        }
        
        // Include short sentences or sentences with action verbs
        // Short direct instructions like "Lift instead of stir" should be included
        final hasAction = RegExp(
          r'\b(combine|stir|mix|add|pour|bake|cook|heat|garnish|serve|lift|shake|muddle|strain|fill|chill|refrigerate|freeze|instead|slice|dice|chop|cut|sauté|saute|fry|grill|roast|simmer|boil|steam|dredge|flatten|dip|layer|dot|lay|place|spread|remove|transfer|toss|arrange|drain|whisk|fold|beat|knead|roll|shape|form|brush|drizzle|sprinkle|scatter|cover|wrap|season|coat|dust|top|set|let|allow|cool|warm|rest|marinate)\b',
          caseSensitive: false,
        ).hasMatch(lowerSentence);
        
        if (trimmed.isNotEmpty && trimmed.length > 10 && trimmed.contains(' ') && (hasAction || trimmed.length < 50)) {
          rawDirections.add(trimmed);
          directions.add(trimmed);
        }
      }
    }

    // ===== PHASE 6.5: Post-process directions - split on periods, filter prose =====
    // Directions may have been concatenated; split them into individual steps
    final processedDirections = <String>[];
    final proseFragmentPattern = RegExp(
      r'\b(if you|you add|you can|becomes a|it becomes|substitute|spiraled|between the|inside of|hint|the drink|it in before)\b',
      caseSensitive: false,
    );
    
    // Time/storage info pattern - these are metadata, not direction steps
    // "HANDS ON 20 minutes BAKE 45 minutes at 350F Refrigerate in an airtight container..."
    final timeStoragePattern = RegExp(
      r'^(hands on|prep time|cook time|bake time|total time|refrigerate in|store in|makes\s+\d|yields\s+\d|serves\s+\d)',
      caseSensitive: false,
    );
    
    for (final direction in rawDirections) {
      // Skip lines that are time/storage metadata, not actual directions
      if (timeStoragePattern.hasMatch(direction.trim().toLowerCase())) {
        continue;
      }
      
      // Split on period followed by space and capital letter, or period at end
      final sentences = direction.split(RegExp(r'(?<=\.)\s+(?=[A-Z])|(?<=\.)\s*$'));
      
      for (final sentence in sentences) {
        final trimmed = sentence.trim();
        if (trimmed.isEmpty || trimmed.length < 10) continue;
        
        // Skip single-word lines (likely OCR garbage or orphaned fragments)
        if (!trimmed.contains(' ')) continue;
        
        // Skip prose fragments
        if (proseFragmentPattern.hasMatch(trimmed.toLowerCase())) {
          continue;
        }
        
        processedDirections.add(trimmed);
      }
    }
    
    // Sort numbered directions (e.g., "1. Preheat oven...", "2. Mix flour...")
    // Directions may come in wrong order due to OCR reading columns left-to-right
    // Also handle "1)" and "Step 1:" formats
    final numberedPattern = RegExp(r'^(?:step\s*)?(\d+)[\.\):\s]\s*', caseSensitive: false);
    final numberedDirections = <int, String>{};
    final unnumberedDirections = <String>[];
    
    for (final direction in processedDirections) {
      final match = numberedPattern.firstMatch(direction);
      if (match != null) {
        final num = int.parse(match.group(1)!);
        // Remove the number prefix for cleaner output
        final text = direction.substring(match.end).trim();
        if (text.isNotEmpty) {
          // If we already have this step number, append (OCR may have split one step)
          if (numberedDirections.containsKey(num)) {
            numberedDirections[num] = '${numberedDirections[num]} $text';
          } else {
            numberedDirections[num] = text;
          }
        }
      } else {
        unnumberedDirections.add(direction);
      }
    }
    
    // Build final directions: sorted numbered first, then unnumbered
    final sortedDirections = <String>[];
    if (numberedDirections.isNotEmpty) {
      final sortedNums = numberedDirections.keys.toList()..sort();
      for (final num in sortedNums) {
        sortedDirections.add(numberedDirections[num]!);
      }
    }
    sortedDirections.addAll(unnumberedDirections);
    
    // Replace rawDirections and directions with processed versions
    // Capitalize first letter of each direction for proper sentence formatting
    rawDirections.clear();
    directions.clear();
    for (final direction in sortedDirections) {
      final capitalized = direction.isNotEmpty 
          ? direction[0].toUpperCase() + direction.substring(1)
          : direction;
      rawDirections.add(capitalized);
      directions.add(capitalized);
    }

    // ===== PHASE 6.75: Pair metric values with ingredients =====
    // If we collected metric values from a two-column layout, pair them with ingredients
    // by position (1st metric → 1st ingredient, 2nd metric → 2nd ingredient, etc.)
    if (metricValues.isNotEmpty && rawIngredients.isNotEmpty) {
      // Only pair if counts are reasonably close (allow some tolerance for items like "Salt and pepper")
      final countDiff = (metricValues.length - rawIngredients.length).abs();
      final shouldPair = countDiff <= 2 || 
          (metricValues.length >= rawIngredients.length * 0.7 && 
           metricValues.length <= rawIngredients.length * 1.3);
      
      if (shouldPair) {
        for (int i = 0; i < rawIngredients.length && i < metricValues.length; i++) {
          final metric = metricValues[i];
          final existing = rawIngredients[i];
          
          // Add metric as a note/preparation field
          final metricNote = metric;
          final newPrep = existing.preparation != null && existing.preparation!.isNotEmpty
              ? '${existing.preparation}; $metricNote'
              : metricNote;
          
          // Create updated RawIngredientData with metric note
          rawIngredients[i] = RawIngredientData(
            original: existing.original,
            name: existing.name,
            amount: existing.amount,
            unit: existing.unit,
            preparation: newPrep,
            bakerPercent: existing.bakerPercent,
            alternative: existing.alternative,
            looksLikeIngredient: existing.looksLikeIngredient,
            isSection: existing.isSection,
            sectionName: existing.sectionName,
          );
          
          // Also update the Ingredient object's preparation
          if (i < ingredients.length) {
            ingredients[i] = Ingredient.create(
              name: ingredients[i].name,
              amount: ingredients[i].amount,
              unit: ingredients[i].unit,
              preparation: newPrep,
            );
          }
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
    
    // Build nutrition info if any values were parsed
    NutritionInfo? parsedNutrition;
    if (parsedCalories != null || parsedFat != null || parsedCarbs != null || 
        parsedProtein != null || parsedFiber != null || parsedSodium != null || parsedSugar != null) {
      parsedNutrition = NutritionInfo.create(
        servingSize: parsedServingSize,
        calories: parsedCalories,
        fatContent: parsedFat,
        carbohydrateContent: parsedCarbs,
        proteinContent: parsedProtein,
        fiberContent: parsedFiber,
        sodiumContent: parsedSodium,
        sugarContent: parsedSugar,
      );
    }

    return RecipeImportResult(
      name: name,
      course: course,
      serves: serves,
      time: time,
      notes: notes,
      ingredients: ingredients,
      directions: directions,
      garnish: garnish,
      nutrition: parsedNutrition,
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
      timeConfidence: timeConfidence,
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
  /// - Dual column: "4 breasts of chicken, de-boned 4" (trailing metric column)
  RawIngredientData _parseIngredientLine(String line) {
    // Strip trailing metric column numbers that OCR merged from two-column layouts
    // Pattern: line ends with a standalone number (or number+unit like "4" or "120 ml")
    // that duplicates or converts the leading amount
    final metricResult = _stripTrailingMetricColumn(line);
    final cleanedLine = metricResult.cleanedLine;
    final metricNote = metricResult.metricNote;
    
    // Normalize fractions in the line before parsing (1/2 → ½)
    final normalizedLine = IngredientParser.normalizeFractions(cleanedLine);
    
    // Use the shared IngredientParser for consistent parsing
    final parsed = IngredientParser.parse(normalizedLine);
    
    // Normalize units using UnitNormalizer for consistent display
    final normalizedUnit = parsed.unit != null 
        ? UnitNormalizer.normalize(parsed.unit)
        : null;
    
    // Combine parser's preparation with any extracted metric note
    String? finalPreparation = parsed.preparation;
    if (metricNote != null && metricNote.isNotEmpty) {
      finalPreparation = finalPreparation != null 
          ? '$finalPreparation ($metricNote)'
          : metricNote;
    }
    
    // Convert ParsedIngredient to RawIngredientData
    return RawIngredientData(
      original: parsed.original.isNotEmpty ? parsed.original : line,
      name: _cleanIngredientName(parsed.name.isNotEmpty ? parsed.name : line),
      amount: parsed.amount,
      unit: normalizedUnit,
      preparation: finalPreparation,
      bakerPercent: parsed.bakerPercent,
      alternative: parsed.alternative,
      isSection: parsed.isSection,
      sectionName: parsed.sectionName,
      looksLikeIngredient: parsed.looksLikeIngredient,
    );
  }
  
  /// Check if a parsed ingredient is valid (not just garbage from metric column)
  /// 
  /// Filters out lines like "4 Tbs.", "1Tbs.", "120 ml", "65 g" that are just
  /// metric column values OCR'd separately from the main ingredient.
  bool _isValidIngredient(RawIngredientData parsed) {
    final name = parsed.name.trim().toLowerCase();
    
    // Empty name is invalid
    if (name.isEmpty) return false;
    
    // Name is just a unit abbreviation (with optional period/plural)
    // "Tbs", "Tbs.", "tsp", "oz", "ml", "g", "kg", "lb", "C", etc.
    final isJustUnit = RegExp(
      r'^(tbs\.?|tbsp\.?|tsp\.?|oz\.?|ml\.?|g\.?|kg\.?|lb\.?|lbs\.?|c\.?|l\.?|cl\.?|cups?\.?|teaspoons?\.?|tablespoons?\.?|ounces?\.?|pounds?\.?|grams?\.?|liters?\.?|litres?\.?|milliliters?\.?|millilitres?\.?)$',
      caseSensitive: false,
    ).hasMatch(name);
    if (isJustUnit) return false;
    
    // Name is just numbers (metric column count like "2", "1", "4")
    if (RegExp(r'^\d+$').hasMatch(name)) return false;
    
    // Name is just a number + unit that got parsed wrong
    // e.g., "4tbs" parsed as name "4tbs" with no amount
    if (RegExp(r'^\d+\s*(tbs|tbsp|tsp|oz|ml|g|kg|lb|c|l)\.?$', caseSensitive: false).hasMatch(name)) {
      return false;
    }
    
    // Very short name (1-2 chars) that's not a known short ingredient
    // Single letters or digits are likely garbage
    if (name.length <= 2 && !RegExp(r'^(ok|lo)$', caseSensitive: false).hasMatch(name)) {
      return false;
    }
    
    return true;
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
  
  /// Strip trailing metric column values from two-column cookbook layouts
  /// 
  /// Many cookbooks have dual columns: "4 oz. butter" (US) and "120 g" (Metric)
  /// OCR often merges these: "4 oz. butter 120 g" or "4 breasts of chicken 4"
  /// 
  /// This detects and removes trailing metric measurements.
  /// - Duplicate counts are discarded (redundant info)
  /// - Different metric units are preserved as notes (useful conversion info)
  ({String cleanedLine, String? metricNote}) _stripTrailingMetricColumn(String line) {
    // Pattern 0: Mid-line metric garbage from two-column OCR merge
    // "Remove the fennel to a 2Tbs." -> OCR merged direction with metric column
    // "... into a 120 ml" or "to a 4 Tbsp" patterns
    // Strip "to a X(unit)" where X is a number and unit is optional
    final midLineMetricMatch = RegExp(
      r'\s+to\s+a\s+\d+\s*(Tbs\.?|Tbsp\.?|tsp\.?|oz\.?|g|ml|kg|l)?\s*\.?\s*$',
      caseSensitive: false,
    ).firstMatch(line);
    if (midLineMetricMatch != null) {
      // Remove the mid-line metric garbage
      return (cleanedLine: line.substring(0, midLineMetricMatch.start).trim(), metricNote: null);
    }
    
    // Pattern 1: Trailing standalone number (same as leading amount)
    // "4 breasts of chicken, de-boned and skinned 4" -> remove trailing "4"
    // This is redundant info, so discard it (no note)
    // Also handle OCR reading "4" as "a" or "A" at end of line
    final leadingAmountMatch = RegExp(r'^(\d+)').firstMatch(line);
    if (leadingAmountMatch != null) {
      final leadingAmount = leadingAmountMatch.group(1)!;
      // Check if line ends with the same number OR a stray letter (OCR artifact)
      final trailingPattern = RegExp('\\s+($leadingAmount|[aA])\$');
      final trailingMatch = trailingPattern.firstMatch(line);
      if (trailingMatch != null) {
        return (cleanedLine: line.substring(0, trailingMatch.start).trim(), metricNote: null);
      }
    }
    
    // Pattern 2: Trailing metric measurement (number + metric unit)
    // "4 oz. butter 120 g" -> remove "120 g" but preserve as note
    // "1 cup flour 65 g" -> remove "65 g" but preserve as note
    // "3 oz. cream 90 ml" -> remove "90 ml" but preserve as note
    final trailingMetricMatch = RegExp(
      r'\s+(\d+\s*(?:g|kg|ml|l|cl))\s*$',
      caseSensitive: false,
    ).firstMatch(line);
    if (trailingMetricMatch != null) {
      // Only strip if there's substantial content before it
      final beforeMetric = line.substring(0, trailingMetricMatch.start);
      if (beforeMetric.length > 10) {
        final metricValue = trailingMetricMatch.group(1)?.trim();
        return (cleanedLine: beforeMetric.trim(), metricNote: metricValue);
      }
    }
    
    // Pattern 3: Trailing fraction that duplicates leading amount
    // "½ cup butter ½" -> remove trailing "½" (redundant, no note)
    final leadingFractionMatch = RegExp(r'^([\d½¼¾⅓⅔]+)').firstMatch(line);
    if (leadingFractionMatch != null) {
      final leadingFrac = leadingFractionMatch.group(1)!;
      // Escape special regex chars in fraction
      final escaped = leadingFrac.replaceAll(r'½', r'½').replaceAll(r'¼', r'¼').replaceAll(r'¾', r'¾');
      final trailingFracMatch = RegExp('\\s+$escaped\\s*\$').firstMatch(line);
      if (trailingFracMatch != null) {
        return (cleanedLine: line.substring(0, trailingFracMatch.start).trim(), metricNote: null);
      }
    }
    
    return (cleanedLine: line, metricNote: null);
  }
  
  /// Clean direction lines by removing metric garbage from OCR two-column merges
  /// 
  /// Examples:
  /// - "Remove the fennel to a 2Tbs." -> "Remove the fennel."
  /// - "Trim the outer leaves to a 4 oz" -> "Trim the outer leaves."
  String _cleanDirectionLine(String line) {
    // Strip mid-line metric garbage: "to a X(unit)" patterns
    final cleaned = RegExp(
      r'\s+to\s+a\s+\d+\s*(Tbs\.?|Tbsp\.?|tsp\.?|oz\.?|g|ml|kg|l)?\s*\.?\s*$',
      caseSensitive: false,
    ).hasMatch(line)
        ? line.replaceFirst(
            RegExp(r'\s+to\s+a\s+\d+\s*(Tbs\.?|Tbsp\.?|tsp\.?|oz\.?|g|ml|kg|l)?\s*\.?\s*$', caseSensitive: false),
            '.')
        : line;
    return cleaned.trim();
  }
  
  /// Fix common OCR artifacts and misreadings
  String _fixOcrArtifacts(String text) {
    var fixed = text;
    
    // Fix merged count + size for canned goods: "119 oz. tin" -> "1 19 oz. tin"
    // OCR often merges the count (1) with the size (19 oz) for cans/tins
    // Pattern: 3-digit number followed by oz/ml and then tin/can/jar
    // Common sizes: 14oz, 15oz, 19oz, 28oz - so 114, 115, 119, 128 etc are likely merged
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b(1)(14|15|19|28|29)\s*(oz\.?|ml\.?)\s*(tin|can|jar)\b', caseSensitive: false),
      (m) => '${m.group(1)} ${m.group(2)} ${m.group(3)} ${m.group(4)}',
    );
    
    // Normalize Unicode fraction characters to standard forms
    // OCR may produce various Unicode representations that look the same but are different
    // U+00BD (½) is the standard, but OCR might produce other variants
    // Also normalize fraction slash combinations: "1⁄2" (U+2044 fraction slash) -> "½"
    fixed = fixed.replaceAll('\u2044', '/'); // Fraction slash to regular slash
    fixed = fixed.replaceAll('\u2215', '/'); // Division slash to regular slash
    
    // Normalize composed fractions (superscript/subscript combinations)
    fixed = fixed.replaceAll('\u00B9\u2044\u2082', '½'); // ¹⁄₂ -> ½
    fixed = fixed.replaceAll('\u00B9\u2044\u2084', '¼'); // ¹⁄₄ -> ¼
    fixed = fixed.replaceAll('\u00B3\u2044\u2084', '¾'); // ³⁄₄ -> ¾
    
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
    
    // Fix "Va" or "va" being read instead of ½ (common OCR misread)
    // "Va cup" -> "½ cup", "Vacup" -> "½ cup"
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b[Vv]a\s*(cups?|tbsps?|tsps?|oz|lbs?|pounds?|ounces?|teaspoons?|tablespoons?)', caseSensitive: false),
      (m) => '½ ${m.group(1)}',
    );
    
    // Fix "l/2" or "I/2" being read instead of ½ (OCR reads 1 as l or I)
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b[lI]\s*/\s*2\b'),
      (m) => '½',
    );
    
    // Fix "2/4" -> ½ (non-reduced fraction)
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b2\s*/\s*4\b'),
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
    
    // Fix "0z" or "0z." being read instead of "oz" (OCR reads 'o' as '0')
    // "4 0z. butter" -> "4 oz. butter"
    // Also handles "70z" where OCR merged number with unit: "1 7oz" -> "1 7 oz" handled below
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b0z\.?\b', caseSensitive: false),
      (m) => 'oz',
    );
    
    // Fix digit followed by 0z (e.g., "70z" -> "7 oz", "40z" -> "4 oz")
    // OCR reads "7oz" or "7 oz" as "70z" (o -> 0)
    fixed = fixed.replaceAllMapped(
      RegExp(r'(\d)0z\.?', caseSensitive: false),
      (m) => '${m.group(1)} oz',
    );
    
    // Fix "Tbsps." or "tbsps." -> normalize periods in unit abbreviations
    // OCR sometimes adds extra periods or 's' to units
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b[Tt]bsps?\.', caseSensitive: false),
      (m) => 'Tbsp',
    );
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b[Tt]sps?\.', caseSensitive: false),
      (m) => 'tsp',
    );
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b[Oo]z\.', caseSensitive: false),
      (m) => 'oz',
    );
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b[Ll]bs?\.', caseSensitive: false),
      (m) => 'lb',
    );
    
    // Fix number+unit with no space: "7CUP" -> "7 CUP", "1CUP" -> "1 CUP"
    fixed = fixed.replaceAllMapped(
      RegExp(r'(\d)(cup|cups|teaspoon|teaspoons|tsp|tablespoon|tablespoons|tbsp|oz|lb|lbs|pound|pounds|ounce|ounces)\b', caseSensitive: false),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    
    // Fix fraction directly attached to word: "½corn" -> "½ corn", "¼cup" -> "¼ cup"
    // This ensures fractions always have space before the ingredient/unit name
    fixed = fixed.replaceAllMapped(
      RegExp(r'([½¼¾⅓⅔⅛⅜⅝⅞])([a-zA-Z])'),
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
    
    // Fix lowercase 'l' being read as '1' when followed by unit
    // "l cup" -> "1 cup", "l tsp" -> "1 tsp"
    fixed = fixed.replaceAllMapped(
      RegExp(r'(^|\n|\s)l\s+(cups?\.?|tbsps?\.?|tbs\.?|tsps?\.?|oz\.?|lbs?\.?|pounds?\.?|ounces?\.?|teaspoons?\.?|tablespoons?\.?|parts?\.?|g\.?|kg\.?|ml\.?|c\.|t\.)\b', caseSensitive: false),
      (m) => '${m.group(1)}1 ${m.group(2)}',
    );
    
    // Fix lowercase 'l' or uppercase 'L' being read as '1' when followed by size descriptor
    // "l small eggplant" -> "1 small eggplant", "L large onion" -> "1 large onion"
    fixed = fixed.replaceAllMapped(
      RegExp(r'(^|\n|\s)[lL]\s+(small|medium|large|clove|head|bunch|sprig|stalk|can|package|pkg|slice|piece)\b', caseSensitive: false),
      (m) => '${m.group(1)}1 ${m.group(2)}',
    );
    
    // Fix lowercase 'l' or uppercase 'L' being read as '1' when followed by common ingredients
    // "l onion" -> "1 onion", "l egg" -> "1 egg", "l lemon" -> "1 lemon"
    // Be careful not to match legitimate words starting with 'l' (like "large")
    fixed = fixed.replaceAllMapped(
      RegExp(r'(^|\n|\s)[lL]\s+(onion|egg|lemon|lime|orange|apple|banana|potato|tomato|carrot|celery|garlic|pepper|cucumber|avocado|mango|pear|peach|plum|cherry|grape|strawberry|raspberry|blueberry|cranberry|melon|watermelon|grapefruit|tangerine|kiwi|papaya|pineapple|coconut|fig|date|prune|apricot|nectarine|persimmon)\b', caseSensitive: false),
      (m) => '${m.group(1)}1 ${m.group(2)}',
    );
    
    // Fix stylized floral bullets (❧) being misread as letters at start of ingredient lines
    // Common OCR misreadings: "t 1 part" -> "1 part", "fl part" -> "1 part", "f4 parts" -> "4 parts"
    // Also handles: "T 1 part", "P 2 parts", "A 1 part", etc.
    // Pattern: letter(s) + space + digit + space + "part(s)" or unit
    fixed = fixed.replaceAllMapped(
      RegExp(r'(^|\n)[TtFfPpAa]l?\s*(\d+)\s+(parts?|oz|ml)\b', multiLine: true, caseSensitive: false),
      (m) => '${m.group(1)}${m.group(2)} ${m.group(3)}',
    );
    
    // Fix "fl" or "Fl" directly attached to unit: "fl part" -> "1 part" (common OCR misread of ❧1)
    // This catches when OCR reads the bullet as "f" and "1" as "l"
    fixed = fixed.replaceAllMapped(
      RegExp(r'(^|\n)[Ff]l\s+(parts?|oz|ml)\b', multiLine: true, caseSensitive: false),
      (m) => '${m.group(1)}1 ${m.group(2)}',
    );
    
    // Fix "f" or "t" directly attached to number: "f4" -> "4", "t1" -> "1" (bullet artifact)
    fixed = fixed.replaceAllMapped(
      RegExp(r'(^|\n)[FfTt](\d+)\s+(parts?|oz|ml)\b', multiLine: true, caseSensitive: false),
      (m) => '${m.group(1)}${m.group(2)} ${m.group(3)}',
    );
    
    // Fix "crème" OCR issues - normalize accented characters
    // "crรจme" might be read as "creme", "crรฉme", etc.
    fixed = fixed.replaceAll(RegExp(r'cr[eรจรฉรช]me', caseSensitive: false), 'crรจme');
    
    // Fix merged unit+word patterns where OCR doesn't add space:
    // "cuppowdered" -> "cup powdered", "cupall-purpose" -> "cup all-purpose"
    // "tbspunsalted" -> "tbsp unsalted", "tspvanilla" -> "tsp vanilla"
    fixed = fixed.replaceAllMapped(
      RegExp(r'(cups?|tbsps?|tsps?|teaspoons?|tablespoons?|oz|lbs?|pounds?|ounces?)((?!s\b)[a-z]{3,})', caseSensitive: false),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    
    // Split merged garnish lines: "wheat beerTo garnish:" -> "wheat beer\nTo garnish:"
    // OCR often merges ingredient with garnish instruction on same line
    // Also handles "wheat beer Garnish:" (no "To")
    fixed = fixed.replaceAllMapped(
      RegExp(r'(\b\w{3,})((?:To\s+)?[Gg]arnish[:\s])', caseSensitive: false),
      (m) => '${m.group(1)}\n${m.group(2)}',
    );
    
    // Fix OCR reading capital "I" as "1" when attached to word start:
    // "1cing" -> "Icing", "1talian" -> "Italian", "1ce" -> "Ice"
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b1(cing|talian|ce|ris[hk]|ndian|ndonesian)\b', caseSensitive: false),
      (m) => 'I${m.group(1)}',
    );
    
    // Fix OCR reading "Fl" or "TỊ" or "Tl" as Flour artifacts:
    // "TỊOur" -> "Flour", "TlOur" -> "Flour", "FlOur" -> "Flour"
    fixed = fixed.replaceAllMapped(
      RegExp(r'\b[TtFf][ỊlLI][oO][uU][rR]\b'),
      (m) => 'Flour',
    );
    
    // Fix OCR reading "l" as "[" in "lbs":
    // "[bs" -> "lbs", "[b" -> "lb"
    fixed = fixed.replaceAllMapped(
      RegExp(r'\[(bs?)\b'),
      (m) => 'l${m.group(1)}',
    );
    
    // Fix mixed case in common words (OCR artifacts):
    // "sOItened" -> "softened", "sOftened" -> "softened"
    fixed = fixed.replaceAllMapped(
      RegExp(r'\bs[oO][fIl][tT]ened\b', caseSensitive: false),
      (m) => 'softened',
    );
    
    // Fix "mELted" or "mElted" -> "melted"
    fixed = fixed.replaceAllMapped(
      RegExp(r'\bm[eE][lL][tT]ed\b', caseSensitive: false),
      (m) => 'melted',
    );
    
    // Fix "chopped" OCR variants
    fixed = fixed.replaceAllMapped(
      RegExp(r'\bch[oO][pP][pP]ed\b', caseSensitive: false),
      (m) => 'chopped',
    );
    
    // Fix "minced" OCR variants
    fixed = fixed.replaceAllMapped(
      RegExp(r'\bm[iI][nN]ced\b', caseSensitive: false),
      (m) => 'minced',
    );
    
    // Fix "diced" OCR variants
    fixed = fixed.replaceAllMapped(
      RegExp(r'\bd[iI]ced\b', caseSensitive: false),
      (m) => 'diced',
    );
    
    // Split merged ingredient+direction lines (MUST be after word fixes like softened):
    // "butter softened bake at 350" -> "butter softened\nbake at 350"
    // "flour sifted preheat oven" -> "flour sifted\npreheat oven"
    // Pattern: word ending + cooking action verb + preposition
    fixed = fixed.replaceAllMapped(
      RegExp(r'(\b\w{3,})\s+(bake|preheat|cook|roast|grill|broil|fry|saute|simmer|boil|steam|mix|combine|stir|whisk|beat|fold|pour|spread|let|place|remove|set|turn|cover|refrigerate|chill|freeze|cool|rest|allow)\s+(at|for|the|in|on|to|until|over)\b', caseSensitive: false),
      (m) => '${m.group(1)}\n${m.group(2)} ${m.group(3)}',
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
