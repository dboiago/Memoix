import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

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
                                'How to scan',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Focus: Use a well-lit, clear photo.\n'
                            'Frame: Capture only the recipe you want\n'
                            'Review: The app will extract the text for you to organize',
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
                ],
              ),
            ),
    );
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      final ocrService = ref.read(ocrImporterProvider);
      
      setState(() {
        _errorMessage = null;
      });

      // Step 1: Pick image (don't show processing yet - cropper is interactive)
      final imagePath = source == ImageSource.camera 
          ? await ocrService.pickImageFromCamera() 
          : await ocrService.pickImageFromGallery();

      if (!mounted) return;

      if (imagePath == null) {
        // User cancelled
        return;
      }

      // Step 2: Crop the image
      final croppedFile = await _cropImage(imagePath);
      
      if (!mounted) return;
      
      if (croppedFile == null) {
        // User cancelled cropping
        return;
      }

      // Step 3: Process the cropped image
      setState(() {
        _isProcessing = true;
      });

      final result = await ocrService.processImageFromPath(croppedFile.path);

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

      // Success - navigate directly to review screen
      setState(() => _isProcessing = false);
      _navigateToReview(result);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to process image: $e';
      });
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

    // Use push instead of pushReplacement so back button returns to camera
    Navigator.of(context).push(
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
