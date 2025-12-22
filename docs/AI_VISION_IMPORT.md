# AI Vision Import - Design Document 

**Feature:** Enhance Image Import (LLM-Assisted)
**Language:** Uses a user-provided AI service to assist with complex image parsing. Memoix does not retain images or extracted content.

**Status:** Planned (Post F&F Test)  
**Priority:** Medium  
**Target:** v1.1+

---

## Overview

Add an AI-powered image import option that uses vision-capable LLMs (GPT-4o, Claude) to extract recipe data from complex images that standard OCR cannot handle, such as:

- Professional cookbook pages with tables
- Multi-column layouts
- Handwritten recipes with unusual formatting
- Recipe cards with decorative backgrounds
- Screenshots of recipes from apps/websites

## User Flow

```
Settings → AI Features (new section)
├── API Provider: [OpenAI / Anthropic / None]
├── API Key: [Secure text field] [Test Connection] [Clear]
└── Note: "Your API key is stored locally and never sent to Memoix servers"

Import Screen (only when API key is configured):
├── From Camera
├── From Gallery
├── Multi-Page Scan
├── AI Vision Import ← NEW option, only visible if key configured
└── From URL
```

### AI Vision Import Flow

1. **Capture/Select Image**
   - Camera capture with preview
   - Gallery selection (single image for v1, multi-image later)

2. **Send to AI Provider**
   - Show loading indicator with "Analyzing image..."
   - Send image with structured prompt (see below)
   - Handle rate limits, errors gracefully

3. **Parse Response**
   - Extract JSON from AI response
   - Validate required fields (name, ingredients OR directions)
   - Convert to `RecipeImportResult`

4. **Review Screen**
   - Standard import review screen
   - User can edit/correct any fields
   - Save to appropriate recipe type

---

## Technical Architecture

### New Files

```
lib/
├── core/
│   └── services/
│       └── ai_vision_service.dart      # Core AI integration
├── features/
│   └── settings/
│       └── screens/
│           └── ai_settings_screen.dart # API key management UI
│       └── services/
│           └── ai_key_storage.dart     # Secure key storage
```

### AI Vision Service

```dart
// lib/core/services/ai_vision_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

enum AIProvider { openai, anthropic }

class AIVisionService {
  static const int _maxImageSizeBytes = 20 * 1024 * 1024; // 20MB limit
  
  final AIProvider provider;
  final String apiKey;
  
  AIVisionService({required this.provider, required this.apiKey});
  
  /// Extract recipe from image using AI vision
  Future<Map<String, dynamic>> extractRecipeFromImage(File imageFile) async {
    // Validate image size
    final fileSize = await imageFile.length();
    if (fileSize > _maxImageSizeBytes) {
      throw AIVisionException('Image too large. Maximum size is 20MB.');
    }
    
    // Encode image to base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = _getMimeType(imageFile.path);
    
    // Send to appropriate provider
    switch (provider) {
      case AIProvider.openai:
        return _extractWithOpenAI(base64Image, mimeType);
      case AIProvider.anthropic:
        return _extractWithAnthropic(base64Image, mimeType);
    }
  }
  
  Future<Map<String, dynamic>> _extractWithOpenAI(String base64Image, String mimeType) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': _systemPrompt},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$base64Image',
                  'detail': 'high',
                },
              },
            ],
          },
        ],
        'max_tokens': 4096,
        'response_format': {'type': 'json_object'},
      }),
    );
    
    if (response.statusCode != 200) {
      throw AIVisionException(_parseOpenAIError(response));
    }
    
    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'];
    return jsonDecode(content);
  }
  
  Future<Map<String, dynamic>> _extractWithAnthropic(String base64Image, String mimeType) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 4096,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': mimeType,
                  'data': base64Image,
                },
              },
              {'type': 'text', 'text': _systemPrompt},
            ],
          },
        ],
      }),
    );
    
    if (response.statusCode != 200) {
      throw AIVisionException(_parseAnthropicError(response));
    }
    
    final data = jsonDecode(response.body);
    final content = data['content'][0]['text'];
    return jsonDecode(content);
  }
  
  String get _systemPrompt => '''
Extract the recipe from this image and return it as JSON with this exact structure:

{
  "name": "Recipe Name",
  "course": "mains|apps|desserts|drinks|baking|sides|sauces|soup|brunch|pickles|rubs|vegn",
  "cuisine": "Optional cuisine type",
  "serves": "4 servings or similar",
  "time": "Total time like 1h 30m",
  "ingredients": [
    {
      "section": "Optional section name like 'For the Sauce'",
      "amount": "2",
      "unit": "cups",
      "name": "flour",
      "preparation": "sifted",
      "bakerPercent": "100" 
    }
  ],
  "directions": [
    "Step 1 description",
    "Step 2 description"
  ],
  "notes": "Any tips, variations, or additional notes"
}

Rules:
- Include ALL ingredients, preserving section groupings if present
- Include ALL directions/steps in order
- For baker's percentages, include them if visible (common in bread recipes)
- Normalize units: use "Tbsp", "tsp", "C" (cup), "g", "oz", "lb", "ml", "L"
- Convert fractions to unicode: ½ ⅓ ¼ ⅔ ¾
- If the recipe type is clearly modernist/molecular, smoking/BBQ, pizza, or sandwich, still use this format
- Return ONLY valid JSON, no markdown or explanation

Handling ambiguous or unclear content:
- Amounts/measurements: OMIT if unclear - wrong amounts can ruin recipes
- Ingredient names: Use best interpretation with context clues
- Directions: Include if reasonably clear, omit steps that are truly illegible
- Metadata (serves, time, cuisine): Include only if explicitly stated, omit if not visible
- When in doubt about a quantity, omit the amount field but include the ingredient name
''';
  
  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
  
  String _parseOpenAIError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['error']['message'] ?? 'OpenAI API error: ${response.statusCode}';
    } catch (_) {
      return 'OpenAI API error: ${response.statusCode}';
    }
  }
  
  String _parseAnthropicError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['error']['message'] ?? 'Anthropic API error: ${response.statusCode}';
    } catch (_) {
      return 'Anthropic API error: ${response.statusCode}';
    }
  }
}

class AIVisionException implements Exception {
  final String message;
  AIVisionException(this.message);
  
  @override
  String toString() => message;
}
```

### Secure Key Storage

```dart
// lib/features/settings/services/ai_key_storage.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AIKeyStorage {
  static const _storage = FlutterSecureStorage();
  static const _openaiKey = 'ai_openai_key';
  static const _anthropicKey = 'ai_anthropic_key';
  static const _preferredProvider = 'ai_preferred_provider';
  
  static Future<String?> getOpenAIKey() async {
    return await _storage.read(key: _openaiKey);
  }
  
  static Future<void> setOpenAIKey(String key) async {
    await _storage.write(key: _openaiKey, value: key);
  }
  
  static Future<void> clearOpenAIKey() async {
    await _storage.delete(key: _openaiKey);
  }
  
  static Future<String?> getAnthropicKey() async {
    return await _storage.read(key: _anthropicKey);
  }
  
  static Future<void> setAnthropicKey(String key) async {
    await _storage.write(key: _anthropicKey, value: key);
  }
  
  static Future<void> clearAnthropicKey() async {
    await _storage.delete(key: _anthropicKey);
  }
  
  static Future<String?> getPreferredProvider() async {
    return await _storage.read(key: _preferredProvider);
  }
  
  static Future<void> setPreferredProvider(String provider) async {
    await _storage.write(key: _preferredProvider, value: provider);
  }
  
  static Future<bool> hasAnyKey() async {
    final openai = await getOpenAIKey();
    final anthropic = await getAnthropicKey();
    return (openai != null && openai.isNotEmpty) || 
           (anthropic != null && anthropic.isNotEmpty);
  }
}
```

### Response Parsing

```dart
// Add to lib/core/services/ai_vision_service.dart or separate file

RecipeImportResult parseAIResponse(Map<String, dynamic> json) {
  // Parse ingredients
  final ingredientsList = (json['ingredients'] as List?) ?? [];
  final ingredients = <Ingredient>[];
  String? currentSection;
  
  for (final item in ingredientsList) {
    if (item is Map<String, dynamic>) {
      final section = item['section'] as String?;
      if (section != null && section != currentSection) {
        currentSection = section;
      }
      
      ingredients.add(Ingredient.create(
        name: item['name'] ?? '',
        amount: item['amount'],
        unit: item['unit'],
        preparation: item['preparation'],
        section: currentSection,
        bakerPercent: item['bakerPercent'],
      ));
    }
  }
  
  // Parse directions
  final directionsList = (json['directions'] as List?) ?? [];
  final directions = directionsList
      .whereType<String>()
      .where((s) => s.trim().isNotEmpty)
      .toList();
  
  // Build raw ingredients for review screen
  final rawIngredients = ingredients.map((i) => RawIngredientData(
    original: '${i.displayAmount} ${i.name}'.trim(),
    amount: i.amount,
    unit: i.unit,
    name: i.name,
    preparation: i.preparation,
    sectionName: i.section,
    isSection: false,
  )).toList();
  
  return RecipeImportResult(
    name: json['name'] as String?,
    course: json['course'] as String? ?? 'mains',
    cuisine: json['cuisine'] as String?,
    serves: json['serves'] as String?,
    time: json['time'] as String?,
    ingredients: ingredients,
    directions: directions,
    notes: json['notes'] as String?,
    rawIngredients: rawIngredients,
    rawDirections: directions,
    source: RecipeSource.ocr, // ADD RecipeSource.aiVision
    ingredientsConfidence: 0.9, // High confidence for AI parsing
    directionsConfidence: 0.9,
  );
}
```

---

## UI Design

### Settings → AI Features

```
┌─────────────────────────────────────────────┐
│ AI Features                                 │
├─────────────────────────────────────────────┤
│                                             │
│ Use your own AI API keys to enable          │
│ advanced image import for complex recipes.  │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ Provider                                │ │
│ │ ┌─────────────────────────────────────┐ │ │
│ │ │ ○ None                              │ │ │
│ │ │ ○ OpenAI (GPT-4o)                   │ │ │
│ │ │ ○ Anthropic (Claude)                │ │ │
│ │ └─────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ OpenAI API Key                          │ │
│ │ ┌─────────────────────────┐ ┌────────┐  │ │
│ │ │ sk-••••••••••••••••••   │ │  Test  │  │ │
│ │ └─────────────────────────┘ └────────┘  │ │
│ │                             ┌────────┐  │ │
│ │                             │ Clear  │  │ │
│ │                             └────────┘  │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ ⓘ Keys are stored securely on your     │ │
│ │   device and never sent to Memoix.      │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ Estimated cost: ~$0.01-0.05 per image   │ │
│ │ Get an API key:                         │ │
│ │ • OpenAI: platform.openai.com           │ │
│ │ • Anthropic: console.anthropic.com      │ │
│ └─────────────────────────────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

### Import Screen (with AI enabled)

Only show "AI Vision Import" option when a valid API key is configured:

```
┌─────────────────────────────────────────────┐
│ Import Recipe                               │
├─────────────────────────────────────────────┤
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 📷  Take Photo                          │ │
│ │     Quick scan of a simple recipe       │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 🖼️  Choose from Gallery                 │ │
│ │     Import from saved photos            │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 📄  Multi-Page Scan                     │ │
│ │     Combine multiple photos             │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ ✨  AI Vision Import                    │ │  ← Only visible with API key
│ │     For complex layouts & cookbooks     │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 🔗  Import from URL                     │ │
│ │     Paste a recipe website link         │ │
│ └─────────────────────────────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

---

## Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_secure_storage: ^9.0.0  # Already present
  http: ^1.1.0                    # Already present
```

No new dependencies required.

---

## Error Handling

| Error | User Message |
|-------|--------------|
| Invalid API key | "API key is invalid. Please check your key in Settings → AI Features." |
| Rate limit exceeded | "Rate limit exceeded. Please wait a moment and try again." |
| Image too large | "Image is too large. Maximum size is 20MB." |
| Network error | "Could not connect to AI service. Check your internet connection." |
| Parsing failed | "Could not extract recipe from image. Try a clearer photo or manual entry." |
| Empty response | "No recipe found in image. Make sure the image contains a complete recipe." |

---

## Testing Plan

1. **Unit tests**
   - Response parsing with various JSON structures
   - Error handling for malformed responses
   - Key storage/retrieval

2. **Integration tests**
   - Mock API responses
   - Full flow from image to review screen

3. **Manual testing**
   - Cookbook pages (tables, multi-column)
   - Handwritten recipes
   - Recipe cards
   - Screenshots from apps
   - Very long recipes (pagination)
   - Non-English recipes

---

## Future Enhancements

1. **Multi-image support** - Combine multiple pages of a recipe
2. **Cost tracking** - Show estimated/actual API costs
3. **Caching** - Cache results to avoid re-processing same image
4. **Offline queue** - Queue images for processing when online
5. **Provider comparison** - Let users compare results from different providers

---

## Implementation Checklist

- [ ] Add `flutter_secure_storage` to pubspec (already present)
- [ ] Create `AIKeyStorage` service
- [ ] Create `AIVisionService` with OpenAI support
- [ ] Add Anthropic support to `AIVisionService`
- [ ] Create AI Settings screen
- [ ] Add route to AI Settings from main Settings
- [ ] Create AI Vision Import screen
- [ ] Add conditional "AI Vision Import" option to import screen
- [ ] Add response parsing to `RecipeImportResult`
- [ ] Test with various cookbook images
- [ ] Add usage documentation to help/FAQ
