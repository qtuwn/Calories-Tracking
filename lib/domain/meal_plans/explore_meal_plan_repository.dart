import 'explore_meal_plan.dart';
import 'meal_plan_goal_type.dart';

/// Abstract repository interface for Explore Meal Plan operations
/// 
/// This is a pure domain interface with no dependencies on Flutter or Firebase.
/// Implementations should be in the data layer.
abstract class ExploreMealPlanRepository {
  /// Watch all published meal plans (for users)
  Stream<List<ExploreMealPlan>> watchPublishedPlans();

  /// Watch all meal plans including unpublished (for admin)
  Stream<List<ExploreMealPlan>> watchAllPlans();

  /// Get a single meal plan by ID
  Future<ExploreMealPlan?> getPlanById(String planId);

  /// Search meal plans
  /// [query] - Search query (name/description)
  /// [goalType] - Optional goal type filter
  /// [minKcal] - Optional minimum calories filter
  /// [maxKcal] - Optional maximum calories filter
  /// [tags] - Optional tags filter
  Stream<List<ExploreMealPlan>> searchPlans({
    String? query,
    MealPlanGoalType? goalType,
    int? minKcal,
    int? maxKcal,
    List<String>? tags,
  });

  /// Get featured meal plans
  Stream<List<ExploreMealPlan>> getFeaturedPlans();

  /// Get meal plan days for a specific plan
  Stream<List<MealPlanDay>> getPlanDays(String planId);

  /// Get meals for a specific day in a plan
  Stream<List<MealSlot>> getDayMeals(String planId, int dayIndex);

  /// Create a new meal plan
  /// Returns the created plan with generated ID
  Future<ExploreMealPlan> createPlan(ExploreMealPlan plan);

  /// Update an existing meal plan
  Future<void> updatePlan(ExploreMealPlan plan);

  /// Delete a meal plan and all its days/meals
  Future<void> deletePlan(String planId);

  /// Publish/unpublish a meal plan
  Future<void> setPublishStatus(String planId, bool isPublished);

  /// Save meals for a specific day (batch operation)
  /// [mealsToSave] - Meals to add or update (empty ID = new meal)
  /// [mealsToDelete] - Meal IDs to delete
  Future<void> saveDayMeals({
    required String planId,
    required int dayIndex,
    required List<MealSlot> mealsToSave,
    required List<String> mealsToDelete,
  });
}

