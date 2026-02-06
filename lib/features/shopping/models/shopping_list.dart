import 'package:isar/isar.dart';
import 'package:memoix/features/shopping/controllers/shopping_list_controller.dart';
import 'package:memoix/core/utils/ingredient_categorizer.dart';
import '../../recipes/models/recipe.dart';

part 'shopping_list.g.dart';

/// A shopping list item
@embedded
class ShoppingItem {
  String name = '';
  String? amount;
  String? unit; // Kept for legacy, logic now combined in detail
  String? category; // Produce, Dairy, Meat, etc.
  String? recipeSource; // Which recipe this came from (comma sep)
  bool isChecked = false;
  String? manualNotes; // Notes from controller aggregation

  ShoppingItem();

  ShoppingItem.create({
    required this.name,
    this.amount,
    this.unit,
    this.category,
    this.recipeSource,
    this.isChecked = false,
    this.manualNotes,
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
    final recipeIds = recipes.map((r) => r.uuid).toList();
    
    // Use professional controller for aggregation
    final controller = ShoppingListController();
    final categoriesMap = await controller.generateShoppingList(recipes);
    
    // Flatten result for Isar storage
    final flatItems = <ShoppingItem>[];
    
    // Iterate through categories (already sorted by Store Flow in Controller)
    for (final entry in categoriesMap.entries) {
      final categoryName = _categoryDisplayName(entry.key);
      
      for (final item in entry.value) {
        flatItems.add(ShoppingItem()
          ..name = item.name
          ..amount = item.quantityDisplay
          // Store raw unit if single, otherwise empty as it's in amount
          ..unit = item.unit == 'mixed' ? null : item.unit 
          ..category = categoryName
          ..recipeSource = item.references.join(', ')
          ..manualNotes = item.manualNotes
          ..isChecked = false
        );
      }
    }

    final list = ShoppingList()
      ..uuid = DateTime.now().millisecondsSinceEpoch.toString()
      ..name = name ?? 'Shopping List ${DateTime.now().month}/${DateTime.now().day}'
      ..items = flatItems
      ..recipeIds = recipeIds
      ..createdAt = DateTime.now();

    await _db.writeTxn(() => _db.shoppingLists.put(list));
    return list;
  }

  String _categoryDisplayName(IngredientCategory cat) {
    // Capitalize first letter
    final s = cat.name; 
    return s[0].toUpperCase() + s.substring(1);
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
    final latestList = await _db.shoppingLists.get(list.id);
    if (latestList != null && itemIndex < latestList.items.length) {
      // Modify a copy to trigger Isar update
      final newItems = List<ShoppingItem>.from(latestList.items);
      newItems[itemIndex].isChecked = !newItems[itemIndex].isChecked;
      latestList.items = newItems;
      
      // Check if all items are complete
      if (latestList.isComplete) {
        latestList.completedAt = DateTime.now();
      } else {
        latestList.completedAt = null;
      }
      
      await _db.writeTxn(() => _db.shoppingLists.put(latestList));
    }
  }

  /// Add a manual item to a list
  Future<void> addItem(ShoppingList list, ShoppingItem item) async {
    // Re-fetch the list to ensure we have the latest version and it's managed
    final latestList = await _db.shoppingLists.get(list.id);
    if (latestList != null) {
      // Create a new list for items to ensure change detection
      final newItems = List<ShoppingItem>.from(latestList.items)..add(item);
      latestList.items = newItems;
      await _db.writeTxn(() => _db.shoppingLists.put(latestList));
    }
  }

  /// Remove an item from a list
  Future<void> removeItem(ShoppingList list, int itemIndex) async {
    final latestList = await _db.shoppingLists.get(list.id);
    if (latestList != null && itemIndex < latestList.items.length) {
      final newItems = List<ShoppingItem>.from(latestList.items)..removeAt(itemIndex);
      latestList.items = newItems;
      await _db.writeTxn(() => _db.shoppingLists.put(latestList));
    }
  }

  /// Delete a shopping list
  Future<void> delete(int id) async {
    await _db.writeTxn(() => _db.shoppingLists.delete(id));
  }

  /// Rename a shopping list
  Future<void> rename(ShoppingList list, String newName) async {
    final latestList = await _db.shoppingLists.get(list.id);
    if (latestList != null) {
      latestList.name = newName;
      await _db.writeTxn(() => _db.shoppingLists.put(latestList));
    }
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
