import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';

part 'meal_plan_dao.g.dart';

@DriftAccessor(tables: [MealPlans, PlannedMeals])
class MealPlanDao extends DatabaseAccessor<AppDatabase>
    with _$MealPlanDaoMixin {
  MealPlanDao(super.db);

  static const _uuid = Uuid();

  // ─── MEAL PLANS ───────────────────────────────────────────────────────────

  Future<MealPlan?> getPlanByDate(String date) =>
      (select(mealPlans)..where((t) => t.date.equals(date)))
          .getSingleOrNull();

  Future<MealPlan> getOrCreatePlan(String date) async {
    final existing = await getPlanByDate(date);
    if (existing != null) return existing;
    final id = await into(mealPlans)
        .insert(MealPlansCompanion.insert(date: date, uuid: Value(_uuid.v4())));
    return (select(mealPlans)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> savePlan(MealPlansCompanion plan) =>
      into(mealPlans).insertOnConflictUpdate(plan);

  Future<int> deletePlan(int id) =>
      (delete(mealPlans)..where((t) => t.id.equals(id))).go();

  Stream<List<MealPlan>> watchDateRange(String startDate, String endDate) =>
      (select(mealPlans)
            ..where((t) =>
                t.date.isBiggerThanValue(startDate) &
                t.date.isSmallerThanValue(endDate),))
          .watch();

  Future<List<MealPlan>> getWeekPlans(List<String> dates) =>
      (select(mealPlans)..where((t) => t.date.isIn(dates))).get();

  // ─── PLANNED MEALS ────────────────────────────────────────────────────────

  Future<List<PlannedMeal>> getMealsForPlan(int planId) =>
      (select(plannedMeals)..where((t) => t.mealPlanId.equals(planId))).get();

  Future<PlannedMeal?> getMealByInstanceId(String instanceId) =>
      (select(plannedMeals)..where((t) => t.instanceId.equals(instanceId)))
          .getSingleOrNull();

  Future<int> addMeal(PlannedMealsCompanion meal) =>
      into(plannedMeals).insert(meal);

  Future<int> removeMeal(String instanceId) =>
      (delete(plannedMeals)..where((t) => t.instanceId.equals(instanceId)))
          .go();

  Future<int> removeAllMealsForPlan(int planId) =>
      (delete(plannedMeals)..where((t) => t.mealPlanId.equals(planId))).go();

  Future<int> moveMeal(String instanceId, int toPlanId) =>
      (update(plannedMeals)..where((t) => t.instanceId.equals(instanceId)))
          .write(PlannedMealsCompanion(mealPlanId: Value(toPlanId)));

  Stream<List<PlannedMeal>> watchMealsForPlan(int planId) =>
      (select(plannedMeals)..where((t) => t.mealPlanId.equals(planId)))
          .watch();

  // ─── COMBINED ─────────────────────────────────────────────────────────────

  Future<void> clearDay(String date) async {
    final plan = await getPlanByDate(date);
    if (plan == null) return;
    await removeAllMealsForPlan(plan.id);
    await deletePlan(plan.id);
  }

  Future<void> copyDay(String fromDate, String toDate) async {
    final sourcePlan = await getPlanByDate(fromDate);
    if (sourcePlan == null) return;
    final sourceMeals = await getMealsForPlan(sourcePlan.id);
    if (sourceMeals.isEmpty) return;
    final destPlan = await getOrCreatePlan(toDate);
    for (final meal in sourceMeals) {
      await addMeal(PlannedMealsCompanion.insert(
        mealPlanId: destPlan.id,
        instanceId: _uuid.v4(),
        recipeId: Value(meal.recipeId),
        recipeName: Value(meal.recipeName),
        course: Value(meal.course),
        notes: Value(meal.notes),
        servings: Value(meal.servings),
        cuisine: Value(meal.cuisine),
        recipeCategory: Value(meal.recipeCategory),
      ),);
    }
  }
}
