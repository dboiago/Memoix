import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

part 'shopping_dao.g.dart';

@DriftAccessor(tables: [ShoppingLists, ShoppingItems])
class ShoppingDao extends DatabaseAccessor<AppDatabase>
    with _$ShoppingDaoMixin {
  ShoppingDao(super.db);

  // ─── SHOPPING LISTS ───────────────────────────────────────────────────────

  Future<List<ShoppingList>> getAllLists() =>
      select(shoppingLists).get();

  Future<ShoppingList?> getListByUuid(String uuid) =>
      (select(shoppingLists)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull();

  Future<ShoppingList?> getListById(int id) =>
      (select(shoppingLists)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> saveList(ShoppingListsCompanion list) =>
      into(shoppingLists).insertOnConflictUpdate(list);

  Future<void> deleteList(int id) async {
    await deleteAllItemsForList(id);
    await (delete(shoppingLists)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteListByUuid(String uuid) async {
    final list = await getListByUuid(uuid);
    if (list == null) return;
    await deleteList(list.id);
  }

  Stream<List<ShoppingList>> watchAllLists() =>
      select(shoppingLists).watch();

  Stream<ShoppingList?> watchListByUuid(String uuid) =>
      (select(shoppingLists)..where((t) => t.uuid.equals(uuid)))
          .watchSingleOrNull();

  Future<int> getListCount() async {
    final count = countAll();
    final query = selectOnly(shoppingLists)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // ─── SHOPPING ITEMS ───────────────────────────────────────────────────────

  Future<List<ShoppingItem>> getItemsForList(int listId) =>
      (select(shoppingItems)
            ..where((t) => t.shoppingListId.equals(listId)))
          .get();

  Future<ShoppingItem?> getItemByUuid(String uuid) =>
      (select(shoppingItems)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull();

  Future<int> saveItem(ShoppingItemsCompanion item) =>
      into(shoppingItems).insertOnConflictUpdate(item);

  Future<int> deleteItem(int id) =>
      (delete(shoppingItems)..where((t) => t.id.equals(id))).go();

  Future<int> deleteItemByUuid(String uuid) =>
      (delete(shoppingItems)..where((t) => t.uuid.equals(uuid))).go();

  Future<int> deleteAllItemsForList(int listId) =>
      (delete(shoppingItems)
            ..where((t) => t.shoppingListId.equals(listId)))
          .go();

  Future<void> toggleItemChecked(int id, bool current) async {
    final item = await (select(shoppingItems)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (item == null) return;
    await (update(shoppingItems)..where((t) => t.id.equals(id)))
        .write(ShoppingItemsCompanion(isChecked: Value(!item.isChecked)));
  }

  Stream<List<ShoppingItem>> watchItemsForList(int listId) =>
      (select(shoppingItems)
            ..where((t) => t.shoppingListId.equals(listId)))
          .watch();
}
