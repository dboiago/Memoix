import 'package:html/dom.dart';
import '../../models/recipe_import_result.dart';

abstract class RecipeParserStrategy {
  /// Returns a confidence score (0.0 - 1.0)
  double canParse(String url, Document? document, String? rawBody);

  /// Executes the parsing logic
  Future<RecipeImportResult?> parse(String url, Document? document, String? rawBody);
}
