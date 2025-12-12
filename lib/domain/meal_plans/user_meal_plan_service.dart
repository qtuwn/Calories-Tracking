import 'dart:async';
import 'user_meal_plan.dart';
import 'user_meal_plan_repository.dart' show UserMealPlanRepository, MealItem;
import 'user_meal_plan_repository.dart' as repo show MealPlanDay;
import 'user_meal_plan_cache.dart';
import 'explore_meal_plan.dart';

/// Service for managing user meal plans with a hybrid cache-first, then network strategy.
/// 
/// This service orchestrates between the local cache (UserMealPlanCache) and
/// the remote data source (UserMealPlanRepository) to provide instant UI feedback
/// and background synchronization.

class UserMealPlanService {
  final UserMealPlanRepository _repository;
  final UserMealPlanCache _cache;

  UserMealPlanService(this._repository, this._cache);

  /// Watch active plan for a user, loading from cache first and then syncing with Firestore.
  /// 
  /// Strategy:
  /// 1. Subscribe to Firestore stream first (source of truth)
  /// 2. While waiting for first Firestore emission, emit cached plan if available
  /// 3. Once Firestore emits, always use Firestore value and update cache
  /// 
  /// This ensures Firestore is the source of truth and cache doesn't interfere
  /// with recent apply operations.
  Stream<UserMealPlan?> watchActivePlanWithCache(String userId) async* {
    print('[UserMealPlanService] [ActivePlan] 🔵 Setting up active plan stream for userId=$userId');
    
    // 1. Load from cache first and emit immediately (for instant UI)
    final cachedPlan = await _cache.loadActivePlan(userId);
    if (cachedPlan != null) {
      print('[UserMealPlanService] [ActivePlan] 📦 Emitting from cache: planId=${cachedPlan.id}, name="${cachedPlan.name}"');
      yield cachedPlan;
    } else {
      print('[UserMealPlanService] [ActivePlan] 📦 No cached plan, emitting null');
      yield null; // Emit null to show UI is ready
    }

    // 2. Subscribe to Firestore updates (source of truth)
    // This will override any cached value once Firestore emits
    await for (final remotePlan in _repository.getActivePlan(userId)) {
      if (remotePlan != null) {
        print('[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore: planId=${remotePlan.id}, name="${remotePlan.name}", isActive=${remotePlan.isActive}');
      } else {
        print('[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore: null (no active plan)');
      }
      
      yield remotePlan;
      
      // Save to cache when we get updates from Firestore
      await _cache.saveActivePlan(userId, remotePlan);
      if (remotePlan != null) {
        print('[UserMealPlanService] [ActivePlan] 💾 Saved to cache: planId=${remotePlan.id}');
      } else {
        print('[UserMealPlanService] [ActivePlan] 💾 Cleared cache (no active plan)');
      }
    }
  }

  /// Load active plan once, prioritizing cache.
  Future<UserMealPlan?> loadActivePlanOnce(String userId) async {
    // Try cache first
    final cached = await _cache.loadActivePlan(userId);
    if (cached != null) {
      return cached;
    }

    // Fallback to repository
    final plan = await _repository.getActivePlan(userId).first;
    if (plan != null) {
      await _cache.saveActivePlan(userId, plan);
    }
    return plan;
  }

  /// Watch all plans for a user, loading from cache first.
  Stream<List<UserMealPlan>> watchPlansForUserWithCache(String userId) async* {
    // 1. Load from cache first and emit immediately
    final cachedPlans = await _cache.loadPlansForUser(userId);
    if (cachedPlans.isNotEmpty) {
      yield cachedPlans;
    } else {
      yield []; // Emit empty list to show UI is ready
    }

    // 2. Subscribe to Firestore updates
    await for (final remotePlans in _repository.getPlansForUser(userId)) {
      yield remotePlans;
      // Save to cache when we get updates from Firestore
      await _cache.savePlansForUser(userId, remotePlans);
    }
  }

  /// Load all plans once, prioritizing cache.
  Future<List<UserMealPlan>> loadPlansForUserOnce(String userId) async {
    // Try cache first
    final cached = await _cache.loadPlansForUser(userId);
    if (cached.isNotEmpty) {
      return cached;
    }

    // Fallback to repository
    final plans = await _repository.getPlansForUser(userId).first;
    if (plans.isNotEmpty) {
      await _cache.savePlansForUser(userId, plans);
    }
    return plans;
  }

  /// Save a meal plan and update cache.
  Future<void> savePlan(UserMealPlan plan) async {
    await _repository.savePlan(plan);
    // Update cache
    await _cache.savePlan(plan.userId, plan);
    // Invalidate user's plans list cache
    await _cache.clearAllForUser(plan.userId);
  }

  /// Save plan and set as active, updating cache.
  Future<void> savePlanAndSetActive({
    required UserMealPlan plan,
    required String userId,
  }) async {
    await _repository.savePlanAndSetActive(plan: plan, userId: userId);
    // Update cache
    await _cache.saveActivePlan(userId, plan);
    await _cache.savePlan(userId, plan);
    // Invalidate user's plans list cache
    await _cache.clearAllForUser(userId);
  }

  /// Set a plan as active, updating cache.
  Future<void> setActivePlan({
    required String userId,
    required String planId,
  }) async {
    await _repository.setActivePlan(userId: userId, planId: planId);
    // Reload active plan and update cache
    final plan = await _repository.getActivePlan(userId).first;
    await _cache.saveActivePlan(userId, plan);
    // Invalidate user's plans list cache
    await _cache.clearAllForUser(userId);
  }

  /// Delete a plan and clear from cache.
  Future<void> deletePlan(String planId, String userId) async {
    await _repository.deletePlan(planId, userId);
    // Clear from cache
    await _cache.clearPlan(userId, planId);
    // Invalidate user's plans list cache
    await _cache.clearAllForUser(userId);
  }

  /// Apply explore template as active plan.
  /// 
  /// Clears stale active plan cache before applying to ensure fresh data.
  Future<UserMealPlan> applyExploreTemplateAsActivePlan({
    required String userId,
    required String templateId,
    required ExploreMealPlan template,
    required Map<String, dynamic> profileData,
  }) async {
    print('[UserMealPlanService] [ApplyExplore] 🚀 Starting apply explore template: templateId=$templateId, userId=$userId');
    
    // Clear stale active plan cache before applying
    // This ensures watchActivePlanWithCache doesn't emit stale cached data
    await _cache.clearActivePlan(userId);
    print('[UserMealPlanService] [ApplyExplore] 🧹 Cleared stale active plan cache');
    
    // Apply template via repository
    final plan = await _repository.applyExploreTemplateAsActivePlan(
      userId: userId,
      templateId: templateId,
      template: template,
      profileData: profileData,
    );
    
    print('[UserMealPlanService] [ApplyExplore] ✅ Repository returned new plan: planId=${plan.id}, name="${plan.name}", isActive=${plan.isActive}');
    
    // Update cache with new active plan
    await _cache.saveActivePlan(userId, plan);
    await _cache.savePlan(userId, plan);
    print('[UserMealPlanService] [ApplyExplore] 💾 Saved new active plan to cache');
    
    // Invalidate user's plans list cache
    await _cache.clearAllForUser(userId);
    
    print('[UserMealPlanService] [ApplyExplore] ✅ Apply complete: planId=${plan.id}');
    return plan;
  }

  /// Apply custom plan as active, updating cache.
  /// 
  /// Clears stale active plan cache before applying to ensure fresh data.
  /// 
  /// Call chain: Service → Repository → Firestore batch write
  Future<UserMealPlan> applyCustomPlanAsActive({
    required String userId,
    required String planId,
  }) async {
    print('[UserMealPlanService] [ApplyCustom] ========== START applyCustomPlanAsActive ==========');
    print('[UserMealPlanService] [ApplyCustom] 🚀 Starting apply custom plan');
    print('[UserMealPlanService] [ApplyCustom] 📋 Plan ID: $planId');
    print('[UserMealPlanService] [ApplyCustom] 👤 User ID: $userId');
    
    // Validate inputs
    if (userId.isEmpty) {
      throw Exception('User ID cannot be empty');
    }
    if (planId.isEmpty) {
      throw Exception('Plan ID cannot be empty');
    }
    
    // Clear stale active plan cache before applying
    // This ensures watchActivePlanWithCache doesn't emit stale cached data
    print('[UserMealPlanService] [ApplyCustom] 🧹 Step 1: Clearing stale active plan cache for userId=$userId');
    await _cache.clearActivePlan(userId);
    print('[UserMealPlanService] [ApplyCustom] ✅ Cleared stale active plan cache');
    
    // Apply custom plan via repository (this does the actual Firestore write)
    print('[UserMealPlanService] [ApplyCustom] 🔄 Step 2: Calling repository.applyCustomPlanAsActive()...');
    print('[UserMealPlanService] [ApplyCustom] 🔄 This will perform Firestore batch write to set isActive=true');
    
    final plan = await _repository.applyCustomPlanAsActive(
      userId: userId,
      planId: planId,
    );
    
    // Verify the plan returned from repository is actually active
    if (!plan.isActive) {
      print('[UserMealPlanService] [ApplyCustom] 🔥 CRITICAL: Repository returned plan with isActive=false!');
      print('[UserMealPlanService] [ApplyCustom] 🔥 Plan ID: ${plan.id}, isActive: ${plan.isActive}');
      throw Exception('Repository returned inactive plan - Firestore write may have failed');
    }
    
    print('[UserMealPlanService] [ApplyCustom] ✅ Repository returned new plan: planId=${plan.id}, name="${plan.name}", isActive=${plan.isActive}');
    
    // Update cache with new active plan
    print('[UserMealPlanService] [ApplyCustom] 💾 Step 3: Saving new active plan to cache...');
    await _cache.saveActivePlan(userId, plan);
    print('[UserMealPlanService] [ApplyCustom] ✅ Saved new active plan to cache: planId=${plan.id}');
    
    // Invalidate user's plans list cache
    print('[UserMealPlanService] [ApplyCustom] 🧹 Step 4: Clearing user plans list cache...');
    await _cache.clearAllForUser(userId);
    print('[UserMealPlanService] [ApplyCustom] ✅ Cleared user plans list cache');
    
    print('[UserMealPlanService] [ApplyCustom] ✅ Apply complete: planId=${plan.id}, isActive=${plan.isActive}');
    print('[UserMealPlanService] [ApplyCustom] ========== END applyCustomPlanAsActive (SUCCESS) ==========');
    return plan;
  }

  /// Update plan status and clear cache.
  Future<void> updatePlanStatus({
    required String planId,
    required String userId,
    required String status,
  }) async {
    await _repository.updatePlanStatus(
      planId: planId,
      userId: userId,
      status: status,
    );
    // Invalidate cache
    await _cache.clearPlan(userId, planId);
    await _cache.clearAllForUser(userId);
  }

  /// Load plan by ID once, prioritizing cache.
  Future<UserMealPlan?> loadPlanByIdOnce(String userId, String planId) async {
    // Try cache first
    final cached = await _cache.loadPlanById(userId, planId);
    if (cached != null) {
      return cached;
    }

    // Fallback to repository
    final plan = await _repository.getPlanById(planId, userId);
    if (plan != null) {
      await _cache.savePlan(userId, plan);
    }
    return plan;
  }

  /// Clear cache for a user.
  Future<void> clearCacheForUser(String userId) async {
    await _cache.clearAllForUser(userId);
  }

  /// Get a specific day from user's meal plan
  Future<repo.MealPlanDay?> getDay(String planId, String userId, int dayIndex) async {
    return await _repository.getDay(planId, userId, dayIndex);
  }

  /// Get meals for a specific day (stream for real-time updates)
  /// 
  /// Note: Meals are subcollections and don't need caching as they're frequently updated.
  /// This method directly exposes the repository stream.
  Stream<List<MealItem>> getDayMeals(
    String planId,
    String userId,
    int dayIndex,
  ) {
    return _repository.getDayMeals(planId, userId, dayIndex);
  }

  /// Save all meals for a day using batch write
  /// 
  /// Note: Meals are subcollections and don't need caching.
  /// This method directly uses the repository for batch writes.
  Future<bool> saveDayMealsBatch({
    required String planId,
    required String userId,
    required int dayIndex,
    required List<MealItem> mealsToSave,
    required List<String> mealsToDelete,
  }) async {
    return await _repository.saveDayMealsBatch(
      planId: planId,
      userId: userId,
      dayIndex: dayIndex,
      mealsToSave: mealsToSave,
      mealsToDelete: mealsToDelete,
    );
  }
}

