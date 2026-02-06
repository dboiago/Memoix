import 'package:isar/isar.dart';
import 'package:memoix/features/shopping/controllers/shopping_list_controller.dart';
import 'package:memoix/features/tools/measurement_converter.dart';
import 'package:memoix/core/utils/ingredient_categorizer.dart';
import 'package:memoix/core/utils/text_normalizer.dart';
import 'package:memoix/core/utils/unit_normalizer.dart';
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

  String _categoryDisplayName(dynamic cat) {
    if (cat is IngredientCategory) {
      return ShoppingListController.aisleFor(cat);
    }
    final s = cat.toString();
    if (s.isEmpty) return 'Other';
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
    // Re-fetch to ensure latest version
    final latestList = await _db.shoppingLists.get(list.id);
    if (latestList != null) {
      // 1. Normalize Name and Amount
      final normalizedName = TextNormalizer.cleanName(item.name);
      item.name = normalizedName;
      
      // Attempt to normalize complex amount string (e.g. "2 tablespoons" -> "2 Tbsp")
      if (item.amount != null && item.amount!.isNotEmpty) {
        item.amount = _normalizeManualAmount(item.amount!);
      }

      // 2. Classify (Auto-Category)
      if (item.category == null || item.category!.isEmpty) {
        final catEnum = IngredientService().classify(item.name);
        item.category = _categoryDisplayName(catEnum);
      }

      final newItems = List<ShoppingItem>.from(latestList.items);

      // 3. Check for Existing Item (Merge Strategy)
      // Use IngredientService.normalize() so "Egg" and "Eggs" resolve to the same key
      final svc = IngredientService();
      final mergeKey = svc.normalize(item.name);
      final existingIndex = newItems.indexWhere(
        (i) => svc.normalize(i.name) == mergeKey,
      );

      if (existingIndex != -1) {
        // Merge logic
        final existing = newItems[existingIndex];
        
        // Combine amounts
        final combinedAmount = _combineAmounts(existing.amount, item.amount);
        
        // Create updated item
        newItems[existingIndex] = ShoppingItem()
          ..name = existing.name
          ..amount = combinedAmount
          ..unit = existing.unit // Keep existing unit or attempt merge? Simple is best for manual.
          ..category = existing.category // Keep existing category
          ..recipeSource = existing.recipeSource // Keep existing source info
          ..manualNotes = (existing.manualNotes?.isNotEmpty == true) 
              ? '${existing.manualNotes}, Manual Add' 
              : 'Manual Add'
          ..isChecked = false; // Uncheck when adding more
      } else {
        // New item
        newItems.add(item);
      }
      
      // 4. Sort entire list by Category Flow then Name
      _sortItems(newItems);

      latestList.items = newItems;
      await _db.writeTxn(() => _db.shoppingLists.put(latestList));
    }
  }

  String? _combineAmounts(String? a, String? b) {
    if (a == null || a.isEmpty) return b;
    if (b == null || b.isEmpty) return a;

    final pA = _simpleParse(a);
    final pB = _simpleParse(b);

    if (pA != null && pB != null) {
      final unitA = UnitNormalizer.normalize(pA.unit);
      final unitB = UnitNormalizer.normalize(pB.unit);

      // 1. Same unit (or both unitless) → sum directly
      if (unitA.toLowerCase() == unitB.toLowerCase()) {
        final total = pA.qty + pB.qty;
        final totalStr = MeasurementConverter.formatNumber(total);
        return unitA.isEmpty ? totalStr : '$totalStr $unitA';
      }

      // 2. Both are volume → convert to same unit and sum
      final volConvert = MeasurementConverter.convertVolume(
        pB.qty, unitB, unitA,
      );
      if (volConvert != null) {
        final total = pA.qty + volConvert;
        final totalStr = MeasurementConverter.formatNumber(total);
        return '$totalStr $unitA';
      }

      // 3. Both are weight → convert to same unit and sum
      final weightConvert = MeasurementConverter.convertWeight(
        pB.qty, unitB, unitA,
      );
      if (weightConvert != null) {
        final total = pA.qty + weightConvert;
        final totalStr = MeasurementConverter.formatNumber(total);
        return '$totalStr $unitA';
      }

      // 4. Count / descriptor items (e.g. "1 large" + "2" → "3 large")
      // If neither side is a real measurement unit, sum as counts.
      final aIsUnit = UnitNormalizer.isRecognizedUnit(unitA);
      final bIsUnit = UnitNormalizer.isRecognizedUnit(unitB);

      if (!aIsUnit && !bIsUnit) {
        final total = pA.qty + pB.qty;
        final totalStr = MeasurementConverter.formatNumber(total);
        // Keep the more descriptive label (non-empty one)
        final descriptor = unitA.isNotEmpty ? unitA : unitB;
        return descriptor.isEmpty ? totalStr : '$totalStr $descriptor';
      }

      // 5. Truly incompatible units (e.g. 500g vs 2 cups) → comma-separated
      return '$a, $b';
    }

    // Could not parse one or both → comma-separated
    return '$a, $b';
  }

  _ParsedAmount? _simpleParse(String s) {
    final cleaned = TextNormalizer.normalizeFractions(s.trim());
    // Match: number (int/decimal/unicode fraction combo) then optional unit text
    // E.g. "1.5 kg", "2", "½ cup", "1½ Tbsp"
    final match = RegExp(r'^([\d]+(?:\.[\d]+)?)\s*(.*)$').firstMatch(cleaned);
    if (match != null) {
      final qt = double.tryParse(match.group(1) ?? '');
      if (qt != null) {
        return _ParsedAmount(qt, match.group(2)?.trim() ?? '');
      }
    }
    return null;
  }

  /// Sorts items in place based on Store Aisle Flow and Name
  void _sortItems(List<ShoppingItem> items) {
    final sortMap = <String, int>{};
    for (int i = 0; i < ShoppingListController.storeAisleFlow.length; i++) {
      sortMap[ShoppingListController.storeAisleFlow[i]] = i;
    }

    items.sort((a, b) {
      // Primary Sort: Category Index
      final catA = sortMap[a.category ?? 'Other'] ?? 999;
      final catB = sortMap[b.category ?? 'Other'] ?? 999;
      final catCompare = catA.compareTo(catB);
      
      if (catCompare != 0) return catCompare;

      // Secondary Sort: Name
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  /// Attempt to normalize a user-typed amount string like "2 tablespoons"
  String _normalizeManualAmount(String raw) {
    // Split by digits vs text if possible, or just look for units
    // Simple heuristic: split by space, normalize each part if it matches a unit
    final parts = raw.split(' ');
    final normalizedParts = parts.map((part) {
      // Check if this part is a unit
      if (UnitNormalizer.isRecognizedUnit(part)) {
        return UnitNormalizer.normalize(part);
      }
      return part;
    }).toList();
    
    return normalizedParts.join(' ');
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

class _ParsedAmount {
  final double qty;
  final String unit;
  _ParsedAmount(this.qty, this.unit);
}
