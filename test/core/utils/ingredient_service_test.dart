import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/core/utils/ingredient_categorizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IngredientService Tests', () {
    late IngredientService service;

    // Mock data mimicking the production JSON structure
    final Map<String, int> mockDatabase = {
      'sun-dried tomato': IngredientCategory.condiment.index,
      'coconut milk': IngredientCategory.beverage.index,
      'milk': IngredientCategory.dairy.index, // For substring conflict test
      'chicken breast': IngredientCategory.poultry.index,
      'kosher salt': IngredientCategory.spice.index,
      'salt': IngredientCategory.spice.index,
    };

    setUp(() async {
      // Encode mock data to JSON -> UTF8 -> Gzip -> ByteData
      final jsonString = json.encode(mockDatabase);
      final utf8Bytes = utf8.encode(jsonString);
      final gzippedBytes = GZipCodec().encode(utf8Bytes);
      final byteData = ByteData.view(Uint8List.fromList(gzippedBytes).buffer);

      // Intercept rootBundle loading
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMock(rootBundle.load('assets/ingredients.json.gz'),
              (ByteData? message) async {
        return byteData;
      });

      service = IngredientService();
      // Reset singleton if possible or ensure it initializes
      // Since it's a singleton with strict init check, we might need to rely on hot restart behavior 
      // or modify the class to be testable. 
      // Assuming for this test we can re-initialize or it's a fresh run.
      await service.initialize();
    });

    test('Decompression Integrity and Initialization', () {
      // If we reach here without error and classify works, init was successful
      expect(service.classify('salt'), IngredientCategory.spice);
    });

    test('Normalization: "2 cups organic sun-dried tomatoes"', () {
      // "2 cups organic" -> removed
      // "tomatoes" -> "tomatoe" (due to s$ strip) or just matching substring?
      // Normalized: "sun-dried tomatoe" ?
      // Wait, let's analyze the regex in the file:
      // .replaceAll(RegExp(r's$'), '')
      // "tomatoes" -> "tomatoe"
      // If mockDB has "sun-dried tomato", and input is "sun-dried tomatoe"
      // It won't match "sun-dried tomato" exactly.
      // But "sun-dried tomatoe" contains "sun-dried tomato".
      // So Longest Match Wins should catch it.
      
      final result = service.classify('2 cups organic sun-dried tomatoes');
      expect(result, IngredientCategory.condiment);
    });

    test('Matching Logic: "100ml cold-pressed coconut milk" (Longest Match)', () {
      // Should match "coconut milk" (beverage) not "milk" (dairy)
      // "100ml" removed. "cold" removed. "pressed" removed.
      // "coconut milk" remains.
      final result = service.classify('100ml cold-pressed coconut milk');
      expect(result, IngredientCategory.beverage);
      expect(result, isNot(IngredientCategory.dairy));
    });

    test('Normalization: "Diced chicken breast"', () {
      // "Diced" -> removed.
      // "chicken breast" matches.
      final result = service.classify('Diced chicken breast');
      expect(result, IngredientCategory.poultry);
    });

    test('Exact Match: "Kosher salt"', () {
      final result = service.classify('Kosher salt');
      expect(result, IngredientCategory.spice);
    });

    test('Fallback partial match: "sea salt"', () {
       // "sea" not removed. "salt" matches.
       // Normalized: "sea salt". Contains "salt".
       final result = service.classify('sea salt');
       expect(result, IngredientCategory.spice);
    });
  });
}
