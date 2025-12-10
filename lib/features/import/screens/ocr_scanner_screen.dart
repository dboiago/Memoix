import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ocr_importer.dart';
import '../../recipes/screens/recipe_edit_screen.dart';

class OCRScannerScreen extends ConsumerStatefulWidget {
  const OCRScannerScreen({super.key});

  @override
  ConsumerState<OCRScannerScreen> createState() => _OCRScannerScreenState();
}

class _OCRScannerScreenState extends ConsumerState<OCRScannerScreen> {
  bool _isProcessing = false;
  String? _extractedText;
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
                                  color: theme.colorScheme.primary),
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
                            '3. The app will extract the text and help you create a recipe',
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
                                color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMessage!)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Extracted text preview
                  if (_extractedText != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Extracted Text',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _extractedText!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _createRecipeFromText,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Recipe from This'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (image == null) return;

      setState(() {
        _isProcessing = true;
        _errorMessage = null;
        _extractedText = null;
      });

      final ocrService = ref.read(ocrImporterProvider);
      final text = await ocrService.extractTextFromImage(image.path);

      setState(() {
        _isProcessing = false;
        _extractedText = text;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to process image: $e';
      });
    }
  }

  void _createRecipeFromText() {
    if (_extractedText == null) return;

    // Navigate to recipe edit screen with extracted text
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RecipeEditScreen(
          ocrText: _extractedText,
        ),
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
