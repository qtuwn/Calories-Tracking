import 'dart:convert';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/foods/food.dart';
import '../../domain/foods/food_cache.dart';

/// SharedPreferences-based implementation of FoodCache.
/// 
/// Stores and retrieves Food objects as JSON strings in SharedPreferences.
class SharedPrefsFoodCache implements FoodCache {
  final SharedPreferences _prefs;
  static const _foodsKey = 'cached_foods';

  SharedPrefsFoodCache(this._prefs);

  @override
  Future<List<Food>> loadAll() async {
    try {
      final jsonString = _prefs.getString(_foodsKey);
      if (jsonString != null) {
        final jsonList = json.decode(jsonString) as List<dynamic>;
        final foods = jsonList
            .map((json) => Food.fromJson(json as Map<String, dynamic>))
            .toList();
        debugPrint('[SharedPrefsFoodCache] ✅ Loaded ${foods.length} foods from cache');
        return foods;
      }
      debugPrint('[SharedPrefsFoodCache] ℹ️ No foods found in cache');
      return [];
    } catch (e, st) {
      debugPrint('[SharedPrefsFoodCache] 🔥 Error loading foods from cache: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  @override
  Future<void> saveAll(List<Food> foods) async {
    try {
      final jsonList = foods.map((food) => food.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _prefs.setString(_foodsKey, jsonString);
      debugPrint('[SharedPrefsFoodCache] ✅ Saved ${foods.length} foods to cache');
    } catch (e, st) {
      debugPrint('[SharedPrefsFoodCache] 🔥 Error saving foods to cache: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _prefs.remove(_foodsKey);
      debugPrint('[SharedPrefsFoodCache] ✅ Cleared foods from cache');
    } catch (e, st) {
      debugPrint('[SharedPrefsFoodCache] 🔥 Error clearing foods from cache: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}

