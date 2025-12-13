import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../domain/meal_plans/user_meal_plan.dart';
import '../../domain/meal_plans/user_meal_plan_cache.dart';

/// SharedPreferences-based implementation of UserMealPlanCache
class SharedPrefsUserMealPlanCache implements UserMealPlanCache {
  final SharedPreferences _prefs;

  SharedPrefsUserMealPlanCache(this._prefs);

  static const String _activePlanKeyPrefix = 'cached_user_meal_plan_active_';
  static const String _plansListKeyPrefix = 'cached_user_meal_plans_list_';
  static const String _planKeyPrefix = 'cached_user_meal_plan_';

  String _activePlanKey(String userId) => '$_activePlanKeyPrefix$userId';
  String _plansListKey(String userId) => '$_plansListKeyPrefix$userId';
  String _planKey(String userId, String planId) => '$_planKeyPrefix${userId}_$planId';

  @override
  Future<UserMealPlan?> loadActivePlan(String userId) async {
    try {
      final jsonStr = _prefs.getString(_activePlanKey(userId));
      if (jsonStr == null) {
        debugPrint('[SharedPrefsUserMealPlanCache] No cached active plan for userId=$userId');
        return null;
      }
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final plan = UserMealPlan.fromJson(json);
      debugPrint('[SharedPrefsUserMealPlanCache] ✅ Loaded cached active plan: ${plan.id}');
      return plan;
    } catch (e, st) {
      debugPrint('[SharedPrefsUserMealPlanCache] 🔥 Error loading active plan: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  @override
  Future<void> saveActivePlan(String userId, UserMealPlan? plan) async {
    try {
      if (plan == null) {
        await _prefs.remove(_activePlanKey(userId));
        debugPrint('[SharedPrefsUserMealPlanCache] Cleared cached active plan for userId=$userId');
        return;
      }
      final json = plan.toJson();
      final jsonStr = jsonEncode(json);
      await _prefs.setString(_activePlanKey(userId), jsonStr);
      debugPrint('[SharedPrefsUserMealPlanCache] ✅ Saved cached active plan: ${plan.id}');
    } catch (e, st) {
      debugPrint('[SharedPrefsUserMealPlanCache] 🔥 Error saving active plan: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Future<List<UserMealPlan>> loadPlansForUser(String userId) async {
    try {
      final jsonStr = _prefs.getString(_plansListKey(userId));
      if (jsonStr == null) {
        debugPrint('[SharedPrefsUserMealPlanCache] No cached plans list for userId=$userId');
        return [];
      }
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      final plans = jsonList
          .map((json) => UserMealPlan.fromJson(json as Map<String, dynamic>))
          .toList();
      debugPrint('[SharedPrefsUserMealPlanCache] ✅ Loaded ${plans.length} cached plans for userId=$userId');
      return plans;
    } catch (e, st) {
      debugPrint('[SharedPrefsUserMealPlanCache] 🔥 Error loading plans list: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  @override
  Future<void> savePlansForUser(String userId, List<UserMealPlan> plans) async {
    try {
      final jsonList = plans.map((plan) => plan.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);
      await _prefs.setString(_plansListKey(userId), jsonStr);
      debugPrint('[SharedPrefsUserMealPlanCache] ✅ Saved ${plans.length} cached plans for userId=$userId');
    } catch (e, st) {
      debugPrint('[SharedPrefsUserMealPlanCache] 🔥 Error saving plans list: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Future<UserMealPlan?> loadPlanById(String userId, String planId) async {
    try {
      final jsonStr = _prefs.getString(_planKey(userId, planId));
      if (jsonStr == null) {
        return null;
      }
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserMealPlan.fromJson(json);
    } catch (e, st) {
      debugPrint('[SharedPrefsUserMealPlanCache] 🔥 Error loading plan by ID: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  @override
  Future<void> savePlan(String userId, UserMealPlan plan) async {
    try {
      final json = plan.toJson();
      final jsonStr = jsonEncode(json);
      await _prefs.setString(_planKey(userId, plan.id), jsonStr);
      debugPrint('[SharedPrefsUserMealPlanCache] ✅ Saved cached plan: ${plan.id}');
    } catch (e, st) {
      debugPrint('[SharedPrefsUserMealPlanCache] 🔥 Error saving plan: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Future<void> clearAllForUser(String userId) async {
    try {
      await _prefs.remove(_activePlanKey(userId));
      await _prefs.remove(_plansListKey(userId));
      // Note: Individual plan keys are not cleared here for performance
      // They will be overwritten when new plans are saved
      debugPrint('[SharedPrefsUserMealPlanCache] ✅ Cleared all cached plans for userId=$userId');
    } catch (e, st) {
      debugPrint('[SharedPrefsUserMealPlanCache] 🔥 Error clearing cache: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Future<void> clearPlan(String userId, String planId) async {
    try {
      await _prefs.remove(_planKey(userId, planId));
      debugPrint('[SharedPrefsUserMealPlanCache] ✅ Cleared cached plan: $planId');
    } catch (e, st) {
      debugPrint('[SharedPrefsUserMealPlanCache] 🔥 Error clearing plan: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Future<void> clearActivePlan(String userId) async {
    try {
      await _prefs.remove(_activePlanKey(userId));
      debugPrint('[SharedPrefsUserMealPlanCache] ✅ Cleared cached active plan for userId=$userId');
    } catch (e, st) {
      debugPrint('[SharedPrefsUserMealPlanCache] 🔥 Error clearing active plan: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}

