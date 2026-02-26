import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

import '../../../core/widgets/memoix_snackbar.dart';
import '../../ai/ai_settings_provider.dart';
import '../../ai/models/ai_response.dart';
import '../../ai/services/ai_service.dart';
import '../../ai/services/memoix_ai_service.dart';
import '../../import/models/recipe_import_result.dart';
import '../screens/import_review_screen.dart';

/// Screen for importing recipes via AI.
///
/// Supports four input methods:
///  * **Take Photo** – camera → crop → AI vision
///  * **Choose Photo** – gallery → crop → AI vision
///  * **Recipe URL** – URL text → AI extraction
///  * **Paste Text** – raw text → AI extraction
///
/// All results route through [ImportReviewScreen] for user review.
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
  final _urlController = TextEditingController();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    _textController.dispose();
    _scrollController.dispose();
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
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Sending to AI...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Instructions card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('How it works',
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose a photo, URL, or paste text below.\n'
                    'The AI will extract the recipe for you to review.\n'
                    'Works well with recipe books, handwritten cards, '
                    'and websites the URL importer cannot parse.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Photo capture options ──
          Row(
            children: [
              Expanded(
                child: _CaptureOption(
                  icon: Icons.camera_alt,
                  label: 'Take Photo',
                  onTap: () => _captureImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _CaptureOption(
                  icon: Icons.photo_library,
                  label: 'Choose Photo',
                  onTap: () => _captureImage(ImageSource.gallery),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // ── Recipe URL section ──
          Text(
            'Recipe URL',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste a link the standard importer could not parse',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'https://example.com/recipe...',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: _urlController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _urlController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _urlController.text.trim().isNotEmpty
                ? _submitUrl
                : null,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Extract from URL'),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // ── Paste text section ──
          Text(
            'Paste Recipe Text',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste ingredients, directions, or a full recipe',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            maxLines: 8,
            minLines: 4,
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
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _textController.text.trim().isNotEmpty
                ? _submitText
                : null,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Extract from Text'),
          ),

          // ── Error display ──
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                          color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: _errorMessage!));
                      MemoixSnackBar.show('Error copied to clipboard');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.copy,
                          size: 16,
                          color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ───────────────────────── Image capture ─────────────────────────

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _captureImage(ImageSource source) async {
    // Camera requires mobile; gallery works on all platforms
    if (source == ImageSource.camera && !_isMobile) {
      MemoixSnackBar.show('Camera is only available on mobile devices');
      return;
    }

    setState(() => _errorMessage = null);

    try {
      // Step 1: Pick image
      final picked = await _imagePicker.pickImage(source: source);
      if (!mounted || picked == null) return;

      // Step 2: Crop (mobile only – image_cropper is not available on desktop/web)
      Uint8List imageBytes;
      if (_isMobile) {
        final cropped = await _cropImage(picked.path);
        if (!mounted || cropped == null) return;
        imageBytes = await File(cropped.path).readAsBytes();
      } else {
        imageBytes = await File(picked.path).readAsBytes();
      }

      // Step 3: Send to AI
      await _sendToAi(imageBytes: imageBytes);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to process image: $e');
        _scrollToError();
      }
    }
  }

  Future<CroppedFile?> _cropImage(String imagePath) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Recipe',
          toolbarColor: theme.colorScheme.surface,
          toolbarWidgetColor: theme.colorScheme.onSurface,
          statusBarColor: theme.colorScheme.surface,
          backgroundColor: theme.colorScheme.surface,
          activeControlsWidgetColor: theme.colorScheme.primary,
          dimmedLayerColor: isDark
              ? theme.colorScheme.scrim.withOpacity(0.7)
              : theme.colorScheme.scrim.withOpacity(0.5),
          cropFrameColor: theme.colorScheme.primary,
          cropGridColor: theme.colorScheme.outline,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
          showCropGrid: true,
        ),
        IOSUiSettings(
          title: 'Crop Recipe',
          doneButtonTitle: 'Done',
          cancelButtonTitle: 'Cancel',
        ),
      ],
    );
  }

  // ───────────────────────── URL submission ─────────────────────────

  Future<void> _submitUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Basic URL scheme validation (AGENTS.md: only http/https)
    final lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      setState(() => _errorMessage = 'Only http:// and https:// URLs are supported.');
      _scrollToError();
      return;
    }

    await _sendToAi(
      text: 'Extract the recipe from this URL: $url',
    );
  }

  // ───────────────────────── Text submission ─────────────────────────

  Future<void> _submitText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    await _sendToAi(text: text);
  }

  // ───────────────────────── Shared AI send ─────────────────────────

  Future<void> _sendToAi({String? text, Uint8List? imageBytes}) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final service = ref.read(aiServiceProvider);
    final response = await service.sendMessage(
      AiRequest(text: text, imageBytes: imageBytes),
    );

    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (!response.isSuccess) {
      _handleError(response);
      return;
    }

    final importResult = RecipeImportResult.fromAi({
      ...response.data!,
      'source': 'ai',
    });

    if (!importResult.hasMinimumData) {
      MemoixSnackBar.showError(
        'The AI could not extract enough data. Try a clearer photo or more text.',
      );
      return;
    }

    final result = widget.defaultCourse != null
        ? importResult.copyWith(course: widget.defaultCourse)
        : importResult;

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImportReviewScreen(
          importResult: result,
          redirectOnSave: widget.redirectOnSave,
        ),
      ),
    );
  }

  void _handleError(AiResponse response) {
    setState(() {
      _errorMessage = response.errorMessage ?? 'Something went wrong';
    });
    _scrollToError();
  }

  void _scrollToError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

// ─────────────────────────── Capture card ───────────────────────────

/// Reusable capture-option card matching the OCR scanner screen style.
class _CaptureOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CaptureOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(label, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}
