import 'package:calories_app/domain/meal_plans/user_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_cache.dart';

/// Fake cache for testing UserMealPlanService
/// 
/// In-memory cache that tracks save/load operations for verification.
class FakeUserMealPlanCache implements UserMealPlanCache {
  final Map<String, UserMealPlan?> _activePlans = {};
  final Map<String, List<UserMealPlan>> _userPlans = {};
  final Map<String, UserMealPlan> _plansById = {};
  
  int _saveActivePlanCallCount = 0;
  int _loadActivePlanCallCount = 0;
  int _clearActivePlanCallCount = 0;
  
  /// Counter for how many times saveActivePlan was called
  int get saveActivePlanCallCount => _saveActivePlanCallCount;
  
  /// Counter for how many times loadActivePlan was called
  int get loadActivePlanCallCount => _loadActivePlanCallCount;
  
  /// Counter for how many times clearActivePlan was called
  int get clearActivePlanCallCount => _clearActivePlanCallCount;
  
  /// Get the cached active plan for a user (for verification)
  UserMealPlan? getCachedActivePlan(String userId) => _activePlans[userId];
  
  /// Clear all cached data (for test cleanup)
  void clear() {
    _activePlans.clear();
    _userPlans.clear();
    _plansById.clear();
    _saveActivePlanCallCount = 0;
    _loadActivePlanCallCount = 0;
    _clearActivePlanCallCount = 0;
  }

  @override
  Future<UserMealPlan?> loadActivePlan(String userId) async {
    _loadActivePlanCallCount++;
    return _activePlans[userId];
  }

  @override
  Future<void> saveActivePlan(String userId, UserMealPlan? plan) async {
    _saveActivePlanCallCount++;
    _activePlans[userId] = plan;
  }

  @override
  Future<List<UserMealPlan>> loadPlansForUser(String userId) async {
    return _userPlans[userId] ?? [];
  }

  @override
  Future<void> savePlansForUser(String userId, List<UserMealPlan> plans) async {
    _userPlans[userId] = plans;
  }

  @override
  Future<UserMealPlan?> loadPlanById(String userId, String planId) async {
    return _plansById[planId];
  }

  @override
  Future<void> savePlan(String userId, UserMealPlan plan) async {
    _plansById[plan.id] = plan;
  }

  @override
  Future<void> clearAllForUser(String userId) async {
    _activePlans.remove(userId);
    _userPlans.remove(userId);
    // Note: _plansById is keyed by planId, not userId, so we don't clear it here
  }

  @override
  Future<void> clearPlan(String userId, String planId) async {
    _plansById.remove(planId);
  }

  @override
  Future<void> clearActivePlan(String userId) async {
    _clearActivePlanCallCount++;
    _activePlans.remove(userId);
  }
}

