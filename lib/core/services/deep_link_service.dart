import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sharing/services/share_service.dart';
import '../../features/recipes/screens/recipe_edit_screen.dart';
import '../../features/external_storage/services/repository_manager.dart';
import '../../features/external_storage/providers/google_drive_storage.dart';
import '../../features/external_storage/models/drive_repository.dart';
import '../widgets/memoix_snackbar.dart';

/// Service to handle deep links (memoix://recipe/...)
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  final Ref _ref;
  StreamSubscription<Uri>? _subscription;

  DeepLinkService(this._ref);

  /// Initialize and start listening for deep links
  Future<void> initialize(BuildContext context) async {
    // Handle initial link if app was opened via deep link
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        await _handleDeepLink(context, initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    // Listen for subsequent deep links
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(context, uri);
    });
  }

  /// Stop listening for deep links
  void dispose() {
    _subscription?.cancel();
  }

  /// Handle a deep link URI
  Future<void> _handleDeepLink(BuildContext context, Uri uri) async {
    debugPrint('Received deep link: $uri');

    if (uri.scheme != 'memoix') return;

    // Handle repository sharing links: memoix://share/repo?id=XXX&name=YYY
    if (uri.host == 'share' && uri.pathSegments.contains('repo')) {
      await _handleRepositoryShare(context, uri);
      return;
    }

    // Handle recipe sharing links: memoix://recipe/...
    if (uri.host == 'recipe' || uri.pathSegments.isNotEmpty) {
      await _handleRecipeShare(context, uri);
      return;
    }
  }

  /// Handle repository sharing deep link
  Future<void> _handleRepositoryShare(BuildContext context, Uri uri) async {
    final folderId = uri.queryParameters['id'];
    final repositoryName = uri.queryParameters['name'];

    if (folderId == null || folderId.isEmpty) {
      _showError(context, 'Invalid repository link: Missing folder ID');
      return;
    }

    if (repositoryName == null || repositoryName.isEmpty) {
      _showError(context, 'Invalid repository link: Missing repository name');
      return;
    }

    // Check if already added
    final manager = RepositoryManager();
    final repositories = await manager.loadRepositories();
    
    if (repositories.any((r) => r.folderId == folderId)) {
      if (context.mounted) {
        MemoixSnackBar.show('Repository already added');
      }
      return;
    }

    // Attempt to verify access
    bool? hasAccess;
    bool isOffline = false;

    try {
      final storage = _ref.read(googleDriveStorageProvider);
      hasAccess = await storage.verifyFolderAccess(folderId);
    } catch (e) {
      debugPrint('Repository verification error (likely offline): $e');
      isOffline = true;
    }

    if (!context.mounted) return;

    // Scenario A: Verified access
    if (hasAccess == true) {
      final repo = await manager.addRepository(
        name: repositoryName,
        folderId: folderId,
        isPendingVerification: false,
      );

      if (context.mounted) {
        final shouldSwitch = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Repository Added'),
            content: Text('Joined "$repositoryName"!\n\nSwitch to this repository now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not Now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Switch'),
              ),
            ],
          ),
        );

        if (shouldSwitch == true) {
          await manager.setActiveRepository(repo.id);
          if (context.mounted) {
            MemoixSnackBar.showSuccess('Switched to "$repositoryName"');
          }
        }
      }
      return;
    }

    // Scenario B: Access denied
    if (hasAccess == false) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Access Denied'),
            content: Text(
              'You don\'t have access to "$repositoryName".\n\n'
              'Ask the repository owner to invite your Google account email address.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Scenario C: Offline - add provisionally
    if (isOffline) {
      final repo = await manager.addRepository(
        name: repositoryName,
        folderId: folderId,
        isPendingVerification: true,
      );

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Repository Saved'),
            content: Text(
              '"$repositoryName" has been added but could not be verified.\n\n'
              'Access will be checked when you\'re online.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Handle recipe sharing deep link
  Future<void> _handleRecipeShare(BuildContext context, Uri uri) async {
      // Extract the encoded recipe data
      String? encodedData;
      
      if (uri.pathSegments.isNotEmpty) {
        encodedData = uri.pathSegments.last;
      } else if (uri.path.isNotEmpty) {
        encodedData = uri.path.replaceFirst('/', '');
      }

      if (encodedData == null || encodedData.isEmpty) {
        _showError(context, 'Invalid recipe link');
        return;
      }

      try {
        final shareService = _ref.read(shareServiceProvider);
        final recipe = shareService.parseShareLink('memoix://recipe/$encodedData');

        if (recipe == null) {
          _showError(context, 'Could not parse recipe from link');
          return;
        }

        // SECURITY: Validate recipe data before allowing import
        if (recipe.name.trim().isEmpty) {
          _showError(context, 'Invalid recipe link: Missing required data.');
          return;
        }
        if (recipe.ingredients.isEmpty && recipe.directions.isEmpty) {
          _showError(context, 'Invalid recipe link: Missing required data.');
          return;
        }

        // Show confirmation dialog before importing
        if (context.mounted) {
          final shouldImport = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Import Recipe?'),
              content: Text('Would you like to import "${recipe.name}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Import'),
                ),
              ],
            ),
          );

          if (shouldImport == true && context.mounted) {
            // Navigate to edit screen so user can review before saving
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecipeEditScreen(importedRecipe: recipe),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error handling deep link: $e');
        _showError(context, 'Failed to import recipe');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    MemoixSnackBar.showError(message);
  }
}

/// Provider for the deep link service
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService(ref);
});
