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

  /// Watch active plan for a user with cache-first fallback and Firestore as source of truth.
  /// 
  /// Policy A: Prefer Firestore first, fallback to cache with timeout
  /// 
  /// Strategy:
  /// 1. Subscribe to Firestore stream immediately (source of truth)
  /// 2. Wait up to 300ms for first Firestore emission
  /// 3. If Firestore emits within timeout: emit that as first value (no cache flicker)
  /// 4. If Firestore doesn't emit within timeout: emit cachedPlan (if any) as temporary value
  /// 5. When Firestore eventually emits: dedupe by planId; emit only if different
  /// 6. Persist remote -> cache after each remote emission
  /// 
  /// This prevents UI flicker when cache has stale data after Apply operations.
  Stream<UserMealPlan?> watchActivePlanWithCache(String userId) async* {
    print('[UserMealPlanService] [ActivePlan] 🔵 Setting up active plan stream for userId=$userId');
    
    // Subscribe to Firestore stream (source of truth)
    final firestoreStream = _repository.getActivePlan(userId);
    
    // Use a single subscription with gating to avoid double-emission
    final controller = StreamController<UserMealPlan?>();
    String? lastEmittedPlanId;
    UserMealPlan? firstRemotePlan;
    UserMealPlan? pendingFirstPlan;
    bool firstEmissionReceived = false;
    bool firstValueDecisionMade = false;
    final firstEmissionCompleter = Completer<UserMealPlan?>();
    
    // Set up single subscription to capture all events without dropping
    final subscription = firestoreStream.listen(
      (plan) {
        final planId = plan?.id;
        
        // Capture first emission for timeout logic
        if (!firstEmissionReceived) {
          firstEmissionReceived = true;
          firstRemotePlan = plan;
          if (!firstEmissionCompleter.isCompleted) {
            firstEmissionCompleter.complete(plan);
          }
        }
        
        // Gate: only forward to controller after first-value decision is made
        // If decision not made yet, store latest plan to avoid losing it
        if (!firstValueDecisionMade) {
          pendingFirstPlan = plan; // Store instead of losing
          return;
        }
        
        // Deduplicate: only add to controller if planId changed
        if (planId != lastEmittedPlanId) {
          lastEmittedPlanId = planId;
          if (!controller.isClosed) {
            controller.add(plan);
          }
          // Save to cache
          _cache.saveActivePlan(userId, plan).then((_) {
            if (plan != null) {
              print('[UserMealPlanService] [ActivePlan] 💾 Saved to cache: planId=${plan.id}');
            }
          });
        } else {
          print('[UserMealPlanService] [ActivePlan] ⏭️ Skipping duplicate emission: planId=$planId');
          // Still update cache even if we skip emission
          _cache.saveActivePlan(userId, plan);
        }
      },
      onError: (error, stackTrace) {
        if (!firstEmissionCompleter.isCompleted) {
          firstEmissionCompleter.completeError(error, stackTrace);
        }
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
      },
      cancelOnError: false,
    );
    
    // Wait for first Firestore emission with timeout (300ms)
    const timeout = Duration(milliseconds: 300);
    bool firestoreEmittedQuickly = false;
    
    print('[ActivePlanCache] ⏳ waiting first Firestore emission timeout=${timeout.inMilliseconds}ms');
    
    try {
      firstRemotePlan = await firstEmissionCompleter.future.timeout(timeout);
      firestoreEmittedQuickly = true;
      print('[ActivePlanCache] ✅ Firestore first emission received planId=${firstRemotePlan?.id ?? "null"}');
    } catch (e) {
      if (e is TimeoutException) {
        print('[ActivePlanCache] ⚠️ Firestore timeout → will emit cached plan if available');
      } else {
        print('[UserMealPlanService] [ActivePlan] ⚠️ Firestore stream error: $e');
      }
      firestoreEmittedQuickly = false;
    }
    
    // Emit first value based on Firestore availability
    if (firestoreEmittedQuickly) {
      // Firestore emitted quickly - emit it first (no cache flicker)
      if (firstRemotePlan != null) {
        print('[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore (first): planId=${firstRemotePlan!.id}, name="${firstRemotePlan!.name}"');
      } else {
        print('[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore (first): null (no active plan)');
      }
      yield firstRemotePlan;
      lastEmittedPlanId = firstRemotePlan?.id;
    } else {
      // Firestore timeout - emit cached plan if available, otherwise emit null
      final cachedPlan = await _cache.loadActivePlan(userId);
      if (cachedPlan != null) {
        print('[UserMealPlanService] [ActivePlan] 📦 Firestore timeout - emitting cached plan: planId=${cachedPlan.id}');
        yield cachedPlan;
        lastEmittedPlanId = cachedPlan.id;
      } else {
        print('[UserMealPlanService] [ActivePlan] 📦 Firestore timeout - emitting NULL (no cache available)');
        yield null;
        lastEmittedPlanId = null;
      }
      print('[UserMealPlanService] [ActivePlan] 📡 Will continue streaming Firestore emissions...');
    }
    
    // Now allow controller to forward events (gate is open)
    firstValueDecisionMade = true;
    
    // Flush pending plan if timeout occurred (firestoreEmittedQuickly == false)
    // Use pendingFirstPlan if available (latest), otherwise fall back to firstRemotePlan
    if (!firestoreEmittedQuickly) {
      final planToFlush = pendingFirstPlan ?? firstRemotePlan;
      if (planToFlush != null) {
        final planId = planToFlush.id;
        if (planId != lastEmittedPlanId) {
          lastEmittedPlanId = planId;
          if (!controller.isClosed) {
            controller.add(planToFlush);
          }
          _cache.saveActivePlan(userId, planToFlush).then((_) {
            print('[UserMealPlanService] [ActivePlan] 💾 Saved to cache: planId=${planToFlush.id}');
          });
        } else {
          // Still update cache even if duplicate
          _cache.saveActivePlan(userId, planToFlush);
        }
      }
    }
    
    // Continue streaming remaining Firestore updates (already deduplicated in listener)
    await for (final remotePlan in controller.stream) {
      if (remotePlan != null) {
        print('[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore: planId=${remotePlan.id}, name="${remotePlan.name}", isActive=${remotePlan.isActive}');
      } else {
        print('[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore: null (no active plan)');
      }
      yield remotePlan;
    }
    
    // Cleanup
    await subscription.cancel();
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
  /// After apply, verifies the new plan is queryable from Firestore before returning.
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
    
    // CRITICAL: Verify the new plan is actually queryable from Firestore
    // This ensures the query will return the new plan when stream subscribes
    print('[UserMealPlanService] [ApplyExplore] 🔍 Verifying new plan is queryable from Firestore...');
    final verifyAttempts = 3;
    final verifyDelay = const Duration(milliseconds: 200);
    UserMealPlan? verifiedPlan;
    
    for (int attempt = 1; attempt <= verifyAttempts; attempt++) {
      try {
        final activePlanStream = _repository.getActivePlan(userId);
        verifiedPlan = await activePlanStream.first.timeout(
          const Duration(milliseconds: 1000),
          onTimeout: () {
            print('[UserMealPlanService] [ApplyExplore] ⏱️ Verification attempt $attempt: Firestore query timeout');
            return null;
          },
        );
        
        if (verifiedPlan != null && verifiedPlan.id == plan.id) {
          print('[UserMealPlanService] [ApplyExplore] ✅ Verification attempt $attempt: New plan verified in Firestore (planId=${verifiedPlan.id})');
          break;
        } else if (verifiedPlan != null) {
          print('[UserMealPlanService] [ApplyExplore] ⚠️ Verification attempt $attempt: Got different plan (expected ${plan.id}, got ${verifiedPlan.id}), retrying...');
          verifiedPlan = null;
        } else {
          print('[UserMealPlanService] [ApplyExplore] ⚠️ Verification attempt $attempt: No active plan found, retrying...');
        }
      } catch (e) {
        print('[UserMealPlanService] [ApplyExplore] ⚠️ Verification attempt $attempt failed: $e, retrying...');
        verifiedPlan = null;
      }
      
      if (attempt < verifyAttempts) {
        await Future.delayed(verifyDelay);
      }
    }
    
    if (verifiedPlan == null || verifiedPlan.id != plan.id) {
      print('[UserMealPlanService] [ApplyExplore] ❌ verification failed: Could not verify new plan in Firestore after $verifyAttempts attempts');
      print('[UserMealPlanService] [ApplyExplore] ❌ Expected planId=${plan.id}, got planId=${verifiedPlan?.id ?? "null"}');
      throw StateError('Active plan verification failed: expected planId=${plan.id}, got planId=${verifiedPlan?.id ?? "null"}');
    }
    
    print('[UserMealPlanService] [ApplyExplore] ✅ verification passed: New plan verified in Firestore (planId=${verifiedPlan.id})');
    
    // CRITICAL: Clear cache again to ensure stream reads from Firestore first
    // This prevents stale cache from being emitted after provider invalidation
    await _cache.clearActivePlan(userId);
    print('[UserMealPlanService] [ApplyExplore] 🧹 Cleared cache again to force Firestore-first read');
    
    // Don't save to cache immediately - let the stream read from Firestore first (source of truth)
    // The stream will cache the Firestore result automatically
    // This ensures no stale cache is emitted after apply
    
    // Invalidate user's plans list cache
    await _cache.clearAllForUser(userId);
    
    print('[UserMealPlanService] [ApplyExplore] ✅ Apply complete: planId=${plan.id}');
    print('[UserMealPlanService] [ApplyExplore] 📡 Stream will read from Firestore (source of truth) and cache automatically');
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
    
    // CRITICAL: Verify the new plan is actually queryable from Firestore
    // This ensures the query will return the new plan when stream subscribes
    print('[UserMealPlanService] [ApplyCustom] 🔍 Step 3: Verifying new plan is queryable from Firestore...');
    final verifyAttempts = 3;
    final verifyDelay = const Duration(milliseconds: 200);
    UserMealPlan? verifiedPlan;
    
    for (int attempt = 1; attempt <= verifyAttempts; attempt++) {
      try {
        final activePlanStream = _repository.getActivePlan(userId);
        verifiedPlan = await activePlanStream.first.timeout(
          const Duration(milliseconds: 1000),
          onTimeout: () {
            print('[UserMealPlanService] [ApplyCustom] ⏱️ Verification attempt $attempt: Firestore query timeout');
            return null;
          },
        );
        
        if (verifiedPlan != null && verifiedPlan.id == plan.id) {
          print('[UserMealPlanService] [ApplyCustom] ✅ Verification attempt $attempt: New plan verified in Firestore (planId=${verifiedPlan.id})');
          break;
        } else if (verifiedPlan != null) {
          print('[UserMealPlanService] [ApplyCustom] ⚠️ Verification attempt $attempt: Got different plan (expected ${plan.id}, got ${verifiedPlan.id}), retrying...');
          verifiedPlan = null;
        } else {
          print('[UserMealPlanService] [ApplyCustom] ⚠️ Verification attempt $attempt: No active plan found, retrying...');
        }
      } catch (e) {
        print('[UserMealPlanService] [ApplyCustom] ⚠️ Verification attempt $attempt failed: $e, retrying...');
        verifiedPlan = null;
      }
      
      if (attempt < verifyAttempts) {
        await Future.delayed(verifyDelay);
      }
    }
    
    if (verifiedPlan == null || verifiedPlan.id != plan.id) {
      print('[UserMealPlanService] [ApplyCustom] ⚠️ WARNING: Could not verify new plan in Firestore after $verifyAttempts attempts');
      print('[UserMealPlanService] [ApplyCustom] ⚠️ This is not critical - stream will eventually emit the correct plan');
    }
    
    // CRITICAL: Clear cache again to ensure stream reads from Firestore first
    // This prevents stale cache from being emitted after provider invalidation
    print('[UserMealPlanService] [ApplyCustom] 🧹 Step 4: Clearing cache again to force Firestore-first read...');
    await _cache.clearActivePlan(userId);
    print('[UserMealPlanService] [ApplyCustom] ✅ Cleared cache again');
    
    // Don't save to cache immediately - let the stream read from Firestore first (source of truth)
    // The stream will cache the Firestore result automatically
    // This ensures no stale cache is emitted after apply
    
    // Invalidate user's plans list cache
    print('[UserMealPlanService] [ApplyCustom] 🧹 Step 5: Clearing user plans list cache...');
    await _cache.clearAllForUser(userId);
    print('[UserMealPlanService] [ApplyCustom] ✅ Cleared user plans list cache');
    
    print('[UserMealPlanService] [ApplyCustom] ✅ Apply complete: planId=${plan.id}, isActive=${plan.isActive}');
    print('[UserMealPlanService] [ApplyCustom] 📡 Stream will read from Firestore (source of truth) and cache automatically');
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
