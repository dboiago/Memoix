/// Gemini (Gemini 1.5 Pro)
// Slightly looser with schema
// Very good with dense scanned PDFs
  
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GeminiClient {
  final String apiKey;

  GeminiClient(this.apiKey);

  Future<Map<String, dynamic>> analyzeRecipe({
    required String systemPrompt,
    String? text,
    Uint8List? imageBytes,
  }) async {
    final parts = <Map<String, dynamic>>[];

    if (text != null && text.trim().isNotEmpty) {
      parts.add({ "text": text });
    }

    if (imageBytes != null) {
      parts.add({
        "inlineData": {
          "mimeType": "image/jpeg",
          "data": base64Encode(imageBytes),
        }
      });
    }

    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models/'
        'gemini-1.5-pro:generateContent?key=$apiKey'
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "systemInstruction": {
          "parts": [{ "text": systemPrompt }]
        },
        "contents": [
          {
            "role": "user",
            "parts": parts,
          }
        ],
        "generationConfig": {
          "temperature": 0.0,
          "responseMimeType": "application/json",
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini error: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    return jsonDecode(decoded['candidates'][0]['content']['parts'][0]['text']);
  }
}
