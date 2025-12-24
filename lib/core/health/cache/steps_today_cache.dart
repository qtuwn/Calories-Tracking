import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple cache for today's steps with TTL (10 minutes).
/// 
/// Keys:
/// - stepsToday_value: int (step count)
/// - stepsToday_updatedAt: String (ISO8601 timestamp)
class StepsTodayCache {
  final SharedPreferences _prefs;
  static const String _valueKey = 'stepsToday_value';
  static const String _updatedAtKey = 'stepsToday_updatedAt';
  static const Duration _ttl = Duration(minutes: 10);

  StepsTodayCache(this._prefs);

  /// Load cached steps if not expired.
  /// Returns null if cache is missing or expired.
  int? loadCachedSteps() {
    try {
      final value = _prefs.getInt(_valueKey);
      final updatedAtStr = _prefs.getString(_updatedAtKey);
      
      if (value == null || updatedAtStr == null) {
        if (kDebugMode) {
          debugPrint('[StepsTodayCache] No cache found');
        }
        return null;
      }

      final updatedAt = DateTime.parse(updatedAtStr);
      final now = DateTime.now();
      
      if (now.difference(updatedAt) > _ttl) {
        if (kDebugMode) {
          debugPrint('[StepsTodayCache] Cache expired (age: ${now.difference(updatedAt).inMinutes} min)');
        }
        clearCache();
        return null;
      }

      if (kDebugMode) {
        debugPrint('[StepsTodayCache] ✅ Loaded cached steps: $value (age: ${now.difference(updatedAt).inSeconds}s)');
      }
      return value;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[StepsTodayCache] ❌ Error loading cache: $e');
        debugPrint('[StepsTodayCache] Stack trace: $stackTrace');
      }
      clearCache();
      return null;
    }
  }

  /// Save steps to cache with current timestamp.
  Future<void> saveSteps(int steps) async {
    try {
      await _prefs.setInt(_valueKey, steps);
      await _prefs.setString(_updatedAtKey, DateTime.now().toIso8601String());
      if (kDebugMode) {
        debugPrint('[StepsTodayCache] ✅ Saved steps to cache: $steps');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[StepsTodayCache] ❌ Error saving cache: $e');
        debugPrint('[StepsTodayCache] Stack trace: $stackTrace');
      }
    }
  }

  /// Clear cache.
  Future<void> clearCache() async {
    await _prefs.remove(_valueKey);
    await _prefs.remove(_updatedAtKey);
    if (kDebugMode) {
      debugPrint('[StepsTodayCache] 🗑️ Cache cleared');
    }
  }
}

