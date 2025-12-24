import 'user_meal_plan.dart';
import 'explore_meal_plan.dart';

/// Abstract repository interface for User Meal Plan operations
/// 
/// This is a pure domain interface with no dependencies on Flutter or Firebase.
/// Implementations should be in the data layer.

/// Meal item for user meal plans
class MealItem {
  final String id;
  final String mealType; // "breakfast" | "lunch" | "dinner" | "snack"
  final String foodId; // Reference to food catalog
  final double servingSize;
  final double calories;
  final double protein;
  final double carb;
  final double fat;

  const MealItem({
    required this.id,
    required this.mealType,
    required this.foodId,
    required this.servingSize,
    required this.calories,
    required this.protein,
    required this.carb,
    required this.fat,
  });

  MealItem copyWith({
    String? id,
    String? mealType,
    String? foodId,
    double? servingSize,
    double? calories,
    double? protein,
    double? carb,
    double? fat,
  }) {
    return MealItem(
      id: id ?? this.id,
      mealType: mealType ?? this.mealType,
      foodId: foodId ?? this.foodId,
      servingSize: servingSize ?? this.servingSize,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carb: carb ?? this.carb,
      fat: fat ?? this.fat,
    );
  }
}

/// Meal plan day summary
class MealPlanDay {
  final String id;
  final int dayIndex; // 1...durationDays
  final double totalCalories;
  final double totalProtein;
  final double totalCarb;
  final double totalFat;

  const MealPlanDay({
    required this.id,
    required this.dayIndex,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarb,
    required this.totalFat,
  });

  MealPlanDay copyWith({
    String? id,
    int? dayIndex,
    double? totalCalories,
    double? totalProtein,
    double? totalCarb,
    double? totalFat,
  }) {
    return MealPlanDay(
      id: id ?? this.id,
      dayIndex: dayIndex ?? this.dayIndex,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProtein: totalProtein ?? this.totalProtein,
      totalCarb: totalCarb ?? this.totalCarb,
      totalFat: totalFat ?? this.totalFat,
    );
  }
}

abstract class UserMealPlanRepository {
  /// Get the active meal plan for a user
  /// Returns null if no active plan exists
  Stream<UserMealPlan?> getActivePlan(String userId);

  /// Get all meal plans for a user
  Stream<List<UserMealPlan>> getPlansForUser(String userId);

  /// Get a specific meal plan by ID
  Future<UserMealPlan?> getPlanById(String planId, String userId);

  /// Save a meal plan (create or update)
  Future<void> savePlan(UserMealPlan plan);

  /// Delete a meal plan
  Future<void> deletePlan(String planId, String userId);

  /// Set a meal plan as active (deactivates all others for the user)
  Future<void> setActivePlan({
    required String userId,
    required String planId,
  });

  /// Save a new meal plan and set it as active atomically
  Future<void> savePlanAndSetActive({
    required UserMealPlan plan,
    required String userId,
  });

  /// Update plan progress (currentDayIndex)
  Future<void> updatePlanProgress({
    required String planId,
    required String userId,
    required int currentDayIndex,
  });

  /// Update plan status
  Future<void> updatePlanStatus({
    required String planId,
    required String userId,
    required String status, // "active" | "paused" | "finished"
  });

  /// Get a specific day from user's meal plan
  Future<MealPlanDay?> getDay(String planId, String userId, int dayIndex);

  /// Get meals for a specific day (stream for real-time updates)
  Stream<List<MealItem>> getDayMeals(
    String planId,
    String userId,
    int dayIndex,
  );

  /// Save all meals for a day using batch write
  Future<bool> saveDayMealsBatch({
    required String planId,
    required String userId,
    required int dayIndex,
    required List<MealItem> mealsToSave,
    required List<String> mealsToDelete,
  });

  /// Apply an explore template as the NEW active plan for this user
  /// Returns the newly created UserMealPlan
  Future<UserMealPlan> applyExploreTemplateAsActivePlan({
    required String userId,
    required String templateId,
    required ExploreMealPlan template,
    required Map<String, dynamic> profileData, // Profile data for calculations
  });

  /// Apply a custom meal plan as the active plan for this user
  /// Returns the activated UserMealPlan
  Future<UserMealPlan> applyCustomPlanAsActive({
    required String userId,
    required String planId,
  });
}

