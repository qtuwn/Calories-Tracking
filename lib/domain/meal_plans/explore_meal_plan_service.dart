import 'explore_meal_plan.dart';
import 'explore_meal_plan_repository.dart';
import 'explore_meal_plan_cache.dart';

/// Business logic service for Explore Meal Plan operations
/// 
/// This service handles validation, business rules, and coordinates
/// between the repository and cache for hybrid cache-first architecture.
class ExploreMealPlanService {
  final ExploreMealPlanRepository _repository;
  final ExploreMealPlanCache? _cache;

  ExploreMealPlanService(this._repository, [this._cache]);

  /// Validate meal plan before creation
  /// Throws [Exception] if validation fails
  void validateForCreate(ExploreMealPlan plan) {
    if (plan.name.trim().isEmpty) {
      throw Exception('Meal plan name cannot be empty');
    }

    if (plan.templateKcal <= 0 || plan.templateKcal > 10000) {
      throw Exception('Daily calories must be between 1 and 10000');
    }

    if (plan.durationDays <= 0 || plan.durationDays > 365) {
      throw Exception('Duration must be between 1 and 365 days');
    }

    if (plan.mealsPerDay <= 0 || plan.mealsPerDay > 10) {
      throw Exception('Meals per day must be between 1 and 10');
    }

    if (plan.description.trim().isEmpty) {
      throw Exception('Description cannot be empty');
    }
  }

  /// Validate meal plan before update
  /// Throws [Exception] if validation fails
  void validateForUpdate(ExploreMealPlan plan) {
    validateForCreate(plan);

    if (plan.id.isEmpty) {
      throw Exception('Meal plan ID cannot be empty for update');
    }
  }

  /// Validate meal slot
  /// Throws [Exception] if validation fails
  void validateMealSlot(MealSlot meal) {
    if (meal.name.trim().isEmpty) {
      throw Exception('Meal name cannot be empty');
    }

    if (meal.calories < 0) {
      throw Exception('Calories cannot be negative');
    }

    if (meal.protein < 0 || meal.carb < 0 || meal.fat < 0) {
      throw Exception('Macros cannot be negative');
    }

    final validMealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    if (!validMealTypes.contains(meal.mealType)) {
      throw Exception('Invalid meal type: ${meal.mealType}');
    }
  }

  /// Stream published plans with cache-first logic
  /// Emits cached data immediately, then streams from Firestore
  Stream<List<ExploreMealPlan>> watchPublishedPlansWithCache() async* {
    // Emit cached data first if available
    final cache = _cache;
    if (cache != null) {
      try {
        final cached = await cache.loadPublishedPlans();
        if (cached.isNotEmpty) {
          yield cached;
        }
      } catch (e) {
        // Cache error, continue to Firestore
      }
    }

    // Stream from Firestore and update cache
    await for (final plans in _repository.watchPublishedPlans()) {
      yield plans;
      final cacheForUpdate = _cache;
      if (cacheForUpdate != null) {
        try {
          await cacheForUpdate.savePublishedPlans(plans);
        } catch (e) {
          // Cache error, continue streaming
        }
      }
    }
  }

  /// Load published plans once, prioritizing cache
  Future<List<ExploreMealPlan>> loadPublishedPlansOnce() async {
    // Try cache first
    final cache = _cache;
    if (cache != null) {
      try {
        final cached = await cache.loadPublishedPlans();
        if (cached.isNotEmpty) {
          return cached;
        }
      } catch (e) {
        // Cache error, fallback to Firestore
      }
    }

    // Fallback to Firestore - get first snapshot from stream
    final plans = await _repository.watchPublishedPlans().first;
    
    // Save to cache
    final cacheForSave = _cache;
    if (cacheForSave != null && plans.isNotEmpty) {
      try {
        await cacheForSave.savePublishedPlans(plans);
      } catch (e) {
        // Cache error, continue
      }
    }

    return plans;
  }

  /// Stream a plan by ID with cache-first logic
  /// Note: Repository doesn't have watchPlanById, so we use getPlanById in a loop
  /// For real-time updates, consider adding watchPlanById to repository
  Stream<ExploreMealPlan?> watchPlanByIdWithCache(String planId) async* {
    // Emit cached data first if available
    final cache = _cache;
    if (cache != null) {
      try {
        final cached = await cache.loadPlanById(planId);
        if (cached != null) {
          yield cached;
        }
      } catch (e) {
        // Cache error, continue to Firestore
      }
    }

    // For now, use getPlanById (one-time fetch)
    // TODO: Add watchPlanById to repository for real-time updates
    final plan = await _repository.getPlanById(planId);
    yield plan;
    
    final cacheForSave = _cache;
    if (cacheForSave != null && plan != null) {
      try {
        await cacheForSave.savePlan(plan);
      } catch (e) {
        // Cache error, continue
      }
    }
  }

  /// Load a plan by ID once, prioritizing cache
  Future<ExploreMealPlan?> loadPlanByIdOnce(String planId) async {
    // Try cache first
    final cache = _cache;
    if (cache != null) {
      try {
        final cached = await cache.loadPlanById(planId);
        if (cached != null) {
          return cached;
        }
      } catch (e) {
        // Cache error, fallback to Firestore
      }
    }

    // Fallback to Firestore
    final plan = await _repository.getPlanById(planId);
    
    // Save to cache
    final cacheForSave = _cache;
    if (cacheForSave != null && plan != null) {
      try {
        await cacheForSave.savePlan(plan);
      } catch (e) {
        // Cache error, continue
      }
    }

    return plan;
  }

  /// Create a new meal plan with validation
  Future<ExploreMealPlan> createPlan(ExploreMealPlan plan) async {
    validateForCreate(plan);
    final created = await _repository.createPlan(plan);
    
    // Update cache if available
    final cache = _cache;
    if (cache != null) {
      try {
        await cache.savePlan(created);
      } catch (e) {
        // Cache error, continue
      }
    }
    
    return created;
  }

  /// Update an existing meal plan with validation
  Future<void> updatePlan(ExploreMealPlan plan) async {
    validateForUpdate(plan);

    // Check if plan exists
    final existing = await _repository.getPlanById(plan.id);
    if (existing == null) {
      throw Exception('Meal plan not found: ${plan.id}');
    }

    await _repository.updatePlan(plan.copyWith(updatedAt: DateTime.now()));
    
    // Update cache if available
    final cache = _cache;
    if (cache != null) {
      try {
        await cache.savePlan(plan.copyWith(updatedAt: DateTime.now()));
      } catch (e) {
        // Cache error, continue
      }
    }
  }

  /// Publish a meal plan
  /// Validates that the plan has at least one day with meals
  Future<void> publishPlan(String planId) async {
    final plan = await _repository.getPlanById(planId);
    if (plan == null) {
      throw Exception('Meal plan not found: $planId');
    }

    // Check if plan has days with meals
    final days = await _repository.getPlanDays(planId).first;
    if (days.isEmpty) {
      throw Exception('Cannot publish plan: no days defined');
    }

    // Check if at least one day has meals
    bool hasMeals = false;
    for (final day in days) {
      final meals = await _repository.getDayMeals(planId, day.dayIndex).first;
      if (meals.isNotEmpty) {
        hasMeals = true;
        break;
      }
    }

    if (!hasMeals) {
      throw Exception('Cannot publish plan: no meals defined');
    }

    await _repository.setPublishStatus(planId, true);
  }

  /// Unpublish a meal plan
  Future<void> unpublishPlan(String planId) async {
    final plan = await _repository.getPlanById(planId);
    if (plan == null) {
      throw Exception('Meal plan not found: $planId');
    }

    await _repository.setPublishStatus(planId, false);
  }

  /// Delete a meal plan
  Future<void> deletePlan(String planId) async {
    final plan = await _repository.getPlanById(planId);
    if (plan == null) {
      throw Exception('Meal plan not found: $planId');
    }

    await _repository.deletePlan(planId);
    
    // Clear cache if available
    final cache = _cache;
    if (cache != null) {
      try {
        await cache.clearPlan(planId);
      } catch (e) {
        // Cache error, continue
      }
    }
  }

  /// Clear all cached plans
  Future<void> clearCache() async {
    final cache = _cache;
    if (cache != null) {
      try {
        await cache.clearAll();
      } catch (e) {
        // Cache error, continue
      }
    }
  }

  /// Save meals for a day with validation
  Future<void> saveDayMeals({
    required String planId,
    required int dayIndex,
    required List<MealSlot> mealsToSave,
    required List<String> mealsToDelete,
  }) async {
    // Validate all meals
    for (final meal in mealsToSave) {
      validateMealSlot(meal);
    }

    await _repository.saveDayMeals(
      planId: planId,
      dayIndex: dayIndex,
      mealsToSave: mealsToSave,
      mealsToDelete: mealsToDelete,
    );
  }
}

