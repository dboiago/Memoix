import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';

import '../../app/app.dart' show rootNavigatorKey;
import '../../features/ai/ai_settings_provider.dart';
import '../../features/ai/services/ai_service.dart';
import '../../features/ai/services/memoix_ai_service.dart';
import '../../features/import/models/recipe_import_result.dart';
import '../../features/import/screens/import_review_screen.dart';
import '../../features/import/screens/url_import_screen.dart' show SpecializedCourses;
import '../../features/import/services/ocr_importer.dart';
import '../../features/recipes/screens/recipe_edit_screen.dart';
import '../../features/sharing/services/share_service.dart';
import '../services/url_importer.dart';
import '../widgets/memoix_snackbar.dart';

/// Listens on the "memoix/share" MethodChannel (registered in MainActivity.kt)
/// and routes incoming share events to the appropriate import flow.
///
/// Routing rules:
///   type "url"   → same confidence logic as [URLImportScreen]
///   type "text"  → AI text extraction → [ImportReviewScreen]
///   type "image" → AI (if configured) or OCR → [ImportReviewScreen]
///
/// If a share arrives before the navigator is ready it is queued and
/// drained on the first [initialize] call.
class ShareHandlerService {
  static const _channel = MethodChannel('memoix/share');

  final Ref _ref;

  /// Queued payload received before initialize() was called.
  Map<String, dynamic>? _pendingEvent;

  /// Screen collected by [_pushScreen] during parsing; pushed after the
  /// loading dialog is dismissed in [_handleShare].
  Widget? _pendingScreen;

  ShareHandlerService(this._ref);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  void initialize() {
    _channel.setMethodCallHandler(_onMethodCall);
    // Drain any event that arrived before the engine/navigator was ready.
    // On a cold start the share intent is queued before the first frame has
    // painted, so we delay briefly to let the Home screen complete its initial
    // layout before attempting to show a dialog.
    final pending = _pendingEvent;
    if (pending != null) {
      _pendingEvent = null;
      Future.delayed(const Duration(milliseconds: 300), () {
        _dispatchEvent(pending);
      });
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }

  // ── Channel handler ────────────────────────────────────────────────────────

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method != 'onShareReceived') return;
    final data = Map<String, dynamic>.from(call.arguments as Map);
    _dispatchEvent(data);
  }

  void _dispatchEvent(Map<String, dynamic> data) {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      // Navigator not ready yet — queue and wait for the next initialize() drain.
      _pendingEvent = data;
      return;
    }
    _handleShare(data);
  }

  // ── Share routing ──────────────────────────────────────────────────────────

  Future<void> _handleShare(Map<String, dynamic> data) async {
    _pendingScreen = null;

    final navigator = rootNavigatorKey.currentState;
    final context = rootNavigatorKey.currentContext;
    if (navigator == null || context == null) return;

    // Show a non-dismissible loading overlay while the async import work runs.
    // It is always dismissed in the finally block so the user is never stuck.
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => const _ShareLoadingDialog(),
    ));

    try {
      final type = data['type'] as String?;
      switch (type) {
        case 'url':
          final content = data['content'] as String? ?? '';
          await _handleUrlShare(content);
        case 'text':
          final content = data['content'] as String? ?? '';
          await _handleTextShare(content);
        case 'image':
          final path = data['path'] as String? ?? '';
          await _handleImageShare(path);
        default:
          debugPrint('ShareHandlerService: unknown share type "$type"');
      }
    } finally {
      // Always dismiss — even on unexpected errors — so the UI is never blocked.
      if (navigator.mounted) {
        navigator.pop();
      }
    }

    // Push the target screen now that the loading overlay is gone.
    final screen = _pendingScreen;
    _pendingScreen = null;
    if (screen != null && navigator.mounted) {
      navigator.push(MaterialPageRoute(builder: (_) => screen));
    }
  }

  // ── URL share ──────────────────────────────────────────────────────────────

  /// Replicates the dispatch logic of [URLImportScreen._importFromUrl].
  /// - Extracts a memoix:// or http(s):// link from the raw text.
  /// - Routes based on [RecipeImportResult.needsUserReview] exactly as
  ///   URLImportScreen does.
  Future<void> _handleUrlShare(String rawInput) async {
    if (rawInput.isEmpty) return;

    // SECURITY: enforce 4096-char limit per AGENTS.md.
    if (rawInput.length > 4096) {
      MemoixSnackBar.showError('Shared link is too long to process (max 4,096 characters).');
      return;
    }

    // Prefer memoix:// deep links over web URLs.
    final memoixMatch = RegExp(r'(memoix://\S+)').firstMatch(rawInput);
    if (memoixMatch != null) {
      final link = memoixMatch.group(1)!;
      final shareService = _ref.read(shareServiceProvider);
      final recipe = shareService.parseShareLink(link);
      if (recipe == null) {
        MemoixSnackBar.showError('Could not decode the Memoix link. It may be corrupt or from an incompatible version.');
        return;
      }
      // Validate per AGENTS.md recipe validation rules.
      if (recipe.name.trim().isEmpty && recipe.ingredients.isEmpty && recipe.directions.isEmpty) {
        MemoixSnackBar.showError('The Memoix link does not contain a valid recipe.');
        return;
      }
      _pushScreen(RecipeEditScreen(importedRecipe: recipe));
      return;
    }

    final httpMatch = RegExp(r'(https?://\S+)').firstMatch(rawInput);
    if (httpMatch == null) {
      MemoixSnackBar.showError('Could not find a valid recipe link in the shared text.');
      return;
    }
    final url = httpMatch.group(1)!;

    try {
      final importer = UrlRecipeImporter();
      final result = await importer.importFromUrl(url);

      if (!result.hasMinimumData) {
        MemoixSnackBar.showError('Could not extract a recipe from the shared URL.');
        return;
      }

      if (result.needsUserReview) {
        _pushScreen(ImportReviewScreen(importResult: result, redirectOnSave: true));
      } else {
        final uuid = const Uuid().v4();
        final specializedScreen = SpecializedCourses.getEditScreen(result, uuid);
        if (specializedScreen != null) {
          _pushScreen(specializedScreen);
        } else {
          _pushScreen(RecipeEditScreen(importedRecipe: result.toRecipe(uuid)));
        }
      }
    } catch (e) {
      MemoixSnackBar.showError('Failed to import shared recipe: $e');
    }
  }

  // ── Text share ─────────────────────────────────────────────────────────────

  /// Replicates [AiImportScreen._submitText] → [AiImportScreen._sendToAi(text:)].
  Future<void> _handleTextShare(String text) async {
    if (text.isEmpty) return;

    final settings = _ref.read(aiSettingsProvider);
    if (settings.activeProviders.isEmpty) {
      MemoixSnackBar.showError(
        'No AI provider is configured. Enable one in Settings → Agents to import from text.',
      );
      return;
    }

    try {
      final service = _ref.read(aiServiceProvider);
      final response = await service.sendMessage(AiRequest(text: text));

      if (!response.isSuccess) {
        MemoixSnackBar.showError(
          response.errorMessage ?? 'AI could not process the shared text.',
        );
        return;
      }

      final importResult = RecipeImportResult.fromAi({
        ...response.data!,
        'source': 'ai',
      });

      if (!importResult.hasMinimumData) {
        MemoixSnackBar.showError(
          'The AI could not extract enough data from the shared text.',
        );
        return;
      }

      _pushScreen(ImportReviewScreen(importResult: importResult, redirectOnSave: true));
    } catch (e) {
      MemoixSnackBar.showError('Failed to process shared text: $e');
    }
  }

  // ── Image share ────────────────────────────────────────────────────────────

  /// Routes to AI (if configured) or OCR, matching the logic described in
  /// AGENTS.md and mirroring [AiImportScreen._sendToAi(imageBytes:)] /
  /// [OcrRecipeImporter.processImageFromPath].
  Future<void> _handleImageShare(String path) async {
    if (path.isEmpty) return;

    final settings = _ref.read(aiSettingsProvider);

    if (settings.activeProviders.isNotEmpty) {
      await _handleImageWithAi(path);
    } else {
      await _handleImageWithOcr(path);
    }
  }

  Future<void> _handleImageWithAi(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final service = _ref.read(aiServiceProvider);
      final response = await service.sendMessage(AiRequest(imageBytes: bytes));

      if (!response.isSuccess) {
        MemoixSnackBar.showError(
          response.errorMessage ?? 'AI could not process the shared image.',
        );
        return;
      }

      final importResult = RecipeImportResult.fromAi({
        ...response.data!,
        'source': 'ai',
      });

      if (!importResult.hasMinimumData) {
        MemoixSnackBar.showError(
          'The AI could not extract enough data from the shared image.',
        );
        return;
      }

      _pushScreen(ImportReviewScreen(importResult: importResult, redirectOnSave: true));
    } catch (e) {
      MemoixSnackBar.showError('Failed to process shared image: $e');
    }
  }

  Future<void> _handleImageWithOcr(String path) async {
    try {
      final ocrImporter = _ref.read(ocrImporterProvider);
      final result = await ocrImporter.processImageFromPath(path);

      if (result.cancelled) return;

      if (!result.success) {
        MemoixSnackBar.showError(result.error ?? 'OCR failed on the shared image.');
        return;
      }

      if (result.importResult == null) {
        MemoixSnackBar.showError('Could not extract recipe data from the shared image.');
        return;
      }

      // Validate per AGENTS.md recipe validation rules.
      final importResult = result.importResult!;
      if ((importResult.name?.trim().isEmpty ?? true) &&
          importResult.ingredients.isEmpty &&
          importResult.directions.isEmpty) {
        MemoixSnackBar.showError('The shared image did not contain enough recipe content.');
        return;
      }

      // OCR always routes through ImportReviewScreen (confidence is inherently low).
      _pushScreen(ImportReviewScreen(importResult: importResult, redirectOnSave: true));
    } catch (e) {
      MemoixSnackBar.showError('Failed to scan shared image: $e');
    }
  }

  // ── Navigation helper ──────────────────────────────────────────────────────

  /// Stores [screen] so that [_handleShare] can push it after the loading
  /// dialog has been dismissed. Never navigates immediately.
  void _pushScreen(Widget screen) {
    _pendingScreen = screen;
  }
}

// ── Loading dialog ───────────────────────────────────────────────────────────

/// Full-screen loading overlay shown while a shared payload is being imported.
/// Styled to match the app splash screen: dark background, logo, spinner.
class _ShareLoadingDialog extends StatelessWidget {
  const _ShareLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: const Color(0xFF242424),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/memoix_logo.svg',
                width: 220,
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Provider ────────────────────────────────────────────────────────────────

final shareHandlerServiceProvider = Provider<ShareHandlerService>((ref) {
  return ShareHandlerService(ref);
});
