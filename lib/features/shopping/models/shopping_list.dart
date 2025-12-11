import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../../core/database/database.dart';
import '../../recipes/models/recipe.dart';

part 'shopping_list.g.dart';

/// A shopping list item
@embedded
class ShoppingItem {
  String name = '';
  String? amount;
  String? unit;
  String? category; // Produce, Dairy, Meat, etc.
  String? recipeSource; // Which recipe this came from
  bool isChecked = false;

  ShoppingItem();

  ShoppingItem.create({
    required this.name,
    this.amount,
    this.unit,
    this.category,
    this.recipeSource,
    this.isChecked = false,
  });

  /// Create from an ingredient
  factory ShoppingItem.fromIngredient(Ingredient ingredient, String? recipeName) {
    return ShoppingItem()
      ..name = ingredient.name
      ..amount = ingredient.amount
      ..category = _guessCategory(ingredient.name)
      ..recipeSource = recipeName
      ..isChecked = false;
  }

  /// Combine with another item of the same ingredient
  ShoppingItem combine(ShoppingItem other) {
    // For now, just note both sources. Advanced: add amounts
    final sources = <String>[];
    if (recipeSource != null) sources.add(recipeSource!);
    if (other.recipeSource != null && other.recipeSource != recipeSource) {
      sources.add(other.recipeSource!);
    }
    
    return ShoppingItem()
      ..name = name
      ..amount = _combineAmounts(amount, other.amount)
      ..category = category ?? other.category
      ..recipeSource = sources.join(', ')
      ..isChecked = false;
  }

  String? _combineAmounts(String? a, String? b) {
    if (a == null || a.isEmpty) return b;
    if (b == null || b.isEmpty) return a;
    return '$a + $b'; // Simplified - could parse and add
  }

  static String? _guessCategory(String name) {
    final n = name.toLowerCase();
    
    // Alcohol/Beverages first (before produce to catch "orange liqueur")
    if (n.contains('wine') || n.contains('beer') || n.contains('vodka') ||
        n.contains('rum') || n.contains('whiskey') || n.contains('whisky') ||
        n.contains('bourbon') || n.contains('brandy') || n.contains('cognac') ||
        n.contains('gin') || n.contains('tequila') || n.contains('sake') ||
        n.contains('liqueur') || n.contains('liquor') || n.contains('vermouth') ||
        n.contains('sherry') || n.contains('port') || n.contains('champagne') ||
        n.contains('prosecco') || n.contains('mirin') || n.contains('cooking wine')) {
      return 'Beverages';
    }
    
    // Pantry (to catch stock, broth, baking items)
    if (n.contains('stock') || n.contains('broth') || n.contains('oil') || 
        n.contains('vinegar') || n.contains('sauce') || n.contains('soy') ||
        n.contains('baking powder') || n.contains('baking soda') ||
        n.contains('cornstarch') || n.contains('yeast') || n.contains('honey') ||
        n.contains('sugar') || n.contains('syrup') || n.contains('molasses')) {
      return 'Pantry';
    }
    if (n.contains('chicken') || n.contains('beef') || n.contains('pork') ||
        n.contains('meat') || n.contains('sausage') || n.contains('bacon') ||
        n.contains('lamb') || n.contains('turkey') || n.contains('duck') ||
        n.contains('veal') || n.contains('ham') || n.contains('prosciutto')) {
      return 'Meat';
    }
    if (n.contains('salmon') || n.contains('fish') || n.contains('shrimp') ||
        n.contains('lobster') || n.contains('crab') || n.contains('scallop') ||
        n.contains('mussel') || n.contains('clam') || n.contains('oyster') ||
        n.contains('tuna') || n.contains('cod') || n.contains('halibut')) {
      return 'Seafood';
    }
    if (n.contains('milk') || n.contains('cheese') || n.contains('butter') ||
        n.contains('cream') || n.contains('yogurt') || n.contains('yoghurt') ||
        n.contains('sour cream') || n.contains('crème')) {
      return 'Dairy';
    }
    if (n.contains('egg')) {
      return 'Dairy';
    }
    if (n.contains('onion') || n.contains('garlic') || n.contains('tomato') ||
        n.contains('pepper') || n.contains('carrot') || n.contains('celery') ||
        n.contains('lettuce') || n.contains('spinach') || n.contains('potato') ||
        n.contains('cabbage') || n.contains('broccoli') || n.contains('cauliflower') ||
        n.contains('zucchini') || n.contains('squash') || n.contains('cucumber') ||
        n.contains('mushroom') || n.contains('leek') || n.contains('shallot') ||
        n.contains('ginger') || n.contains('lemon') || n.contains('lime') ||
        n.contains('orange') || n.contains('apple') || n.contains('banana') ||
        n.contains('avocado') || n.contains('herb') || n.contains('cilantro') ||
        n.contains('parsley') || n.contains('basil') || n.contains('mint') ||
        n.contains('thyme') || n.contains('rosemary') || n.contains('dill') ||
        n.contains('chive') || n.contains('scallion') || n.contains('green onion')) {
      return 'Produce';
    }
    if (n.contains('bread') || n.contains('flour') || n.contains('pasta') ||
        n.contains('rice') || n.contains('noodle') || n.contains('tortilla') ||
        n.contains('wrap') || n.contains('pita') || n.contains('couscous') ||
        n.contains('quinoa') || n.contains('oat') || n.contains('cereal')) {
      return 'Grains';
    }
    if (n.contains('salt') || n.contains('pepper') || n.contains('spice') ||
        n.contains('cumin') || n.contains('paprika') || n.contains('oregano') ||
        n.contains('cinnamon') || n.contains('nutmeg') || n.contains('clove') ||
        n.contains('coriander') || n.contains('turmeric') || n.contains('curry') ||
        n.contains('chili') || n.contains('cayenne') || n.contains('powder')) {
      return 'Spices';
    }
    if (n.contains('can') || n.contains('bean') || n.contains('lentil') ||
        n.contains('chickpea') || n.contains('tomato paste') || n.contains('diced tomato')) {
      return 'Canned';
    }
    if (n.contains('frozen')) {
      return 'Frozen';
    }
    // Refrigerated proteins (tofu, tempeh, etc.)
    if (n.contains('tofu') || n.contains('tempeh') || n.contains('seitan') ||
        n.contains('edamame') || n.contains('miso')) {
      return 'Refrigerated';
    }
    
    return 'Other';
  }
}

/// A shopping list collection
@collection
class ShoppingList {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid;

  late String name;
  List<ShoppingItem> items = [];
  DateTime createdAt = DateTime.now();
  DateTime? completedAt;

  /// IDs of recipes this list was generated from
  List<String> recipeIds = [];

  ShoppingList();

  bool get isComplete => items.every((item) => item.isChecked);

  int get checkedCount => items.where((item) => item.isChecked).length;

  /// Group items by category for display
  @ignore
  Map<String, List<ShoppingItem>> get groupedItems {
    final Map<String, List<ShoppingItem>> grouped = {};
    
    for (final item in items) {
      final category = item.category ?? 'Other';
      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(item);
    }
    
    return grouped;
  }
}

/// Service for managing shopping lists
class ShoppingListService {
  final Isar _db;

  ShoppingListService(this._db);

  /// Generate a shopping list from recipes
  Future<ShoppingList> generateFromRecipes(List<Recipe> recipes, {String? name}) async {
    final items = <String, ShoppingItem>{};
    final recipeIds = <String>[];

    for (final recipe in recipes) {
      recipeIds.add(recipe.uuid);
      
      for (final ingredient in recipe.ingredients) {
        if (ingredient.isOptional) continue; // Skip optional by default
        
        final key = ingredient.name.toLowerCase().trim();
        final item = ShoppingItem.fromIngredient(ingredient, recipe.name);
        
        if (items.containsKey(key)) {
          // Combine with existing
          items[key] = items[key]!.combine(item);
        } else {
          items[key] = item;
        }
      }
    }

    final list = ShoppingList()
      ..uuid = DateTime.now().millisecondsSinceEpoch.toString()
      ..name = name ?? 'Shopping List ${DateTime.now().month}/${DateTime.now().day}'
      ..items = items.values.toList()
      ..recipeIds = recipeIds
      ..createdAt = DateTime.now();

    // Sort items by category
    list.items.sort((a, b) {
      final catCompare = (a.category ?? 'Other').compareTo(b.category ?? 'Other');
      if (catCompare != 0) return catCompare;
      return a.name.compareTo(b.name);
    });

    await _db.writeTxn(() => _db.shoppingLists.put(list));
    return list;
  }

  /// Get all shopping lists
  Future<List<ShoppingList>> getAll() async {
    return _db.shoppingLists.where().sortByCreatedAtDesc().findAll();
  }

  /// Get active (incomplete) lists
  Future<List<ShoppingList>> getActive() async {
    return _db.shoppingLists.filter().completedAtIsNull().findAll();
  }

  /// Update an item's checked status
  Future<void> toggleItem(ShoppingList list, int itemIndex) async {
    list.items[itemIndex].isChecked = !list.items[itemIndex].isChecked;
    
    // Check if all items are complete
    if (list.isComplete) {
      list.completedAt = DateTime.now();
    } else {
      list.completedAt = null;
    }
    
    await _db.writeTxn(() => _db.shoppingLists.put(list));
  }

  /// Add a manual item to a list
  Future<void> addItem(ShoppingList list, ShoppingItem item) async {
    list.items.add(item);
    await _db.writeTxn(() => _db.shoppingLists.put(list));
  }

  /// Remove an item from a list
  Future<void> removeItem(ShoppingList list, int itemIndex) async {
    list.items.removeAt(itemIndex);
    await _db.writeTxn(() => _db.shoppingLists.put(list));
  }

  /// Delete a shopping list
  Future<void> delete(int id) async {
    await _db.writeTxn(() => _db.shoppingLists.delete(id));
  }

  /// Watch all shopping lists
  Stream<List<ShoppingList>> watchAll() {
    return _db.shoppingLists.where().sortByCreatedAtDesc().watch(fireImmediately: true);
  }
}

// Providers moved to core/providers.dart
