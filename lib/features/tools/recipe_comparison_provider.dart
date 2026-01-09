import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../recipes/models/recipe.dart';

/// State for recipe comparison view
class RecipeComparisonState {
  final Recipe? recipe1;
  final Recipe? recipe2;
  final Set<int> selectedIngredients1;
  final Set<int> selectedIngredients2;
  final Set<int> selectedSteps1;
  final Set<int> selectedSteps2;

  RecipeComparisonState({
    this.recipe1,
    this.recipe2,
    Set<int>? selectedIngredients1,
    Set<int>? selectedIngredients2,
    Set<int>? selectedSteps1,
    Set<int>? selectedSteps2,
  })  : selectedIngredients1 = selectedIngredients1 ?? {},
        selectedIngredients2 = selectedIngredients2 ?? {},
        selectedSteps1 = selectedSteps1 ?? {},
        selectedSteps2 = selectedSteps2 ?? {};

  RecipeComparisonState copyWith({
    Recipe? recipe1,
    Recipe? recipe2,
    Set<int>? selectedIngredients1,
    Set<int>? selectedIngredients2,
    Set<int>? selectedSteps1,
    Set<int>? selectedSteps2,
    bool clearRecipe1 = false,
    bool clearRecipe2 = false,
  }) {
    return RecipeComparisonState(
      recipe1: clearRecipe1 ? null : recipe1 ?? this.recipe1,
      recipe2: clearRecipe2 ? null : recipe2 ?? this.recipe2,
      selectedIngredients1: selectedIngredients1 ?? this.selectedIngredients1,
      selectedIngredients2: selectedIngredients2 ?? this.selectedIngredients2,
      selectedSteps1: selectedSteps1 ?? this.selectedSteps1,
      selectedSteps2: selectedSteps2 ?? this.selectedSteps2,
    );
  }
}

/// Provider for recipe comparison state management
class RecipeComparisonNotifier extends StateNotifier<RecipeComparisonState> {
  RecipeComparisonNotifier() : super(RecipeComparisonState());

  /// Set recipe for slot 1
  void setRecipe1(Recipe recipe) {
    state = state.copyWith(
      recipe1: recipe,
      selectedIngredients1: {},
      selectedSteps1: {},
    );
  }

  /// Set recipe for slot 2
  void setRecipe2(Recipe recipe) {
    state = state.copyWith(
      recipe2: recipe,
      selectedIngredients2: {},
      selectedSteps2: {},
    );
  }

  /// Clear recipe slot 1
  void clearRecipe1() {
    state = state.copyWith(
      clearRecipe1: true,
      selectedIngredients1: {},
      selectedSteps1: {},
    );
  }

  /// Clear recipe slot 2
  void clearRecipe2() {
    state = state.copyWith(
      clearRecipe2: true,
      selectedIngredients2: {},
      selectedSteps2: {},
    );
  }

  /// Toggle ingredient selection in recipe 1
  void toggleIngredient1(int index) {
    final newSelection = Set<int>.from(state.selectedIngredients1);
    if (newSelection.contains(index)) {
      newSelection.remove(index);
    } else {
      newSelection.add(index);
    }
    state = state.copyWith(selectedIngredients1: newSelection);
  }

  /// Toggle ingredient selection in recipe 2
  void toggleIngredient2(int index) {
    final newSelection = Set<int>.from(state.selectedIngredients2);
    if (newSelection.contains(index)) {
      newSelection.remove(index);
    } else {
      newSelection.add(index);
    }
    state = state.copyWith(selectedIngredients2: newSelection);
  }

  /// Toggle step selection in recipe 1
  void toggleStep1(int index) {
    final newSelection = Set<int>.from(state.selectedSteps1);
    if (newSelection.contains(index)) {
      newSelection.remove(index);
    } else {
      newSelection.add(index);
    }
    state = state.copyWith(selectedSteps1: newSelection);
  }

  /// Toggle step selection in recipe 2
  void toggleStep2(int index) {
    final newSelection = Set<int>.from(state.selectedSteps2);
    if (newSelection.contains(index)) {
      newSelection.remove(index);
    } else {
      newSelection.add(index);
    }
    state = state.copyWith(selectedSteps2: newSelection);
  }

  /// Reset all state (for when leaving the screen)
  void reset() {
    state = RecipeComparisonState();
  }
}

/// Provider for recipe comparison
final recipeComparisonProvider =
    StateNotifierProvider<RecipeComparisonNotifier, RecipeComparisonState>(
  (ref) => RecipeComparisonNotifier(),
);
