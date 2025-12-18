import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/memoix_snackbar.dart';

/// Screen for picking multiple images (for multi-page recipe imports)
class MultiImagePickerScreen extends StatefulWidget {
  final String title;
  final String description;
  final int minImages;
  final int maxImages;

  const MultiImagePickerScreen({
    super.key,
    this.title = 'Select Recipe Images',
    this.description = 'Add multiple images (ingredients, directions, etc.)',
    this.minImages = 1,
    this.maxImages = 10,
  });

  @override
  State<MultiImagePickerScreen> createState() => _MultiImagePickerScreenState();
}

class _MultiImagePickerScreenState extends State<MultiImagePickerScreen> {
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFromGallery() async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (images.isNotEmpty) {
        setState(() {
          // Limit to maxImages total
          _selectedImages.addAll(images);
          if (_selectedImages.length > widget.maxImages) {
            _selectedImages.removeRange(widget.maxImages, _selectedImages.length);
          }
        });
      }
    } catch (e) {
      MemoixSnackBar.showError('Failed to pick images: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null && _selectedImages.length < widget.maxImages) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      MemoixSnackBar.showError('Failed to capture image: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final image = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, image);
    });
  }

  void _confirm() {
    if (_selectedImages.length < widget.minImages) {
      MemoixSnackBar.showError(
        'Please select at least ${widget.minImages} image${widget.minImages > 1 ? 's' : ''}',
      );
      return;
    }

    // Return the paths of selected images
    Navigator.pop(context, _selectedImages.map((f) => f.path).toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  '${_selectedImages.length}/${widget.maxImages}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _pickFromCamera,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                      ),
                    ),
                  ],
                ),
                if (_selectedImages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 64,
                            color: theme.colorScheme.outline.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No images selected',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap gallery or camera to add recipe images',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Reorder images by dragging (top = ingredient page 1)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          // Selected images grid
          if (_selectedImages.isNotEmpty)
            Expanded(
              child: ReorderableListView(
                padding: const EdgeInsets.all(16),
                onReorder: _reorderImages,
                children: [
                  for (int i = 0; i < _selectedImages.length; i++)
                    _ImageTile(
                      key: ValueKey(_selectedImages[i].path),
                      index: i,
                      imagePath: _selectedImages[i].path,
                      onRemove: () => _removeImage(i),
                    ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedImages.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: const Text('Continue'),
            )
          : null,
    );
  }
}

class _ImageTile extends StatelessWidget {
  final int index;
  final String imagePath;
  final VoidCallback onRemove;

  const _ImageTile({
    super.key,
    required this.index,
    required this.imagePath,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text('Image ${index + 1}'),
        subtitle: Text(
          'Page ${index + 1}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: SizedBox(
          width: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onRemove,
                tooltip: 'Remove',
                iconSize: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
