import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';

import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';

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
      buffer.writeln('- ${ingredient.displayText}');
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
