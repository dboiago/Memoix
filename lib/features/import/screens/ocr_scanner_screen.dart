import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../../../app/theme/colors.dart';
import '../services/ocr_importer.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
import 'import_review_screen.dart';

class OCRScannerScreen extends ConsumerStatefulWidget {
  final String? defaultCourse;
  
  const OCRScannerScreen({super.key, this.defaultCourse});

  @override
  ConsumerState<OCRScannerScreen> createState() => _OCRScannerScreenState();
}

class _OCRScannerScreenState extends ConsumerState<OCRScannerScreen> {
  bool _isProcessing = false;
  OcrResult? _ocrResult;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Recipe'),
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing image...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instructions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: theme.colorScheme.primary,),
                              const SizedBox(width: 8),
                              Text(
                                'How to scan a recipe',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. Take a clear photo of a recipe from a cookbook or handwritten note\n'
                            '2. Make sure the text is readable and well-lit\n'
                            '3. The app will extract the text and help you organize it into a recipe',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Capture options
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

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: theme.colorScheme.error,),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMessage!)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Result preview
                  if (_ocrResult != null && _ocrResult!.success) ...[
                    const SizedBox(height: 24),
                    _buildResultPreview(theme, _ocrResult!),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildResultPreview(ThemeData theme, OcrResult result) {
    final confidence = result.importResult?.overallConfidence ?? 0.0;
    final ingredientCount = result.importResult?.ingredients.length ?? 0;
    final directionCount = result.importResult?.directions.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Confidence summary
        Card(
          color: confidence < 0.5 
              ? MemoixColors.warningContainer 
              : MemoixColors.successContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      confidence < 0.5 ? Icons.warning : Icons.check_circle,
                      color: confidence < 0.5 ? MemoixColors.warning : MemoixColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        confidence < 0.5
                            ? 'Text extracted! Please review and organize.'
                            : 'Recipe structure detected!',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Found: $ingredientCount possible ingredients, $directionCount directions',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Raw text preview (collapsible)
        ExpansionTile(
          leading: const Icon(Icons.text_fields),
          title: const Text('Raw Text'),
          subtitle: Text(
            '${result.rawText?.split('\n').length ?? 0} lines extracted',
            style: theme.textTheme.bodySmall,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest,
              child: SelectableText(
                result.rawText ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Action button
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _navigateToReview(result),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Review & Create Recipe'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      final ocrService = ref.read(ocrImporterProvider);
      
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
        _ocrResult = null;
      });

      // Let the OCR service handle image picking and processing
      final result = source == ImageSource.camera 
          ? await ocrService.scanFromCamera() 
          : await ocrService.scanFromGallery();

      if (!mounted) return;

      if (result.cancelled) {
        setState(() => _isProcessing = false);
        return;
      }

      if (!result.success) {
        setState(() {
          _isProcessing = false;
          _errorMessage = result.error ?? 'Failed to process image';
        });
        return;
      }

      setState(() {
        _isProcessing = false;
        _ocrResult = result;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to process image: $e';
      });
    }
  }

  void _navigateToReview(OcrResult result) {
    if (result.importResult == null) {
      // Fallback: use the old flow with raw text
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipeEditScreen(
            ocrText: result.rawText,
            defaultCourse: widget.defaultCourse,
          ),
        ),
      );
      return;
    }

    // Set the default course if provided
    final importResult = widget.defaultCourse != null && result.importResult!.course == null
        ? result.importResult!.copyWith(course: widget.defaultCourse)
        : result.importResult!;

    // Always go to review screen for OCR since confidence is typically low
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ImportReviewScreen(importResult: importResult),
      ),
    );
  }
}

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
              Text(
                label,
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
