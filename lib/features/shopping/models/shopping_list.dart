import 'package:isar/isar.dart';

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
      ..category = null // No auto-categorization - just alphabetical
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

    // Sort items alphabetically by name
    list.items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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

  /// Rename a shopping list
  Future<void> rename(ShoppingList list, String newName) async {
    list.name = newName;
    await _db.writeTxn(() => _db.shoppingLists.put(list));
  }

  /// Create an empty list with a name
  Future<ShoppingList> createEmpty({String? name}) async {
    final list = ShoppingList()
      ..uuid = DateTime.now().millisecondsSinceEpoch.toString()
      ..name = name ?? 'Shopping List ${DateTime.now().month}/${DateTime.now().day}'
      ..items = []
      ..createdAt = DateTime.now();
    await _db.writeTxn(() => _db.shoppingLists.put(list));
    return list;
  }

  /// Watch all shopping lists
  Stream<List<ShoppingList>> watchAll() {
    return _db.shoppingLists.where().sortByCreatedAtDesc().watch(fireImmediately: true);
  }
}

// Providers moved to core/providers.dart
