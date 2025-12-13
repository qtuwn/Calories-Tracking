import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../domain/meal_plans/explore_meal_plan.dart';
import '../../domain/meal_plans/explore_meal_plan_cache.dart';

/// SharedPreferences-based implementation of ExploreMealPlanCache
class SharedPrefsExploreMealPlanCache implements ExploreMealPlanCache {
  final SharedPreferences _prefs;

  SharedPrefsExploreMealPlanCache(this._prefs);

  static const String _publishedPlansKey = 'cached_explore_meal_plans_published';
  static const String _planKeyPrefix = 'cached_explore_meal_plan_';

  String _planKey(String planId) => '$_planKeyPrefix$planId';

  @override
  Future<List<ExploreMealPlan>> loadPublishedPlans() async {
    try {
      final jsonStr = _prefs.getString(_publishedPlansKey);
      if (jsonStr == null) {
        debugPrint('[SharedPrefsExploreMealPlanCache] No cached published plans');
        return [];
      }
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      final plans = jsonList
          .map((json) => ExploreMealPlan.fromJson(json as Map<String, dynamic>))
          .toList();
      debugPrint('[SharedPrefsExploreMealPlanCache] ✅ Loaded ${plans.length} cached published plans');
      return plans;
    } catch (e, st) {
      debugPrint('[SharedPrefsExploreMealPlanCache] 🔥 Error loading published plans: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  @override
  Future<void> savePublishedPlans(List<ExploreMealPlan> plans) async {
    try {
      final jsonList = plans.map((plan) => plan.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);
      await _prefs.setString(_publishedPlansKey, jsonStr);
      debugPrint('[SharedPrefsExploreMealPlanCache] ✅ Saved ${plans.length} cached published plans');
    } catch (e, st) {
      debugPrint('[SharedPrefsExploreMealPlanCache] 🔥 Error saving published plans: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Future<ExploreMealPlan?> loadPlanById(String planId) async {
    try {
      final jsonStr = _prefs.getString(_planKey(planId));
      if (jsonStr == null) {
        return null;
      }
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ExploreMealPlan.fromJson(json);
    } catch (e, st) {
      debugPrint('[SharedPrefsExploreMealPlanCache] 🔥 Error loading plan by ID: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  @override
  Future<void> savePlan(ExploreMealPlan plan) async {
    try {
      final json = plan.toJson();
      final jsonStr = jsonEncode(json);
      await _prefs.setString(_planKey(plan.id), jsonStr);
      debugPrint('[SharedPrefsExploreMealPlanCache] ✅ Saved cached plan: ${plan.id}');
    } catch (e, st) {
      debugPrint('[SharedPrefsExploreMealPlanCache] 🔥 Error saving plan: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await _prefs.remove(_publishedPlansKey);
      // Note: Individual plan keys are not cleared here for performance
      debugPrint('[SharedPrefsExploreMealPlanCache] ✅ Cleared all cached plans');
    } catch (e, st) {
      debugPrint('[SharedPrefsExploreMealPlanCache] 🔥 Error clearing cache: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Future<void> clearPlan(String planId) async {
    try {
      await _prefs.remove(_planKey(planId));
      debugPrint('[SharedPrefsExploreMealPlanCache] ✅ Cleared cached plan: $planId');
    } catch (e, st) {
      debugPrint('[SharedPrefsExploreMealPlanCache] 🔥 Error clearing plan: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}

