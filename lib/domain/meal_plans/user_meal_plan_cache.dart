import 'user_meal_plan.dart';

/// Abstract cache interface for User Meal Plan caching
/// 
/// This is a pure domain interface with no dependencies on Flutter or Firebase.
/// Implementations should use SharedPreferences or similar local storage.

abstract class UserMealPlanCache {
  /// Load active plan for a user from cache
  Future<UserMealPlan?> loadActivePlan(String userId);

  /// Save active plan to cache
  Future<void> saveActivePlan(String userId, UserMealPlan? plan);

  /// Load all plans for a user from cache
  Future<List<UserMealPlan>> loadPlansForUser(String userId);

  /// Save all plans for a user to cache
  Future<void> savePlansForUser(String userId, List<UserMealPlan> plans);

  /// Load a specific plan by ID from cache
  Future<UserMealPlan?> loadPlanById(String userId, String planId);

  /// Save a plan to cache
  Future<void> savePlan(String userId, UserMealPlan plan);

  /// Clear all cached plans for a user
  Future<void> clearAllForUser(String userId);

  /// Clear a specific plan from cache
  Future<void> clearPlan(String userId, String planId);

  /// Clear the active plan from cache for a user
  /// 
  /// This is useful when applying a new plan to ensure stale cache doesn't interfere.
  Future<void> clearActivePlan(String userId);
}

