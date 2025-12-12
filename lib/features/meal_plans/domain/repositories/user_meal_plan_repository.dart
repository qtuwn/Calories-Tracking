import 'package:calories_app/features/meal_plans/domain/models/user/user_meal_plan.dart';
import 'package:calories_app/features/meal_plans/domain/models/user/user_meal_day.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/meal_item.dart';
import 'package:calories_app/features/meal_plans/domain/models/explore/explore_meal_plan_template.dart';
import 'package:calories_app/domain/profile/profile.dart';

/// Repository interface for user meal plans
/// 
/// This is a domain interface - implementations are in the data layer.
/// Domain layer depends on this abstraction, not on Firestore directly.
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
  /// This ensures no race condition where two plans are active simultaneously
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
  Future<UserMealDay?> getDay(String planId, String userId, int dayIndex);

  /// Get meals for a specific day (stream for real-time updates)
  Stream<List<MealItem>> getDayMeals(
    String planId,
    String userId,
    int dayIndex,
  );

  /// Save all meals for a day using batch write
  /// 
  /// [mealsToSave] - List of meals to add or update (empty ID = new meal)
  /// [mealsToDelete] - List of meal IDs to delete
  /// 
  /// Returns true if successful (or queued offline)
  Future<bool> saveDayMealsBatch({
    required String planId,
    required String userId,
    required int dayIndex,
    required List<MealItem> mealsToSave,
    required List<String> mealsToDelete,
  });

  /// Apply an explore template as the NEW active plan for this user.
  /// 
  /// This method:
  /// - Deactivates any existing active plan (using Firestore transaction)
  /// - Creates a new user_meal_plans document with type = 'template' and isActive = true
  /// - Copies all template meals into the new plan's subcollections
  /// - Guarantees there is at most one isActive == true plan after completion
  /// 
  /// Returns the newly created UserMealPlan.
  Future<UserMealPlan> applyExploreTemplateAsActivePlan({
    required String userId,
    required String templateId,
    required ExploreMealPlanTemplate template,
    required Profile profile,
  });

  /// Apply a custom meal plan as the active plan for this user.
  /// 
  /// This method:
  /// - Deactivates any existing active plan (using Firestore batch/transaction)
  /// - Sets the specified plan as active (isActive = true)
  /// - Guarantees there is at most one isActive == true plan after completion
  /// 
  /// Returns the activated UserMealPlan.
  Future<UserMealPlan> applyCustomPlanAsActive({
    required String userId,
    required String planId,
  });
}

