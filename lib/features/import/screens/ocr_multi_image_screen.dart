import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ocr_importer.dart';
import '../models/recipe_import_result.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
import 'import_review_screen.dart';
import 'multi_image_picker_screen.dart';

class OCRMultiImageScreen extends ConsumerStatefulWidget {
  const OCRMultiImageScreen({super.key});

  @override
  ConsumerState<OCRMultiImageScreen> createState() =>
      _OCRMultiImageScreenState();
}

class _OCRMultiImageScreenState extends ConsumerState<OCRMultiImageScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  double _processingProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Multi-Page Recipe'),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(value: _processingProgress),
                  const SizedBox(height: 16),
                  const Text('Processing images...'),
                  if (_processingProgress > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${(_processingProgress * 100).toInt()}%',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instructions card
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
                              Text(
                                'Scan Multi-Page Recipe',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '• Take separate photos of each page (ingredients, directions, etc.)\n'
                            '• The app will extract text from all pages and merge them\n'
                            '• Reorder pages if needed before processing\n'
                            '• All images will be saved with your recipe',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action button
                  FilledButton.icon(
                    onPressed: _selectAndProcessImages,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Select Recipe Pages'),
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
                                color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMessage!)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Tips section
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline,
                                  color: theme.colorScheme.secondary),
                              const SizedBox(width: 8),
                              Text(
                                'Tips for best results',
                                style: theme.textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '✓ Use good lighting when photographing recipes\n'
                            '✓ Make text large and clear in each photo\n'
                            '✓ Keep pages aligned and readable\n'
                            '✓ 2-3 images per recipe is ideal\n'
                            '✓ Check extracted text in the review screen',
                            style: TextStyle(height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _selectAndProcessImages() async {
    // Navigate to multi-image picker
    final imagePaths = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => const MultiImagePickerScreen(
          minImages: 1,
          maxImages: 10,
          title: 'Select Recipe Pages',
          description: 'Choose photos of recipe pages (ingredients, directions, etc.)',
        ),
      ),
    );

    if (imagePaths == null || imagePaths.isEmpty) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _processingProgress = 0.0;
    });

    try {
      final ocrService = ref.read(ocrImporterProvider);
      final result = await ocrService.scanMultipleImages(imagePaths);

      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _isProcessing = false;
          _errorMessage = result.error ?? 'Failed to process images';
        });
        return;
      }

      // Navigate to review screen
      if (result.importResult != null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ImportReviewScreen(
              importResult: result.importResult!,
            ),
          ),
        );
      } else {
        // Fallback to edit screen with raw text
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RecipeEditScreen(
              ocrText: result.rawText,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error: $e';
      });
    }
  }
}
