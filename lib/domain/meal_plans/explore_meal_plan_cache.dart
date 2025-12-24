import 'explore_meal_plan.dart';

/// Abstract cache interface for Explore Meal Plan caching
/// 
/// This is a pure domain interface with no dependencies on Flutter or Firebase.
/// Implementations should use SharedPreferences or similar local storage.

abstract class ExploreMealPlanCache {
  /// Load all published plans from cache
  Future<List<ExploreMealPlan>> loadPublishedPlans();

  /// Save published plans to cache
  Future<void> savePublishedPlans(List<ExploreMealPlan> plans);

  /// Load a specific plan by ID from cache
  Future<ExploreMealPlan?> loadPlanById(String planId);

  /// Save a plan to cache
  Future<void> savePlan(ExploreMealPlan plan);

  /// Clear all cached plans
  Future<void> clearAll();

  /// Clear a specific plan from cache
  Future<void> clearPlan(String planId);
}

