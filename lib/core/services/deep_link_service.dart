import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sharing/services/share_service.dart';
import '../../features/recipes/screens/recipe_edit_screen.dart';
import '../../features/personal_storage/services/shared_storage_manager.dart';
import '../../features/personal_storage/providers/google_drive_storage.dart';
import '../../features/personal_storage/providers/one_drive_storage.dart';
import '../../features/personal_storage/models/storage_location.dart';
import '../../app/app.dart' show rootNavigatorKey;
import '../widgets/memoix_snackbar.dart';

/// Service to handle deep links (memoix://recipe/...)
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  final Ref _ref;
  StreamSubscription<Uri>? _subscription;

  DeepLinkService(this._ref);

  /// Initialize and start listening for deep links
  Future<void> initialize(BuildContext context) async {
    if (_subscription != null) return;

    // Handle initial link if app was opened via deep link
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null && initialUri.scheme == 'memoix') {
        if (!context.mounted) return;
        await _handleDeepLink(context, initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    // Listen for subsequent deep links
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'memoix') {
        if (!context.mounted) return;
        _handleDeepLink(context, uri);
      }
    });
  }

  /// Stop listening for deep links
  void dispose() {
    _subscription?.cancel();
  }

  /// Handle a deep link URI
  Future<void> _handleDeepLink(BuildContext context, Uri uri) async {
    debugPrint('Received deep link: $uri');

    // SECURITY: Enforce max payload size per AGENTS.md (4,096 chars)
    if (uri.toString().length > 4096) {
      debugPrint('Security: Rejected oversized deep link (${uri.toString().length} chars)');
      return;
    }

    // Let flutter_appauth handle OAuth callbacks
    if (uri.host == 'oauth') return;

    if (uri.scheme != 'memoix') return;

    // Handle repository sharing links: memoix://share/repo?id=XXX&name=YYY
    if (uri.host == 'share' && uri.pathSegments.contains('repo')) {
      await handleRepositoryShare(context, uri);
      return;
    }

    // Handle recipe sharing links: memoix://recipe/...
    if (uri.host == 'recipe') {
      await _handleRecipeShare(context, uri);
      return;
    }
  }

  /// Handle repository sharing deep link
  Future<void> handleRepositoryShare(BuildContext context, Uri uri) async {
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

    // SECURITY: Reject excessively long parameters before storing or displaying
    if (folderId.length > 256) {
      _showError(context, 'Invalid repository link: folder ID is too long.');
      return;
    }
    if (repositoryName.length > 255) {
      _showError(context, 'Invalid repository link: repository name is too long.');
      return;
    }

    // Check if already added
    final manager = SharedStorageManager();
    final repositories = await manager.loadRepositories();
    
    if (repositories.any((r) => r.folderId == folderId)) {
      if (context.mounted) {
        MemoixSnackBar.show('Repository already added');
      }
      return;
    }

    // Parse provider from URI — default to googleDrive for backwards compatibility
    final providerStr = uri.queryParameters['provider'];
    final storageProvider = providerStr != null
        ? StorageProvider.values.firstWhere(
            (e) => e.name == providerStr,
            orElse: () => StorageProvider.googleDrive,
          )
        : StorageProvider.googleDrive;

    // Attempt to verify access
    bool? hasAccess;
    bool isOffline = false;
    bool isAuthFailure = false;

    try {
      switch (storageProvider) {
        case StorageProvider.googleDrive:
          final storage = _ref.read(googleDriveStorageProvider);
          if (!storage.isConnected) {
            isAuthFailure = true;
          } else {
            hasAccess = await storage.verifyFolderAccess(folderId);
          }
          break;
        case StorageProvider.oneDrive:
          final storage = OneDriveStorage();
          await storage.init();
          if (storage.isConnected) {
            hasAccess = await storage.verifyFolderAccess(folderId);
          } else {
            isAuthFailure = true;
          }
          break;
      }
    } catch (e) {
      debugPrint('Repository verification error: $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('auth') ||
          msg.contains('401') ||
          msg.contains('403') ||
          msg.contains('unauthorized') ||
          msg.contains('unauthenticated') ||
          msg.contains('sign in')) {
        isAuthFailure = true;
      } else {
        isOffline = true;
      }
    }

    if (!context.mounted) return;

    // Scenario A: Verified access
    if (hasAccess == true) {
      final repo = await manager.addRepository(
        name: repositoryName,
        folderId: folderId,
        isPendingVerification: false,
        provider: storageProvider,
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

    // Scenario C: Offline or unauthenticated — add provisionally
    if (isOffline || isAuthFailure) {
      await manager.addRepository(
        name: repositoryName,
        folderId: folderId,
        isPendingVerification: true,
        provider: storageProvider,
      );

      if (context.mounted) {
        final message = isAuthFailure
            ? 'Sign in required — tap the repository to connect and sync'
            : '"$repositoryName" has been added but could not be verified.\n\n'
              'Access will be checked when you\'re online.';
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Repository Added'),
            content: Text(message),
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
      if (!context.mounted) return;
      _showError(context, 'Failed to import recipe');
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
