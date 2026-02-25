import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../ai/ai_settings_provider.dart';
import '../../ai/models/ai_response.dart';
import '../../ai/services/ai_service.dart';
import '../../ai/services/memoix_ai_service.dart';
import '../../import/models/recipe_import_result.dart';
import '../screens/import_review_screen.dart';

/// Screen for importing recipes via AI text extraction.
///
/// The user pastes raw recipe text (from a book, blog, notes, etc.)
/// and the AI provider parses it into structured recipe data, which
/// is then routed to [ImportReviewScreen] for the user to confirm.
///
/// Access is gated on AI being enabled with at least one active provider.
class AiImportScreen extends ConsumerStatefulWidget {
  final String? defaultCourse;
  final bool redirectOnSave;

  const AiImportScreen({
    super.key,
    this.defaultCourse,
    this.redirectOnSave = false,
  });

  @override
  ConsumerState<AiImportScreen> createState() => _AiImportScreenState();
}

class _AiImportScreenState extends ConsumerState<AiImportScreen> {
  final _textController = TextEditingController();
  bool _isLoading = false;

  /// Prevents duplicate rapid submissions.
  bool _submitted = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(aiSettingsProvider);
    final hasActive = settings.activeProviders.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Import')),
      body: hasActive ? _buildActiveBody(theme) : _buildNoProviderBody(theme),
    );
  }

  // ───────────────────────── No-provider state ─────────────────────────

  Widget _buildNoProviderBody(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No AI Provider Configured',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enable at least one provider and add an API key in '
              'Settings → Agents before using AI import.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Active body ─────────────────────────

  Widget _buildActiveBody(ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Paste Recipe Text',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paste ingredients, directions, or a full recipe and '
                  'the AI will extract structured data for you to review.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _textController,
                  maxLines: 12,
                  minLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Paste recipe text here...',
                    border: const OutlineInputBorder(),
                    suffixIcon: _textController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _textController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ),
        // Bottom action area
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _canSubmit ? _submit : null,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isLoading ? 'Extracting...' : 'Extract Recipe'),
            ),
          ),
        ),
      ],
    );
  }

  bool get _canSubmit =>
      !_isLoading &&
      !_submitted &&
      _textController.text.trim().isNotEmpty;

  // ───────────────────────── Submission ─────────────────────────

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _submitted = true;
    });

    final service = ref.read(aiServiceProvider);
    final response = await service.sendMessage(
      AiRequest(text: text),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _submitted = false;
    });

    if (!response.isSuccess) {
      _handleError(response);
      return;
    }

    // Build import result from AI response
    final importResult = RecipeImportResult.fromAi({
      ...response.data!,
      'source': 'ai',
    });

    if (!importResult.hasMinimumData) {
      MemoixSnackBar.showError(
        'The AI could not extract enough data. Try pasting more text.',
      );
      return;
    }

    // Apply default course if provided
    final result = widget.defaultCourse != null
        ? importResult.copyWith(course: widget.defaultCourse)
        : importResult;

    if (!mounted) return;

    // Always route through review so the user can verify AI output
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ImportReviewScreen(
          importResult: result,
          redirectOnSave: widget.redirectOnSave,
        ),
      ),
    );
  }

  void _handleError(AiResponse response) {
    switch (response.errorType) {
      case AiErrorType.noToken:
      case AiErrorType.invalidToken:
      case AiErrorType.disabled:
        MemoixSnackBar.showError(response.errorMessage ?? 'Configuration error');
        break;
      case AiErrorType.rateLimited:
        MemoixSnackBar.showError(response.errorMessage ?? 'Rate limited');
        break;
      case AiErrorType.noInternet:
        MemoixSnackBar.showError(response.errorMessage ?? 'No connection');
        break;
      case AiErrorType.timeout:
        MemoixSnackBar.showError(response.errorMessage ?? 'Request timed out');
        break;
      default:
        MemoixSnackBar.showError(
          response.errorMessage ?? 'Something went wrong',
        );
    }
  }
}
