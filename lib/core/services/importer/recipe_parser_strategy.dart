import 'package:html/dom.dart';
import '../models/recipe_import_result.dart';

abstract class RecipeParserStrategy {
  /// Returns 0.0 to 1.0. 
  /// 1.0 = I definitely handle this (e.g., YouTube URL).
  /// 0.0 = I cannot handle this.
  double canParse(String url, Document? document, String? rawBody);

  /// Performs the extraction.
  Future<RecipeImportResult?> parse(String url, Document? document, String? rawBody);
}
