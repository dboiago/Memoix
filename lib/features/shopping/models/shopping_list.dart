import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import 'package:memoix/features/shopping/controllers/shopping_list_controller.dart';
import 'package:memoix/features/tools/measurement_converter.dart';
import 'package:memoix/core/utils/ingredient_categorizer.dart';
import 'package:memoix/core/utils/text_normalizer.dart';
import 'package:memoix/core/utils/unit_normalizer.dart';
import 'package:uuid/uuid.dart';
import '../../recipes/models/recipe.dart';

final Uuid _uuid = Uuid();



/// Service for managing shopping lists
class ShoppingListService {
  final AppDatabase _db;

  final Map<int, Timer> _pendingDeletes = {};
  final Map<String, Timer> _pendingItemDeletes = {};
  final Map<String, _PendingItemDelete> _pendingItemDeleteData = {};

  ShoppingListService(this._db);

  /// Generate a shopping list from recipes
  Future<ShoppingList> generateFromRecipes(List<Recipe> recipes, {String? name}) async {
    final recipeIds = recipes.map((r) => r.uuid).toList();

    final controller = ShoppingListController();
    final categoriesMap = await controller.generateShoppingList(recipes);

    final now = DateTime.now();
    final listId = await _db.shoppingDao.saveList(ShoppingListsCompanion(
      uuid: Value(_uuid.v4()),
      name: Value(name ?? 'Shopping List ${now.month}/${now.day}'),
      recipeIds: Value(jsonEncode(recipeIds)),
      createdAt: Value(now),
    ));

    for (final entry in categoriesMap.entries) {
      final categoryName = _categoryDisplayName(entry.key);
      for (final item in entry.value) {
        final normalizedAmount = _normalizeAmount(item.quantityDisplay);
        await _db.shoppingDao.saveItem(ShoppingItemsCompanion(
          shoppingListId: Value(listId),
          uuid: Value(_uuid.v4()),
          name: Value(item.name),
          amount: Value(normalizedAmount),
          unit: Value(item.unit == 'mixed' ? null : item.unit),
          category: Value(categoryName),
          recipeSource: Value(item.references.join(', ')),
          manualNotes: Value(item.manualNotes),
          isChecked: const Value(false),
        ));
      }
    }

    return (await _db.shoppingDao.getListById(listId))!;
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
    final lists = await _db.shoppingDao.getAllLists();
    return lists..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get active (incomplete) lists
  Future<List<ShoppingList>> getActive() async {
    final lists = await _db.shoppingDao.getAllLists();
    return lists.where((l) => l.completedAt == null).toList();
  }

  /// Update an item's checked status
  Future<ShoppingList?> toggleItem(ShoppingList list, int itemIndex) async {
    final items = await _db.shoppingDao.getItemsForList(list.id);
    if (itemIndex >= items.length) return null;
    await _db.shoppingDao.toggleItemChecked(items[itemIndex].id, items[itemIndex].isChecked);
    final updatedItems = await _db.shoppingDao.getItemsForList(list.id);
    final isComplete = updatedItems.isNotEmpty && updatedItems.every((i) => i.isChecked);
    await _db.shoppingDao.saveList(ShoppingListsCompanion(
      id: Value(list.id),
      uuid: Value(list.uuid),
      name: Value(list.name),
      createdAt: Value(list.createdAt),
      recipeIds: Value(list.recipeIds),
      completedAt: Value(isComplete ? DateTime.now() : null),
    ));
    return _db.shoppingDao.getListById(list.id);
  }

  /// Update an item's checked status using its UUID (with fallback to index)
  Future<ShoppingList?> toggleItemById(
    ShoppingList list,
    String itemUuid, {
    int? fallbackIndex,
  }) async {
    final items = await _db.shoppingDao.getItemsForList(list.id);
    var index = itemUuid.isNotEmpty
        ? items.indexWhere((i) => i.uuid == itemUuid)
        : -1;
    if (index == -1 && fallbackIndex != null && fallbackIndex < items.length) {
      index = fallbackIndex;
    }
    if (index == -1) return null;
    await _db.shoppingDao.toggleItemChecked(items[index].id, items[index].isChecked);
    final updatedItems = await _db.shoppingDao.getItemsForList(list.id);
    final isComplete = updatedItems.isNotEmpty && updatedItems.every((i) => i.isChecked);
    await _db.shoppingDao.saveList(ShoppingListsCompanion(
      id: Value(list.id),
      uuid: Value(list.uuid),
      name: Value(list.name),
      createdAt: Value(list.createdAt),
      recipeIds: Value(list.recipeIds),
      completedAt: Value(isComplete ? DateTime.now() : null),
    ));
    return _db.shoppingDao.getListById(list.id);
  }

  /// Add a manual item to a list
  Future<ShoppingList?> addItem(ShoppingList list, ShoppingItem item) async {
    final latestList = await _db.shoppingDao.getListById(list.id);
    if (latestList == null) return null;

    final itemUuid = item.uuid.isEmpty ? _uuid.v4() : item.uuid;

    // 1. Normalize Name and Amount
    final normalizedName = TextNormalizer.cleanName(item.name);
    final normalizedAmount = (item.amount != null && item.amount!.isNotEmpty)
        ? _normalizeManualAmount(item.amount!)
        : item.amount;

    // 2. Classify (Auto-Category)
    final categoryName = (item.category == null || item.category!.isEmpty)
        ? _categoryDisplayName(IngredientService().classify(normalizedName))
        : item.category;

    // 3. Check for Existing Item (Merge Strategy)
    final existingItems = await _db.shoppingDao.getItemsForList(list.id);
    final svc = IngredientService();
    final mergeKey = svc.normalize(normalizedName);
    final existingIndex = existingItems.indexWhere(
      (i) => svc.normalize(i.name) == mergeKey,
    );

    if (existingIndex != -1) {
      final existing = existingItems[existingIndex];
      final combinedAmount = _combineAmounts(existing.amount, normalizedAmount);
      await _db.shoppingDao.saveItem(ShoppingItemsCompanion(
        id: Value(existing.id),
        shoppingListId: Value(list.id),
        uuid: Value(existing.uuid),
        name: Value(existing.name),
        amount: Value(combinedAmount),
        unit: Value(existing.unit),
        category: Value(existing.category),
        recipeSource: Value(existing.recipeSource),
        manualNotes: Value(
          (existing.manualNotes?.isNotEmpty == true)
              ? '${existing.manualNotes}, Manual Add'
              : 'Manual Add',
        ),
        isChecked: const Value(false),
      ));
    } else {
      await _db.shoppingDao.saveItem(ShoppingItemsCompanion(
        shoppingListId: Value(list.id),
        uuid: Value(itemUuid),
        name: Value(normalizedName),
        amount: Value(normalizedAmount),
        unit: Value(item.unit),
        category: Value(categoryName),
        recipeSource: Value(item.recipeSource),
        manualNotes: Value(item.manualNotes),
        isChecked: const Value(false),
      ));
    }

    return latestList;
  }

  String? _combineAmounts(String? a, String? b) {
    if (a == null || a.isEmpty) return b;
    if (b == null || b.isEmpty) return a;

    // 🎯 Strategy: Parse all amounts (handling comma-separated), attempt unit conversion,
    // sum everything that's convertible, and comma-separate only truly incompatible items.
    
    // Collect ALL amounts (comma-separated if present)
    final allParts = <String>[];
    if (a.contains(',')) {
      allParts.addAll(a.split(',').map((p) => p.trim()));
    } else {
      allParts.add(a);
    }
    if (b.contains(',')) {
      allParts.addAll(b.split(',').map((p) => p.trim()));
    } else {
      allParts.add(b);
    }

    // Parse all parts
    final parsed = <_ParsedAmount>[];
    final unparseable = <String>[];
    for (final part in allParts) {
      final p = _simpleParse(part);
      if (p != null) {
        parsed.add(p);
      } else {
        unparseable.add(part);
      }
    }

    // If we have parseable amounts, try to combine them
    if (parsed.isNotEmpty) {
      // Attempt to find a common unit for all parsed amounts
      final commonUnit = _findCommonUnit(parsed);
      
      if (commonUnit != null) {
        // Convert all to common unit and sum
        double total = 0.0;
        for (final p in parsed) {
          final normalized = UnitNormalizer.normalizeUnit(
            UnitNormalizer.normalize(p.unit).toLowerCase()
          );
          final converted = _convertToUnit(p.qty, normalized, commonUnit);
          if (converted != null) {
            total += converted;
          }
        }
        
        final totalStr = MeasurementConverter.formatNumber(total);
        final result = commonUnit.isEmpty ? totalStr : '$totalStr $commonUnit';
        final normalized = _normalizeAmount(result);
        
        // If we had unparseable items, append them
        if (unparseable.isNotEmpty) {
          return '$normalized, ${unparseable.join(', ')}';
        }
        return normalized;
      }
    }

    // Fallback: comma-separate all items (at least normalize them)
    final normalized = (allParts + unparseable)
        .map((p) => _normalizeAmount(p))
        .toList();
    return normalized.join(', ');
  }

  /// Find a common unit that all amounts can convert to, preferring the first unit
  String? _findCommonUnit(List<_ParsedAmount> amounts) {
    if (amounts.isEmpty) return null;
    
    // Start with the first unit as the target
    final firstUnit = UnitNormalizer.normalizeUnit(
      UnitNormalizer.normalize(amounts[0].unit).toLowerCase()
    );
    
    // Check if all amounts can convert to this unit
    for (final p in amounts) {
      final unit = UnitNormalizer.normalizeUnit(
        UnitNormalizer.normalize(p.unit).toLowerCase()
      );
      if (unit == firstUnit) continue; // Already same
      
      // Try volume conversion
      final volConvert = MeasurementConverter.convertVolume(1.0, unit, firstUnit);
      if (volConvert != null) continue; // Volume compatible
      
      // Try weight conversion
      final weightConvert = MeasurementConverter.convertWeight(1.0, unit, firstUnit);
      if (weightConvert != null) continue; // Weight compatible
      
      // No conversion possible with this unit - try the next one
      return null;
    }
    
    // All amounts can convert to firstUnit
    return firstUnit;
  }

  /// Convert qty from one unit to another (handles volume, weight, or identity)
  double? _convertToUnit(double qty, String fromUnit, String toUnit) {
    final normFrom = UnitNormalizer.normalize(fromUnit);
    final normTo = UnitNormalizer.normalize(toUnit);
    
    if (normFrom.toLowerCase() == normTo.toLowerCase()) {
      return qty;
    }
    
    // Try volume
    final vol = MeasurementConverter.convertVolume(qty, normFrom, normTo);
    if (vol != null) return vol;
    
    // Try weight
    final weight = MeasurementConverter.convertWeight(qty, normFrom, normTo);
    if (weight != null) return weight;
    
    return null;
  }

  _ParsedAmount? _simpleParse(String s) {
    final cleaned = TextNormalizer.normalizeFractions(s.trim());
    
    // Parse quantity: supports "1.5", "2", "½", "1 ½" (mixed fraction)
    double qty = 0.0;
    String remainder = cleaned;

    // Unicode fraction map
    const fractionMap = {
      '½': 0.5, '¼': 0.25, '¾': 0.75,
      '⅓': 0.333, '⅔': 0.666,
      '⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
      '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8,
      '⅙': 0.166, '⅚': 0.833,
    };

    // Extract all numbers and fractions
    final regex = RegExp(r'([\d]+(?:\.[\d]+)?)|([' + fractionMap.keys.join() + r'])');
    final matches = regex.allMatches(cleaned);
    
    int lastMatchEnd = 0;
    for (final match in matches) {
      final numStr = match.group(1);
      final fracStr = match.group(2);
      
      if (numStr != null) {
        qty += double.tryParse(numStr) ?? 0.0;
      } else if (fracStr != null) {
        qty += fractionMap[fracStr] ?? 0.0;
      }
      lastMatchEnd = match.end;
    }

    if (qty == 0.0) return null;

    // Everything after the last number/fraction is the unit
    remainder = cleaned.substring(lastMatchEnd).trim();
    return _ParsedAmount(qty, remainder);
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

  /// Normalize an amount string: fractions → Unicode, units → proper case
  String _normalizeAmount(String raw) {
    if (raw.isEmpty) return raw;
    
    // 1. Convert text fractions to Unicode ("1/2" → "½")
    String result = TextNormalizer.normalizeFractions(raw);
    
    // 2. Normalize unit capitalization
    final parts = result.split(' ');
    final normalizedParts = parts.map((part) {
      if (UnitNormalizer.isRecognizedUnit(part)) {
        return UnitNormalizer.normalize(part);
      }
      return part;
    }).toList();
    
    return normalizedParts.join(' ');
  }

  /// Attempt to normalize a user-typed amount string like "2 tablespoons"
  String _normalizeManualAmount(String raw) => _normalizeAmount(raw);

  /// Remove an item from a list
  Future<ShoppingList?> removeItem(ShoppingList list, int itemIndex) async {
    final latestList = await _db.shoppingDao.getListById(list.id);
    if (latestList == null) return null;
    final items = await _db.shoppingDao.getItemsForList(list.id);
    if (itemIndex >= items.length) return null;
    await _db.shoppingDao.deleteItem(items[itemIndex].id);
    return latestList;
  }

  /// Remove an item from a list using its UUID
  Future<ShoppingList?> removeItemById(ShoppingList list, String itemUuid) async {
    final latestList = await _db.shoppingDao.getListById(list.id);
    if (latestList == null) return null;
    await _db.shoppingDao.deleteItemByUuid(itemUuid);
    return latestList;
  }

  /// Remove an item by UUID using list ID only
  Future<ShoppingList?> removeItemByUuid(int listId, String itemUuid) async {
    await _db.shoppingDao.deleteItemByUuid(itemUuid);
    return _db.shoppingDao.getListById(listId);
  }

  /// Remove an item by index using list ID only (fallback)
  Future<ShoppingList?> removeItemByIndex(int listId, int itemIndex) async {
    final latestList = await _db.shoppingDao.getListById(listId);
    if (latestList == null) return null;
    return removeItem(latestList, itemIndex);
  }

  /// Update an item's amount using its UUID
  Future<ShoppingList?> updateItemAmountById(
    ShoppingList list,
    String itemUuid,
    String? amount,
  ) async {
    final latestList = await _db.shoppingDao.getListById(list.id);
    if (latestList == null) return null;
    final item = await _db.shoppingDao.getItemByUuid(itemUuid);
    if (item == null) return null;
    final normalizedAmount = (amount == null || amount.trim().isEmpty)
        ? null
        : _normalizeManualAmount(amount.trim());
    await _db.shoppingDao.saveItem(ShoppingItemsCompanion(
      id: Value(item.id),
      shoppingListId: Value(item.shoppingListId),
      uuid: Value(item.uuid),
      name: Value(item.name),
      amount: Value(normalizedAmount),
      unit: Value(item.unit),
      category: Value(item.category),
      recipeSource: Value(item.recipeSource),
      isChecked: Value(item.isChecked),
      manualNotes: Value(item.manualNotes),
    ));
    return latestList;
  }

  /// Delete a shopping list
  Future<void> delete(int id) async {
    await _db.shoppingDao.deleteList(id);
  }

  /// Schedule a list deletion with undo capability
  void scheduleListDelete({
    required int listId,
    required Duration undoDuration,
    void Function()? onComplete,
  }) {
    _pendingDeletes[listId]?.cancel();
    _pendingDeletes[listId] = Timer(undoDuration, () async {
      _pendingDeletes.remove(listId);
      await delete(listId);
      onComplete?.call();
    });
  }

  /// Cancel a pending delete (undo)
  void cancelPendingDelete(int listId) {
    _pendingDeletes[listId]?.cancel();
    _pendingDeletes.remove(listId);
  }

  /// Check if a delete is pending for this list
  bool isPendingDelete(int listId) => _pendingDeletes.containsKey(listId);

  /// Schedule an item deletion with undo capability
  Future<void> scheduleItemDelete({
    required int listId,
    required String itemUuid,
    required String itemName,
    String? itemAmount,
    String? itemRecipeSource,
    int? fallbackIndex,
    required Duration undoDuration,
    void Function()? onComplete,
  }) async {
    if (itemUuid.isEmpty && fallbackIndex == null) return;

    final key = itemUuid.isNotEmpty
        ? '$listId:$itemUuid'
        : '$listId:index:$fallbackIndex';

    var resolvedUuid = itemUuid;
    var resolvedIndex = fallbackIndex;

    if (resolvedUuid.isEmpty && resolvedIndex != null) {
      final items = await _db.shoppingDao.getItemsForList(listId);
      if (resolvedIndex >= 0 && resolvedIndex < items.length) {
        resolvedUuid = items[resolvedIndex].uuid;
      }
    }

    _pendingItemDeletes[key]?.cancel();
    _pendingItemDeleteData[key] = _PendingItemDelete(
      listId: listId,
      itemUuid: resolvedUuid,
      itemName: itemName,
      itemAmount: itemAmount,
      itemRecipeSource: itemRecipeSource,
      fallbackIndex: resolvedIndex,
    );

    _pendingItemDeletes[key] = Timer(undoDuration, () async {
      final data = _pendingItemDeleteData.remove(key);
      _pendingItemDeletes.remove(key);
      if (data == null) return;

      var removed = false;
      if (data.itemUuid.isNotEmpty) {
        removed = (await removeItemByUuid(data.listId, data.itemUuid)) != null;
      }

      if (!removed) {
        final items = await _db.shoppingDao.getItemsForList(data.listId);
        final matchIndex = _findItemIndexByFields(
          items,
          data.itemName,
          data.itemAmount,
          data.itemRecipeSource,
        );
        if (matchIndex != null) {
          removed = (await removeItemByIndex(data.listId, matchIndex)) != null;
        }
      }

      if (!removed && data.fallbackIndex != null) {
        await removeItemByIndex(data.listId, data.fallbackIndex!);
      }
      onComplete?.call();
    });
  }

  /// Cancel a pending item delete (undo)
  void cancelPendingItemDelete({
    required int listId,
    required String itemUuid,
    int? fallbackIndex,
  }) {
    final key = itemUuid.isNotEmpty
        ? '$listId:$itemUuid'
        : '$listId:index:$fallbackIndex';
    _pendingItemDeletes[key]?.cancel();
    _pendingItemDeletes.remove(key);
    _pendingItemDeleteData.remove(key);
  }

  /// Check if an item delete is pending
  bool isPendingItemDelete({
    required int listId,
    required String itemUuid,
    int? fallbackIndex,
  }) {
    final key = itemUuid.isNotEmpty
        ? '$listId:$itemUuid'
        : '$listId:index:$fallbackIndex';
    return _pendingItemDeletes.containsKey(key);
  }

  /// Rename a shopping list
  Future<ShoppingList?> rename(ShoppingList list, String newName) async {
    final latestList = await _db.shoppingDao.getListById(list.id);
    if (latestList == null) return null;
    await _db.shoppingDao.saveList(ShoppingListsCompanion(
      id: Value(latestList.id),
      uuid: Value(latestList.uuid),
      name: Value(newName),
      createdAt: Value(latestList.createdAt),
      recipeIds: Value(latestList.recipeIds),
      completedAt: Value(latestList.completedAt),
    ));
    return _db.shoppingDao.getListById(list.id);
  }

  /// Create an empty list with a name
  Future<ShoppingList> createEmpty({String? name}) async {
    final now = DateTime.now();
    final listId = await _db.shoppingDao.saveList(ShoppingListsCompanion(
      uuid: Value(_uuid.v4()),
      name: Value(name ?? 'Shopping List ${now.month}/${now.day}'),
      createdAt: Value(now),
      recipeIds: const Value('[]'),
    ));
    return (await _db.shoppingDao.getListById(listId))!;
  }

  /// Watch all shopping lists
  Stream<List<ShoppingList>> watchAll() {
    return _db.shoppingDao.watchAllLists();
  }

  Future<void> ensureItemUuids(ShoppingList list) async {}

  bool _ensureItemUuids(ShoppingList list) => false;

  int? _findItemIndexByFields(
    List<ShoppingItem> items,
    String name,
    String? amount,
    String? recipeSource,
  ) {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.name == name &&
          item.amount == amount &&
          item.recipeSource == recipeSource) {
        return i;
      }
    }
    return null;
  }
}

// Providers moved to core/providers.dart

class _ParsedAmount {
  final double qty;
  final String unit;
  _ParsedAmount(this.qty, this.unit);
}

class _PendingItemDelete {
  final int listId;
  final String itemUuid;
  final String itemName;
  final String? itemAmount;
  final String? itemRecipeSource;
  final int? fallbackIndex;

  const _PendingItemDelete({
    required this.listId,
    required this.itemUuid,
    required this.itemName,
    required this.itemAmount,
    required this.itemRecipeSource,
    required this.fallbackIndex,
  });
}
