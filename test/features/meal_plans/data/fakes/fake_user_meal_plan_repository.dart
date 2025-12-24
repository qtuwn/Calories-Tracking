import 'dart:async';
import 'package:calories_app/domain/meal_plans/user_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart'
    as user_meal_plan_repository;
import 'package:calories_app/domain/meal_plans/explore_meal_plan.dart';

/// Fake repository for testing UserMealPlanService
///
/// Allows controlling stream emissions and timing for testing stream policies.
class FakeUserMealPlanRepository
    implements user_meal_plan_repository.UserMealPlanRepository {
  final Map<String, StreamController<UserMealPlan?>> _activePlanControllers = {};
  final Map<String, StreamController<List<UserMealPlan>>> _plansControllers = {};
  final Map<String, StreamController<List<user_meal_plan_repository.MealItem>>>
      _mealsControllers = {};

  /// Stores the latest snapshot per (planId:userId:dayIndex) so new subscribers
  /// immediately receive current state (Firestore snapshots() behavior).
  final Map<String, List<user_meal_plan_repository.MealItem>> _latestMeals = {};

  int _getActivePlanCallCount = 0;
  int _getDayMealsCallCount = 0;

  /// Counter for how many times getActivePlan was called
  int get getActivePlanCallCount => _getActivePlanCallCount;

  /// Counter for how many times getDayMeals was called
  int get getDayMealsCallCount => _getDayMealsCallCount;

  /// Emit a plan to the active plan stream for a user
  void emitActivePlan(String userId, UserMealPlan? plan) {
    final key = userId;
    _activePlanControllers
        .putIfAbsent(key, () => StreamController<UserMealPlan?>.broadcast())
        .add(plan);
  }

  /// Emit meals to the day meals stream
  void emitDayMeals(
    String planId,
    String userId,
    int dayIndex,
    List<user_meal_plan_repository.MealItem> meals,
  ) {
    final key = '$planId:$userId:$dayIndex';

    // Store immutable snapshot so later listeners can receive current state.
    _latestMeals[key] =
        List<user_meal_plan_repository.MealItem>.unmodifiable(meals);

    _mealsControllers
        .putIfAbsent(
          key,
          () => StreamController<List<user_meal_plan_repository.MealItem>>
              .broadcast(),
        )
        .add(meals);
  }

  /// Close all streams (cleanup)
  void dispose() {
    for (final controller in _activePlanControllers.values) {
      controller.close();
    }
    for (final controller in _plansControllers.values) {
      controller.close();
    }
    for (final controller in _mealsControllers.values) {
      controller.close();
    }
    _activePlanControllers.clear();
    _plansControllers.clear();
    _mealsControllers.clear();
    _latestMeals.clear();
  }

  @override
  Stream<UserMealPlan?> getActivePlan(String userId) {
    _getActivePlanCallCount++;
    final key = userId;
    return _activePlanControllers.putIfAbsent(
      key,
      () => StreamController<UserMealPlan?>.broadcast(),
    ).stream;
  }

  @override
  Stream<List<UserMealPlan>> getPlansForUser(String userId) {
    final key = userId;
    return _plansControllers.putIfAbsent(
      key,
      () => StreamController<List<UserMealPlan>>.broadcast(),
    ).stream;
  }

  @override
  Future<UserMealPlan?> getPlanById(String planId, String userId) async {
    // Return null by default - tests can override if needed
    return null;
  }

  @override
  Future<void> savePlan(UserMealPlan plan) async {
    // No-op for testing
  }

  @override
  Future<void> deletePlan(String planId, String userId) async {
    // No-op for testing
  }

  @override
  Future<void> setActivePlan({required String userId, required String planId}) async {
    // No-op for testing
  }

  @override
  Future<void> savePlanAndSetActive({
    required UserMealPlan plan,
    required String userId,
  }) async {
    // No-op for testing
  }

  @override
  Future<void> updatePlanProgress({
    required String planId,
    required String userId,
    required int currentDayIndex,
  }) async {
    // No-op for testing
  }

  @override
  Future<void> updatePlanStatus({
    required String planId,
    required String userId,
    required String status,
  }) async {
    // No-op for testing
  }

  @override
  Future<user_meal_plan_repository.MealPlanDay?> getDay(
    String planId,
    String userId,
    int dayIndex,
  ) async {
    return null;
  }

  @override
  Stream<List<user_meal_plan_repository.MealItem>> getDayMeals(
    String planId,
    String userId,
    int dayIndex,
  ) {
    _getDayMealsCallCount++;
    final key = '$planId:$userId:$dayIndex';

    final controller = _mealsControllers.putIfAbsent(
      key,
      () => StreamController<List<user_meal_plan_repository.MealItem>>.broadcast(),
    );

    // IMPORTANT:
    // - Must emit immediately with current state (Firestore snapshots behavior)
    // - Must allow multiple listeners (contract tests may listen twice)
    return Stream<List<user_meal_plan_repository.MealItem>>.multi(
      (multi) {
        // Emit current snapshot immediately for THIS listener
        multi.add(_latestMeals[key] ?? const <user_meal_plan_repository.MealItem>[]);

        // Forward subsequent updates
        final sub = controller.stream.listen(
          (meals) => multi.add(meals),
          onError: (error, stackTrace) => multi.addError(error, stackTrace),
          onDone: () => multi.close(),
          cancelOnError: false,
        );

        multi.onCancel = () => sub.cancel();
      },
      isBroadcast: true, // ✅ critical: allow multiple listeners
    );
  }

  @override
  Future<bool> saveDayMealsBatch({
    required String planId,
    required String userId,
    required int dayIndex,
    required List<user_meal_plan_repository.MealItem> mealsToSave,
    required List<String> mealsToDelete,
  }) async {
    return true;
  }

  @override
  Future<UserMealPlan> applyExploreTemplateAsActivePlan({
    required String userId,
    required String templateId,
    required ExploreMealPlan template,
    required Map<String, dynamic> profileData,
  }) async {
    // Return a fake plan for testing
    return UserMealPlan(
      id: 'test-plan-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      planTemplateId: templateId,
      name: template.name,
      goalType: MealPlanGoalType.maintain,
      type: UserMealPlanType.template,
      startDate: DateTime.now(),
      currentDayIndex: 1,
      status: UserMealPlanStatus.active,
      dailyCalories: template.templateKcal.toInt(),
      durationDays: template.durationDays,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<UserMealPlan> applyCustomPlanAsActive({
    required String userId,
    required String planId,
  }) async {
    // Return a fake plan for testing
    return UserMealPlan(
      id: planId,
      userId: userId,
      name: 'Test Plan',
      goalType: MealPlanGoalType.maintain,
      type: UserMealPlanType.custom,
      startDate: DateTime.now(),
      currentDayIndex: 1,
      status: UserMealPlanStatus.active,
      dailyCalories: 2000,
      durationDays: 7,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
