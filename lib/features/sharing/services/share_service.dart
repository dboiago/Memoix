import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';

import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../pizzas/models/pizza.dart';
import '../../sandwiches/models/sandwich.dart';
import '../../smoking/models/smoking_recipe.dart';
import '../../modernist/models/modernist_recipe.dart';

/// Service for sharing and importing recipes
class ShareService {
  /// Generate a shareable link for a recipe
  String generateShareLink(Recipe recipe) {
    final json = recipe.toShareableJson();
    final encoded = base64Url.encode(utf8.encode(jsonEncode(json)));
    return 'memoix://recipe/$encoded';
  }

  /// Generate a short share code (first 8 chars of UUID)
  String generateShareCode(Recipe recipe) {
    return recipe.uuid.substring(0, 8).toUpperCase();
  }

  /// Share a recipe via system share sheet
  Future<void> shareRecipe(Recipe recipe) async {
    final link = generateShareLink(recipe);
    
    await Share.share(
      '🍳 Check out this recipe: ${recipe.name}\n\n$link',
      subject: 'Recipe: ${recipe.name}',
    );
  }

  /// Share recipe as plain text
  Future<void> shareAsText(Recipe recipe) async {
    final buffer = StringBuffer();
    
    buffer.writeln('# ${recipe.name}');
    buffer.writeln();
    
    if (recipe.cuisine != null) {
      buffer.writeln('Cuisine: ${recipe.cuisine}');
    }
    if (recipe.serves != null) {
      buffer.writeln('Serves: ${recipe.serves}');
    }
    if (recipe.time != null) {
      buffer.writeln('Time: ${recipe.time}');
    }
    
    buffer.writeln();
    buffer.writeln('## Ingredients');
    for (final ingredient in recipe.ingredients) {
      var line = '- ${ingredient.displayText}';
      if (ingredient.preparation != null && ingredient.preparation!.isNotEmpty) {
        line += ' (${ingredient.preparation})';
      }
      if (ingredient.isOptional) {
        line += ' [optional]';
      }
      buffer.writeln(line);
      if (ingredient.alternative != null) {
        buffer.writeln('  Alt: ${ingredient.alternative}');
      }
    }
    
    buffer.writeln();
    buffer.writeln('## Directions');
    for (int i = 0; i < recipe.directions.length; i++) {
      buffer.writeln('${i + 1}. ${recipe.directions[i]}');
    }
    
    if (recipe.notes != null && recipe.notes!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Notes');
      buffer.writeln(recipe.notes);
    }
    
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('Shared from Memoix');
    
    await Share.share(buffer.toString(), subject: recipe.name);
  }

  /// Parse a recipe from a share link
  Recipe? parseShareLink(String link) {
    try {
      // Handle both full URI and just the encoded part
      String encoded;
      if (link.startsWith('memoix://recipe/')) {
        encoded = link.substring('memoix://recipe/'.length);
      } else {
        encoded = link;
      }
      
      final decoded = utf8.decode(base64Url.decode(encoded));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      
      return Recipe.fromJson(json)..source = RecipeSource.imported;
    } catch (e) {
      print('Error parsing share link: $e');
      return null;
    }
  }

  /// Copy share link to clipboard
  Future<void> copyShareLink(Recipe recipe) async {
    final link = generateShareLink(recipe);
    await Clipboard.setData(ClipboardData(text: link));
  }

  /// Show QR code dialog for sharing
  void showQrCode(BuildContext context, Recipe recipe) {
    final link = generateShareLink(recipe);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Share ${recipe.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: link,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan this QR code with another\nMemoix app to import this recipe',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await copyShareLink(recipe);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              }
            },
            child: const Text('Copy Link'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // === PIZZA SHARING ===

  /// Generate a shareable link for a pizza
  String generatePizzaShareLink(Pizza pizza) {
    final json = pizza.toShareableJson();
    final encoded = base64Url.encode(utf8.encode(jsonEncode(json)));
    return 'memoix://pizza/$encoded';
  }

  /// Share a pizza via system share sheet
  Future<void> sharePizza(Pizza pizza) async {
    final link = generatePizzaShareLink(pizza);
    
    await Share.share(
      'Check out this pizza: ${pizza.name}\n\n$link',
      subject: 'Pizza: ${pizza.name}',
    );
  }

  /// Share pizza as plain text
  Future<void> sharePizzaAsText(Pizza pizza) async {
    final buffer = StringBuffer();
    
    buffer.writeln('# ${pizza.name}');
    buffer.writeln();
    buffer.writeln('Base: ${pizza.base.displayName}');
    
    if (pizza.cheeses.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Cheeses');
      for (final cheese in pizza.cheeses) {
        buffer.writeln('- $cheese');
      }
    }
    
    if (pizza.proteins.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Proteins');
      for (final protein in pizza.proteins) {
        buffer.writeln('- $protein');
      }
    }
    
    if (pizza.vegetables.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Vegetables');
      for (final vegetable in pizza.vegetables) {
        buffer.writeln('- $vegetable');
      }
    }
    
    if (pizza.notes != null && pizza.notes!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Notes');
      buffer.writeln(pizza.notes);
    }
    
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('Shared from Memoix');
    
    await Share.share(buffer.toString(), subject: pizza.name);
  }

  /// Copy pizza share link to clipboard
  Future<void> copyPizzaShareLink(Pizza pizza) async {
    final link = generatePizzaShareLink(pizza);
    await Clipboard.setData(ClipboardData(text: link));
  }

  /// Show QR code dialog for pizza sharing
  void showPizzaQrCode(BuildContext context, Pizza pizza) {
    final link = generatePizzaShareLink(pizza);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Share ${pizza.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: link,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan this QR code with another\nMemoix app to import this pizza',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await copyPizzaShareLink(pizza);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              }
            },
            child: const Text('Copy Link'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // === SANDWICH SHARING ===

  /// Generate a shareable link for a sandwich
  String generateSandwichShareLink(Sandwich sandwich) {
    final json = sandwich.toShareableJson();
    final encoded = base64Url.encode(utf8.encode(jsonEncode(json)));
    return 'memoix://sandwich/$encoded';
  }

  /// Share a sandwich via system share sheet
  Future<void> shareSandwich(Sandwich sandwich) async {
    final link = generateSandwichShareLink(sandwich);
    
    await Share.share(
      'Check out this sandwich: ${sandwich.name}\n\n$link',
      subject: 'Sandwich: ${sandwich.name}',
    );
  }

  /// Share sandwich as plain text
  Future<void> shareSandwichAsText(Sandwich sandwich) async {
    final buffer = StringBuffer();
    
    buffer.writeln('# ${sandwich.name}');
    buffer.writeln();
    if (sandwich.bread.isNotEmpty) {
      buffer.writeln('Bread: ${sandwich.bread}');
    }
    
    if (sandwich.proteins.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Proteins');
      for (final protein in sandwich.proteins) {
        buffer.writeln('- $protein');
      }
    }
    
    if (sandwich.vegetables.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Vegetables');
      for (final vegetable in sandwich.vegetables) {
        buffer.writeln('- $vegetable');
      }
    }
    
    if (sandwich.cheeses.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Cheeses');
      for (final cheese in sandwich.cheeses) {
        buffer.writeln('- $cheese');
      }
    }
    
    if (sandwich.condiments.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Condiments');
      for (final condiment in sandwich.condiments) {
        buffer.writeln('- $condiment');
      }
    }
    
    if (sandwich.notes != null && sandwich.notes!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Notes');
      buffer.writeln(sandwich.notes);
    }
    
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('Shared from Memoix');
    
    await Share.share(buffer.toString(), subject: sandwich.name);
  }

  /// Copy sandwich share link to clipboard
  Future<void> copySandwichShareLink(Sandwich sandwich) async {
    final link = generateSandwichShareLink(sandwich);
    await Clipboard.setData(ClipboardData(text: link));
  }

  /// Show QR code dialog for sandwich sharing
  void showSandwichQrCode(BuildContext context, Sandwich sandwich) {
    final link = generateSandwichShareLink(sandwich);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Share ${sandwich.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: link,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan this QR code with another\nMemoix app to import this sandwich',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await copySandwichShareLink(sandwich);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              }
            },
            child: const Text('Copy Link'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // === SMOKING SHARING ===

  /// Generate a shareable link for a smoking recipe
  String generateSmokingShareLink(SmokingRecipe recipe) {
    final json = recipe.toShareableJson();
    final encoded = base64Url.encode(utf8.encode(jsonEncode(json)));
    return 'memoix://smoking/$encoded';
  }

  /// Share a smoking recipe via system share sheet
  Future<void> shareSmokingRecipe(SmokingRecipe recipe) async {
    final link = generateSmokingShareLink(recipe);
    
    await Share.share(
      'Check out this smoking recipe: ${recipe.name}\n\n$link',
      subject: 'Smoking: ${recipe.name}',
    );
  }

  /// Share smoking recipe as plain text
  Future<void> shareSmokingAsText(SmokingRecipe recipe) async {
    final buffer = StringBuffer();
    
    buffer.writeln('# ${recipe.name}');
    buffer.writeln();
    buffer.writeln('Temperature: ${recipe.temperature}');
    buffer.writeln('Time: ${recipe.time}');
    buffer.writeln('Wood: ${recipe.wood}');
    
    if (recipe.seasonings.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Seasonings');
      for (final seasoning in recipe.seasonings) {
        if (seasoning.amount != null && seasoning.amount!.isNotEmpty) {
          buffer.writeln('- ${seasoning.amount} ${seasoning.name}');
        } else {
          buffer.writeln('- ${seasoning.name}');
        }
      }
    }
    
    if (recipe.directions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Directions');
      for (int i = 0; i < recipe.directions.length; i++) {
        buffer.writeln('${i + 1}. ${recipe.directions[i]}');
      }
    }
    
    if (recipe.notes != null && recipe.notes!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Notes');
      buffer.writeln(recipe.notes);
    }
    
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('Shared from Memoix');
    
    await Share.share(buffer.toString(), subject: recipe.name);
  }

  /// Copy smoking recipe share link to clipboard
  Future<void> copySmokingShareLink(SmokingRecipe recipe) async {
    final link = generateSmokingShareLink(recipe);
    await Clipboard.setData(ClipboardData(text: link));
  }

  /// Show QR code dialog for smoking recipe sharing
  void showSmokingQrCode(BuildContext context, SmokingRecipe recipe) {
    final link = generateSmokingShareLink(recipe);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Share ${recipe.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: link,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan this QR code with another\nMemoix app to import this recipe',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await copySmokingShareLink(recipe);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              }
            },
            child: const Text('Copy Link'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // === MODERNIST SHARING ===

  /// Generate a shareable link for a modernist recipe
  String generateModernistShareLink(ModernistRecipe recipe) {
    final json = recipe.toShareableJson();
    final encoded = base64Url.encode(utf8.encode(jsonEncode(json)));
    return 'memoix://modernist/$encoded';
  }

  /// Share a modernist recipe via system share sheet
  Future<void> shareModernistRecipe(ModernistRecipe recipe) async {
    final link = generateModernistShareLink(recipe);
    
    await Share.share(
      'Check out this modernist recipe: ${recipe.name}\n\n$link',
      subject: 'Modernist: ${recipe.name}',
    );
  }

  /// Share modernist recipe as plain text
  Future<void> shareModernistAsText(ModernistRecipe recipe) async {
    final buffer = StringBuffer();
    
    buffer.writeln('# ${recipe.name}');
    buffer.writeln();
    buffer.writeln('Type: ${recipe.type.displayName}');
    if (recipe.technique != null && recipe.technique!.isNotEmpty) {
      buffer.writeln('Technique: ${recipe.technique}');
    }
    if (recipe.serves != null && recipe.serves!.isNotEmpty) {
      buffer.writeln('Serves: ${recipe.serves}');
    }
    if (recipe.time != null && recipe.time!.isNotEmpty) {
      buffer.writeln('Time: ${recipe.time}');
    }
    
    if (recipe.equipment.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Equipment');
      for (final item in recipe.equipment) {
        buffer.writeln('- $item');
      }
    }
    
    if (recipe.ingredients.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Ingredients');
      for (final ingredient in recipe.ingredients) {
        buffer.writeln('- ${ingredient.displayText}');
      }
    }
    
    if (recipe.directions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Directions');
      for (int i = 0; i < recipe.directions.length; i++) {
        buffer.writeln('${i + 1}. ${recipe.directions[i]}');
      }
    }
    
    if (recipe.scienceNotes != null && recipe.scienceNotes!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Science Notes');
      buffer.writeln(recipe.scienceNotes);
    }
    
    if (recipe.notes != null && recipe.notes!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Notes');
      buffer.writeln(recipe.notes);
    }
    
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('Shared from Memoix');
    
    await Share.share(buffer.toString(), subject: recipe.name);
  }

  /// Copy modernist recipe share link to clipboard
  Future<void> copyModernistShareLink(ModernistRecipe recipe) async {
    final link = generateModernistShareLink(recipe);
    await Clipboard.setData(ClipboardData(text: link));
  }

  /// Show QR code dialog for modernist recipe sharing
  void showModernistQrCode(BuildContext context, ModernistRecipe recipe) {
    final link = generateModernistShareLink(recipe);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Share ${recipe.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: link,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan this QR code with another\nMemoix app to import this recipe',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await copyModernistShareLink(recipe);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              }
            },
            child: const Text('Copy Link'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// Provider
final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService();
});

/// Handler for incoming deep links
class DeepLinkHandler {
  final RecipeRepository repository;
  final ShareService shareService;

  DeepLinkHandler(this.repository, this.shareService);

  /// Handle an incoming deep link
  Future<Recipe?> handleLink(String link) async {
    if (!link.startsWith('memoix://')) {
      return null;
    }

    if (link.startsWith('memoix://recipe/')) {
      final recipe = shareService.parseShareLink(link);
      if (recipe != null) {
        await repository.saveRecipe(recipe);
        return recipe;
      }
    }

    return null;
  }
}

final deepLinkHandlerProvider = Provider<DeepLinkHandler>((ref) {
  return DeepLinkHandler(
    ref.watch(recipeRepositoryProvider),
    ref.watch(shareServiceProvider),
  );
});
