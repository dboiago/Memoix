import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/recipe.dart';
import '../widgets/ingredient_list.dart';
import '../widgets/direction_list.dart';
import '../../settings/screens/settings_screen.dart';

/// A split-screen cooking view optimised for hands-free use in the kitchen.
/// Shows ingredients and directions side-by-side on wide screens,
/// or stacked with a fixed ingredients panel on phones.
class RecipeCookingView extends ConsumerStatefulWidget {
  final Recipe recipe;

  const RecipeCookingView({super.key, required this.recipe});

  @override
  ConsumerState<RecipeCookingView> createState() => _RecipeCookingViewState();
}

class _RecipeCookingViewState extends ConsumerState<RecipeCookingView> {
  @override
  void initState() {
    super.initState();
    _enableWakeLockIfNeeded();
  }

  @override
  void dispose() {
    // Always disable wakelock when leaving cooking view
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _enableWakeLockIfNeeded() async {
    final keepScreenOn = ref.read(keepScreenOnProvider);
    if (keepScreenOn) {
      await WakelockPlus.enable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe.name),
        actions: [
          // Screen wake toggle
          Consumer(
            builder: (context, ref, _) {
              final keepScreenOn = ref.watch(keepScreenOnProvider);
              return IconButton(
                icon: Icon(
                  keepScreenOn ? Icons.lightbulb : Icons.lightbulb_outline,
                ),
                tooltip: keepScreenOn ? 'Screen stays on' : 'Screen may turn off',
                onPressed: () async {
                  await ref.read(keepScreenOnProvider.notifier).toggle();
                  final newValue = ref.read(keepScreenOnProvider);
                  if (newValue) {
                    await WakelockPlus.enable();
                  } else {
                    await WakelockPlus.disable();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: isWide
          ? _buildHorizontalSplit(theme)
          : _buildVerticalSplit(theme),
    );
  }

  /// Wide screen: ingredients left, directions right
  Widget _buildHorizontalSplit(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ingredients panel (scrollable)
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Ingredients',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: IngredientList(ingredients: widget.recipe.ingredients),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Directions panel (scrollable)
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Directions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DirectionList(directions: widget.recipe.directions),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Phone/narrow screen: ingredients on top (collapsible), directions below
  Widget _buildVerticalSplit(ThemeData theme) {
    return Column(
      children: [
        // Ingredients panel - takes top portion, scrollable
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.checklist, 
                        size: 20, 
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ingredients',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: IngredientList(ingredients: widget.recipe.ingredients),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Directions panel - takes bottom portion, scrollable
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.format_list_numbered, 
                      size: 20, 
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Directions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: DirectionList(directions: widget.recipe.directions),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
