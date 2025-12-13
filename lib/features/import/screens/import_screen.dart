import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../services/url_importer.dart';
import '../services/ocr_importer.dart';
import '../models/recipe_import_result.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
import 'import_review_screen.dart';
import 'qr_scanner_screen.dart';
import 'ocr_scanner_screen.dart';
import 'ocr_multi_image_screen.dart';

class ImportScreen extends ConsumerStatefulWidget {
  final String? defaultCourse;
  
  const ImportScreen({super.key, this.defaultCourse});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Recipe'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Create manually
            _ImportOption(
              icon: Icons.edit,
              title: 'Create Manually',
              description: 'Write a new recipe from scratch',
              color: Colors.blue,
              onTap: () => _createManually(context),
            ),

            const SizedBox(height: 16),

            // Scan from photo
            _ImportOption(
              icon: Icons.camera_alt,
              title: 'Scan from Photo',
              description: 'Take a photo of a recipe book or handwritten notes',
              color: Colors.green,
              onTap: () => _scanFromCamera(context),
            ),

            const SizedBox(height: 16),

            // Scan multiple pages
            _ImportOption(
              icon: Icons.collections,
              title: 'Scan Multi-Page Recipe',
              description: 'Take photos of multiple recipe pages (ingredients, directions, etc.)',
              color: Colors.teal,
              onTap: () => _scanMultipleImages(context),
            ),

            const SizedBox(height: 16),

            // Pick from gallery
            _ImportOption(
              icon: Icons.photo_library,
              title: 'Import from Gallery',
              description: 'Choose an existing photo to scan',
              color: Colors.orange,
              onTap: () => _scanFromGallery(context),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Import from URL
            Text(
              'Import from URL',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paste a link from popular recipe websites',
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
              onPressed: _urlController.text.isNotEmpty && !_isLoading
                  ? () => _importFromUrl(context)
                  : null,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_isLoading ? 'Importing...' : 'Import Recipe'),
            ),

            if (_error != null) ...[
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
                        _error!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Import shared recipe
            _ImportOption(
              icon: Icons.qr_code_scanner,
              title: 'Scan QR Code',
              description: 'Import a recipe shared via QR code',
              color: Colors.purple,
              onTap: () => _scanQrCode(context),
            ),

            const SizedBox(height: 16),

            // Supported sites info
            ExpansionTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Supported Websites'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Memoix can import recipes from most cooking websites that use '
                    'standard recipe markup (JSON-LD). This includes:\n\n'
                    '• AllRecipes\n'
                    '• Food Network\n'
                    '• Serious Eats\n'
                    '• Bon Appétit\n'
                    '• NYT Cooking\n'
                    '• BBC Good Food\n'
                    '• And many more!\n\n'
                    'If a site doesn\'t work, you can always create the recipe manually.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _createManually(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RecipeEditScreen(),
      ),
    );
  }

  Future<void> _scanFromCamera(BuildContext context) async {
    final ocrImporter = ref.read(ocrImporterProvider);
    final result = await ocrImporter.scanFromCamera();
    _handleOcrResult(context, result);
  }

  void _scanMultipleImages(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OCRMultiImageScreen(),
      ),
    );
  }

  Future<void> _scanFromGallery(BuildContext context) async {
    final ocrImporter = ref.read(ocrImporterProvider);
    final result = await ocrImporter.scanFromGallery();
    _handleOcrResult(context, result);
  }

  void _handleOcrResult(BuildContext context, OcrResult result) {
    if (result.cancelled) return;

    if (!result.success) {
      setState(() => _error = result.error);
      return;
    }

    // Navigate to edit screen with pre-filled recipe
    if (result.recipe != null && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipeEditScreen(
            initialRecipe: result.recipe,
            ocrText: result.rawText,
          ),
        ),
      );
    }
  }

  Future<void> _importFromUrl(BuildContext context) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final importer = UrlRecipeImporter();
      final result = await importer.importFromUrl(url);

      if (!result.hasMinimumData) {
        setState(() => _error = 'Could not extract recipe from this URL');
        return;
      }

      if (context.mounted) {
        // Route based on confidence
        if (result.needsUserReview) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ImportReviewScreen(importResult: result),
            ),
          );
        } else {
          final recipe = result.toRecipe(const Uuid().v4());
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => RecipeEditScreen(importedRecipe: recipe),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scanQrCode(BuildContext context) {
    // Navigate to QR scanner screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(),
      ),
    );
  }
}

class _ImportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ImportOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
