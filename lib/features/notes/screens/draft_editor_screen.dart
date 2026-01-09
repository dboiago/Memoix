
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../core/widgets/memoix_snackbar.dart';
import '../models/scratch_pad.dart';

class DraftEditorScreen extends ConsumerStatefulWidget {
	final RecipeDraft? initialDraft;

	const DraftEditorScreen({Key? key, this.initialDraft}) : super(key: key);

	@override
	ConsumerState<DraftEditorScreen> createState() => _DraftEditorScreenState();
}


class _DraftEditorScreenState extends ConsumerState<DraftEditorScreen> {
	static const _uuid = Uuid();

	late final TextEditingController _nameController;
	late final TextEditingController _servesController;
	late final TextEditingController _timeController;
	late final TextEditingController _notesController;

	final List<_DraftIngredientRow> _ingredientRows = [];
	final List<_DirectionRow> _directionRows = [];
	final List<String> _stepImages = [];
	final Map<int, int> _stepImageMap = {};
	final List<String> _pairedRecipeIds = [];

	String? _headerImage;
	bool _isSaving = false;
	bool _isLoading = true;
	RecipeDraft? _existingDraft;

	// --- Restored: Course selector ---
	String _selectedCourse = 'mains';

	@override
	void initState() {
		super.initState();
		_nameController = TextEditingController();
		_servesController = TextEditingController();
		_timeController = TextEditingController();
		_notesController = TextEditingController();
		_loadDraft();
	}

	Future<void> _loadDraft() async {
		RecipeDraft? draft = widget.initialDraft;
		if (draft != null) {
			_existingDraft = draft;
			_nameController.text = draft.name;
			_servesController.text = draft.serves ?? '';
			_timeController.text = draft.time ?? '';
			_notesController.text = draft.notes;
			_stepImages.addAll(draft.stepImages);
			for (final mapping in draft.stepImageMap) {
				final parts = mapping.split(':');
				if (parts.length == 2) {
					final stepIndex = int.tryParse(parts[0]);
					final imageIndex = int.tryParse(parts[1]);
					if (stepIndex != null && imageIndex != null) {
						_stepImageMap[stepIndex] = imageIndex;
					}
				}
			}
			_pairedRecipeIds.addAll(draft.pairedRecipeIds);
			// --- Restore course field ---
			_selectedCourse = (draft is dynamic && draft.course != null && (draft.course as String).isNotEmpty)
				? draft.course as String
				: 'mains';
			// Ingredients
			for (final ingredient in draft.structuredIngredients) {
				_ingredientRows.add(_DraftIngredientRow(
					nameController: TextEditingController(text: ingredient.name),
					amountController: TextEditingController(text: ingredient.quantity ?? ''),
					unitController: TextEditingController(text: ingredient.unit ?? ''),
					prepController: TextEditingController(text: ingredient.preparation ?? ''),
				));
			}
			// Directions
			for (final direction in draft.structuredDirections) {
				_directionRows.add(_DirectionRow(controller: TextEditingController(text: direction)));
			}
		} else {
			_selectedCourse = 'mains';
		}
		if (_ingredientRows.isEmpty) {
			_ingredientRows.add(_DraftIngredientRow(
				nameController: TextEditingController(),
				amountController: TextEditingController(),
				unitController: TextEditingController(),
				prepController: TextEditingController(),
			));
		}
		if (_directionRows.isEmpty) {
			_directionRows.add(_DirectionRow(controller: TextEditingController()));
		}
		setState(() => _isLoading = false);
	}

	@override
	void dispose() {
		_nameController.dispose();
		_servesController.dispose();
		_timeController.dispose();
		_notesController.dispose();
		for (final row in _ingredientRows) {
			row.dispose();
		}
		for (final row in _directionRows) {
			row.dispose();
		}
		super.dispose();
	}

	Future<void> _saveDraft() async {
		if (_nameController.text.trim().isEmpty) {
			MemoixSnackBar.showError('Please enter a recipe name');
			return;
		}
		setState(() => _isSaving = true);
		try {
			final ingredients = <DraftIngredient>[];
			for (final row in _ingredientRows) {
				final name = row.nameController.text.trim();
				if (name.isEmpty) continue;
				ingredients.add(DraftIngredient(
					name: name,
					quantity: row.amountController.text.trim().isEmpty ? null : row.amountController.text.trim(),
					unit: row.unitController.text.trim().isEmpty ? null : row.unitController.text.trim(),
					preparation: row.prepController.text.trim().isEmpty ? null : row.prepController.text.trim(),
				));
			}
			final directions = _directionRows
					.map((row) => row.controller.text.trim())
					.where((text) => text.isNotEmpty)
					.toList();
			final draft = _existingDraft ?? RecipeDraft();
			draft
				..uuid = draft.uuid.isNotEmpty ? draft.uuid : _uuid.v4()
				..name = _nameController.text.trim()
				..serves = _servesController.text.trim().isEmpty ? null : _servesController.text.trim()
				..time = _timeController.text.trim().isEmpty ? null : _timeController.text.trim()
				..structuredIngredients = ingredients
				..structuredDirections = directions
				..notes = _notesController.text.trim()
				..stepImages = List<String>.from(_stepImages)
				..stepImageMap = _stepImageMap.entries.map((e) => '${e.key}:${e.value}').toList()
				..pairedRecipeIds = List<String>.from(_pairedRecipeIds)
				..imagePath = _headerImage
				..updatedAt = DateTime.now()
				..course = _selectedCourse;
			await ref.read(scratchPadRepositoryProvider).updateDraft(draft);
			if (mounted) {
				Navigator.of(context).pop();
				MemoixSnackBar.showSaved(
					itemName: draft.name,
					actionLabel: 'View',
					onView: () {},
				);
			}
		} catch (e) {
			MemoixSnackBar.showError('Error saving draft: $e');
		} finally {
			setState(() => _isSaving = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final allRecipesAsync = ref.watch(allRecipesProvider);
		if (_isLoading) {
			return Scaffold(
				appBar: AppBar(title: const Text('Loading...')),
				body: const Center(child: CircularProgressIndicator()),
			);
		}
		return Scaffold(
			appBar: AppBar(
				title: Text(_existingDraft != null ? 'Edit Draft' : 'New Draft'),
				actions: [
					TextButton.icon(
						onPressed: _isSaving ? null : _saveDraft,
						icon: _isSaving
								? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
								: const Icon(Icons.save),
						label: const Text('Save'),
					),
					const SizedBox(width: 8),
				],
			),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						// Recipe image (optional)
						_buildImagePicker(theme),
						const SizedBox(height: 16),
						TextField(
							controller: _nameController,
							decoration: const InputDecoration(
								labelText: 'Recipe Name *',
								hintText: 'e.g., My Draft Recipe',
							),
							textCapitalization: TextCapitalization.words,
						),
						const SizedBox(height: 16),
						// --- Restored: Course selector ---
						DropdownButtonFormField<String>(
							value: _selectedCourse,
							decoration: const InputDecoration(labelText: 'Course'),
							items: const [
								DropdownMenuItem(value: 'mains', child: Text('Mains')),
								DropdownMenuItem(value: 'desserts', child: Text('Desserts')),
								DropdownMenuItem(value: 'drinks', child: Text('Drinks')),
								DropdownMenuItem(value: 'sides', child: Text('Sides')),
								DropdownMenuItem(value: 'apps', child: Text('Apps')),
							],
							onChanged: (value) {
								if (value != null) setState(() => _selectedCourse = value);
							},
						),
						const SizedBox(height: 16),
						Row(
							children: [
								Expanded(
									child: TextField(
										controller: _servesController,
										decoration: const InputDecoration(
											labelText: 'Serves',
											hintText: 'e.g., 4-6',
										),
									),
								),
								const SizedBox(width: 12),
								Expanded(
									child: TextField(
										controller: _timeController,
										decoration: const InputDecoration(
											labelText: 'Time',
											hintText: 'e.g., 40 min',
										),
									),
								),
							],
						),
						const SizedBox(height: 24),
						// Ingredients
						Text('Ingredients', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
						const SizedBox(height: 8),
						ListView.builder(
							shrinkWrap: true,
							physics: const NeverScrollableScrollPhysics(),
							itemCount: _ingredientRows.length,
							itemBuilder: (context, index) {
								return _buildIngredientRowWidget(index);
							},
						),
						TextButton.icon(
							onPressed: () {
								setState(() {
									_ingredientRows.add(_DraftIngredientRow(
										nameController: TextEditingController(),
										amountController: TextEditingController(),
										unitController: TextEditingController(),
										prepController: TextEditingController(),
									));
								});
							},
							icon: const Icon(Icons.add),
							label: const Text('Add Ingredient'),
						),
						const SizedBox(height: 24),
						// Directions
						Text('Directions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
						const SizedBox(height: 8),
						ListView.builder(
							shrinkWrap: true,
							physics: const NeverScrollableScrollPhysics(),
							itemCount: _directionRows.length,
							itemBuilder: (context, index) {
								return _buildDirectionRowWidget(index, theme);
							},
						),
						TextButton.icon(
							onPressed: () {
								setState(() {
									_directionRows.add(_DirectionRow(controller: TextEditingController()));
								});
							},
							icon: const Icon(Icons.add),
							label: const Text('Add Step'),
						),
						const SizedBox(height: 24),
						// Step Images Gallery
						_buildStepImagesGallery(theme),
						const SizedBox(height: 24),
						// --- Restored: Pairs With UI ---
						_buildPairsWithSection(theme, allRecipesAsync),
						const SizedBox(height: 24),
						// Comments/Notes
						Text('Notes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
						const SizedBox(height: 8),
						TextField(
							controller: _notesController,
							decoration: const InputDecoration(
								hintText: 'Optional notes, tips, etc.',
							),
							maxLines: 4,
							minLines: 2,
						),
						const SizedBox(height: 32),
						// --- Convert to Recipe Button ---
						FilledButton.icon(
							icon: const Icon(Icons.restaurant_menu),
							label: const Text('Convert to Recipe'),
							style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
							onPressed: _convertToRecipe,
						),
						const SizedBox(height: 16),
					],
				),
			),
		);
	}

	// --- Pairs With Section ---
	Widget _buildPairsWithSection(ThemeData theme, AsyncValue<List<Recipe>> allRecipesAsync) {
		final allRecipes = allRecipesAsync.valueOrNull ?? [];
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text('Pairs With', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
				const SizedBox(height: 8),
				if (_pairedRecipeIds.isNotEmpty)
					Wrap(
						spacing: 8,
						runSpacing: 8,
						children: _pairedRecipeIds.map((uuid) {
							final recipe = allRecipes.where((r) => r.uuid == uuid).firstOrNull;
							final name = recipe?.name ?? 'Unknown';
							return Chip(
								label: Text(name),
								backgroundColor: theme.colorScheme.surfaceContainerHighest,
								labelStyle: TextStyle(color: theme.colorScheme.onSurface),
								visualDensity: VisualDensity.compact,
								deleteIcon: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurface),
								onDeleted: () {
									setState(() {
										_pairedRecipeIds.remove(uuid);
									});
								},
							);
						}).toList(),
					),
				if (_pairedRecipeIds.length < 3) ...[
					if (_pairedRecipeIds.isNotEmpty) const SizedBox(height: 8),
					OutlinedButton.icon(
						onPressed: () => _showRecipeSelector(allRecipes),
						icon: const Icon(Icons.add, size: 18),
						label: const Text('Add Recipe'),
						style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
					),
				],
			],
		);
	}

	void _showRecipeSelector(List<Recipe> allRecipes) {
		// Filter out: already paired
		final availableRecipes = allRecipes.where((r) => !_pairedRecipeIds.contains(r.uuid)).toList();
		availableRecipes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
		final theme = Theme.of(context);
		final searchController = TextEditingController();
		var filteredRecipes = List<Recipe>.from(availableRecipes);
		showDialog(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (ctx, setDialogState) {
					return AlertDialog(
						title: const Text('Select Recipe'),
						content: SizedBox(
							width: double.maxFinite,
							height: 400,
							child: Column(
								children: [
									TextField(
										controller: searchController,
										decoration: const InputDecoration(
											hintText: 'Search recipes...',
											prefixIcon: Icon(Icons.search),
											isDense: true,
										),
										onChanged: (query) {
											setDialogState(() {
												if (query.isEmpty) {
													filteredRecipes = List<Recipe>.from(availableRecipes);
												} else {
													filteredRecipes = availableRecipes.where((r) =>
														r.name.toLowerCase().contains(query.toLowerCase())
													).toList();
												}
											});
										},
									),
									const SizedBox(height: 12),
									Expanded(
										child: filteredRecipes.isEmpty
											? Center(child: Text('No recipes found', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
											: ListView.builder(
													itemCount: filteredRecipes.length,
													itemBuilder: (context, index) {
														final recipe = filteredRecipes[index];
														return ListTile(
															title: Text(recipe.name),
															dense: true,
															onTap: () {
																setState(() {
																	_pairedRecipeIds.add(recipe.uuid);
																});
																Navigator.pop(ctx);
															},
														);
													},
												),
									),
								],
							),
						),
						actions: [
							TextButton(
								onPressed: () => Navigator.pop(ctx),
								child: const Text('Cancel'),
							),
						],
					);
				},
			),
		);
	}

	// --- Convert to Recipe ---
	Future<void> _convertToRecipe() async {
		await _saveDraft();
		// Build Recipe object from draft
		final ingredients = _ingredientRows.map((row) {
			final name = row.nameController.text.trim();
			if (name.isEmpty) return null;
			final amount = row.amountController.text.trim();
			final unit = row.unitController.text.trim();
			final prep = row.prepController.text.trim();
			return Ingredient()
				..name = name
				..amount = amount.isEmpty ? null : amount
				..unit = unit.isEmpty ? null : unit
				..preparation = prep.isEmpty ? null : prep;
		}).whereType<Ingredient>().toList();
		final directions = _directionRows.map((row) => row.controller.text.trim()).where((t) => t.isNotEmpty).toList();
		final recipe = Recipe.create(
			uuid: _uuid.v4(),
			name: _nameController.text.trim(),
			course: _selectedCourse,
			ingredients: ingredients,
			directions: directions,
			comments: _notesController.text.trim(),
			imageUrl: _headerImage,
			stepImages: List<String>.from(_stepImages),
			stepImageMap: _stepImageMap.entries.map((e) => '${e.key}:${e.value}').toList(),
			pairedRecipeIds: List<String>.from(_pairedRecipeIds),
		);
		if (mounted) {
			Navigator.of(context).push(
				MaterialPageRoute(
					builder: (_) => RecipeEditScreen(importedRecipe: recipe),
				),
			);
		}
	}

	Widget _buildIngredientRowWidget(int index) {
		final row = _ingredientRows[index];
		return Row(
			children: [
				Expanded(
					flex: 2,
					child: TextField(
						controller: row.nameController,
						decoration: const InputDecoration(hintText: 'Ingredient'),
					),
				),
				const SizedBox(width: 8),
				SizedBox(
					width: 60,
					child: TextField(
						controller: row.amountController,
						decoration: const InputDecoration(hintText: 'Qty'),
					),
				),
				const SizedBox(width: 8),
				SizedBox(
					width: 60,
					child: TextField(
						controller: row.unitController,
						decoration: const InputDecoration(hintText: 'Unit'),
					),
				),
				const SizedBox(width: 8),
				Expanded(
					flex: 2,
					child: TextField(
						controller: row.prepController,
						decoration: const InputDecoration(hintText: 'Prep/Notes'),
					),
				),
				IconButton(
					icon: const Icon(Icons.delete_outline),
					onPressed: _ingredientRows.length > 1
							? () {
									setState(() {
										row.dispose();
										_ingredientRows.removeAt(index);
									});
								}
							: null,
				),
			],
		);
	}

	Widget _buildDirectionRowWidget(int index, ThemeData theme) {
		final row = _directionRows[index];
		return Row(
			children: [
				Expanded(
					child: TextField(
						controller: row.controller,
						decoration: InputDecoration(hintText: 'Step ${index + 1}'),
						maxLines: 2,
					),
				),
				IconButton(
					icon: const Icon(Icons.delete_outline),
					onPressed: _directionRows.length > 1
							? () {
									setState(() {
										row.dispose();
										_directionRows.removeAt(index);
									});
								}
							: null,
				),
			],
		);
	}

	Widget _buildImagePicker(ThemeData theme) {
		final hasImage = _headerImage != null && _headerImage!.isNotEmpty;
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text('Recipe Photo', style: theme.textTheme.titleSmall),
				const SizedBox(height: 8),
				GestureDetector(
					onTap: _pickHeaderImage,
					child: Container(
						height: 180,
						decoration: BoxDecoration(
							color: theme.colorScheme.surfaceVariant,
							borderRadius: BorderRadius.circular(12),
							border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
						),
						child: hasImage
								? Stack(
										fit: StackFit.expand,
										children: [
											ClipRRect(
												borderRadius: BorderRadius.circular(11),
												child: _buildHeaderImageWidget(),
											),
											Positioned(
												top: 8,
												right: 8,
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														_imageActionButton(
															icon: Icons.edit,
															onTap: _pickHeaderImage,
															theme: theme,
														),
														const SizedBox(width: 8),
														_imageActionButton(
															icon: Icons.delete,
															onTap: _removeHeaderImage,
															theme: theme,
														),
													],
												),
											),
										],
									)
								: Center(
										child: Column(
											mainAxisAlignment: MainAxisAlignment.center,
											children: [
												Icon(Icons.add_photo_alternate_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
												const SizedBox(height: 8),
												Text('Tap to add photo', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
											],
										),
									),
					),
				),
			],
		);
	}

	Widget _buildHeaderImageWidget() {
		if (_headerImage == null) return const SizedBox.shrink();
		if (_headerImage!.startsWith('http://') || _headerImage!.startsWith('https://')) {
			return Image.network(_headerImage!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 48)),);
		} else {
			return Image.file(File(_headerImage!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 48)),);
		}
	}

	void _pickHeaderImage() {
		showModalBottomSheet(
			context: context,
			builder: (ctx) => SafeArea(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						ListTile(
							leading: const Icon(Icons.camera_alt),
							title: const Text('Take Photo'),
							onTap: () {
								Navigator.pop(ctx);
								_pickImageForHeader(ImageSource.camera);
							},
						),
						ListTile(
							leading: const Icon(Icons.photo_library),
							title: const Text('Choose from Gallery'),
							onTap: () {
								Navigator.pop(ctx);
								_pickImageForHeader(ImageSource.gallery);
							},
						),
						ListTile(
							leading: const Icon(Icons.close),
							title: const Text('Cancel'),
							onTap: () => Navigator.pop(ctx),
						),
					],
				),
			),
		);
	}

	Future<void> _pickImageForHeader(ImageSource source) async {
		try {
			final picker = ImagePicker();
			final pickedFile = await picker.pickImage(
				source: source,
				maxWidth: 1200,
				maxHeight: 1200,
				imageQuality: 85,
			);
			if (pickedFile != null) {
				final appDir = await getApplicationDocumentsDirectory();
				final imagesDir = Directory('${appDir.path}/recipe_images');
				if (!await imagesDir.exists()) {
					await imagesDir.create(recursive: true);
				}
				final fileName = '${const Uuid().v4()}${path.extension(pickedFile.path)}';
				final savedFile = await File(pickedFile.path).copy('${imagesDir.path}/$fileName');
				setState(() {
					_headerImage = savedFile.path;
				});
			}
		} catch (e) {
			MemoixSnackBar.showError('Error picking image: $e');
		}
	}

	void _removeHeaderImage() {
		setState(() {
			_headerImage = null;
		});
	}

	Widget _imageActionButton({required IconData icon, required VoidCallback onTap, required ThemeData theme, double size = 20,}) {
		return Material(
			color: theme.colorScheme.surface.withOpacity(0.9),
			borderRadius: BorderRadius.circular(20),
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(20),
				child: Padding(
					padding: const EdgeInsets.all(8),
					child: Icon(icon, size: size, color: theme.colorScheme.onSurface),
				),
			),
		);
	}

	Widget _buildStepImagesGallery(ThemeData theme) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Row(
					children: [
						Text('Gallery', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
						const SizedBox(width: 8),
						if (_stepImages.isNotEmpty)
							Container(
								padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
								decoration: BoxDecoration(
									color: theme.colorScheme.primaryContainer,
									borderRadius: BorderRadius.circular(12),
								),
								child: Text('${_stepImages.length}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w500)),
							),
					],
				),
				const SizedBox(height: 4),
				Text('Add photos for cooking steps', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
				const SizedBox(height: 8),
				SizedBox(
					height: 100,
					child: ListView.builder(
						scrollDirection: Axis.horizontal,
						itemCount: _stepImages.length + 1,
						itemBuilder: (context, index) {
							if (index == _stepImages.length) {
								return GestureDetector(
									onTap: _pickGalleryImage,
									child: Container(
										width: 100,
										height: 100,
										decoration: BoxDecoration(
											color: theme.colorScheme.surfaceVariant,
											borderRadius: BorderRadius.circular(8),
											border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
										),
										child: Column(
											mainAxisAlignment: MainAxisAlignment.center,
											children: [
												Icon(Icons.add_photo_alternate, size: 32, color: theme.colorScheme.onSurfaceVariant),
												const SizedBox(height: 4),
												Text('Add', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
											],
										),
									),
								);
							}
							return Padding(
								padding: const EdgeInsets.only(right: 8),
								child: Stack(
									children: [
										ClipRRect(
											borderRadius: BorderRadius.circular(8),
											child: _buildStepImageWidget(_stepImages[index], width: 100, height: 100),
										),
										Positioned(
											top: 4,
											right: 4,
											child: Material(
												color: theme.colorScheme.surface.withOpacity(0.9),
												borderRadius: BorderRadius.circular(20),
												child: InkWell(
													onTap: () => _removeGalleryImage(index),
													borderRadius: BorderRadius.circular(20),
													child: Padding(
														padding: const EdgeInsets.all(4),
														child: Icon(Icons.close, size: 14, color: theme.colorScheme.secondary),
													),
												),
											),
										),
									],
								),
							);
						},
					),
				),
			],
		);
	}

	Future<void> _pickGalleryImage() async {
		showModalBottomSheet(
			context: context,
			builder: (ctx) => SafeArea(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						ListTile(
							leading: const Icon(Icons.camera_alt),
							title: const Text('Take Photo'),
							onTap: () {
								Navigator.pop(ctx);
								_pickImageForGallery(ImageSource.camera);
							},
						),
						ListTile(
							leading: const Icon(Icons.photo_library),
							title: const Text('Choose from Gallery'),
							onTap: () {
								Navigator.pop(ctx);
								_pickImageForGallery(ImageSource.gallery);
							},
						),
						ListTile(
							leading: const Icon(Icons.close),
							title: const Text('Cancel'),
							onTap: () => Navigator.pop(ctx),
						),
					],
				),
			),
		);
	}

	Future<void> _pickImageForGallery(ImageSource source) async {
		try {
			final picker = ImagePicker();
			final pickedFile = await picker.pickImage(
				source: source,
				maxWidth: 1200,
				maxHeight: 1200,
				imageQuality: 85,
			);
			if (pickedFile != null) {
				final appDir = await getApplicationDocumentsDirectory();
				final imagesDir = Directory('${appDir.path}/recipe_images');
				if (!await imagesDir.exists()) {
					await imagesDir.create(recursive: true);
				}
				final fileName = '${const Uuid().v4()}${path.extension(pickedFile.path)}';
				final savedFile = await File(pickedFile.path).copy('${imagesDir.path}/$fileName');
				setState(() {
					_stepImages.add(savedFile.path);
				});
			}
		} catch (e) {
			MemoixSnackBar.showError('Error picking image: $e');
		}
	}

	void _removeGalleryImage(int index) {
		setState(() {
			_stepImageMap.removeWhere((k, v) => v == index);
			final newMap = <int, int>{};
			for (final entry in _stepImageMap.entries) {
				if (entry.value > index) {
					newMap[entry.key] = entry.value - 1;
				} else {
					newMap[entry.key] = entry.value;
				}
			}
			_stepImageMap.clear();
			_stepImageMap.addAll(newMap);
			_stepImages.removeAt(index);
		});
	}

	Widget _buildStepImageWidget(String imagePath, {double? width, double? height}) {
		if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
			return Image.network(imagePath, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: width, height: height, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),);
		} else {
			return Image.file(File(imagePath), width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: width, height: height, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),);
		}
	}
}

class _DraftIngredientRow {
	final TextEditingController nameController;
	final TextEditingController amountController;
	final TextEditingController unitController;
	final TextEditingController prepController;

	_DraftIngredientRow({
		required this.nameController,
		required this.amountController,
		required this.unitController,
		required this.prepController,
	});

	void dispose() {
		nameController.dispose();
		amountController.dispose();
		unitController.dispose();
		prepController.dispose();
	}
}

class _DirectionRow {
	final TextEditingController controller;
	_DirectionRow({required this.controller});
	void dispose() {
		controller.dispose();
	}
}
