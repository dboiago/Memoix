/// Memoix on-device agent (first-party, no external API)
// Returns empty results immediately until the on-device pipeline is wired up.
// No I/O, no credentials, no network requests.

import 'dart:typed_data';

class MemoixClient {
  final String apiKey;
  final String model;

  MemoixClient(this.apiKey, {this.model = ''});

  Future<Map<String, dynamic>> analyzeRecipe({
    required String systemPrompt,
    String? text,
    Uint8List? imageBytes,
    double temperature = 0.0,
  }) async {
    return const {};
  }
}
