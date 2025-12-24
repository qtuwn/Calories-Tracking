import 'dart:convert';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/diary/diary_cache.dart';
import '../../data/firebase/date_utils.dart';

/// SharedPreferences-based implementation of DiaryCache.
/// 
/// Stores and retrieves DiaryEntry objects as JSON strings in SharedPreferences.
/// Key format: `cached_diary_<uid>_<YYYY-MM-DD>`
class SharedPrefsDiaryCache implements DiaryCache {
  final SharedPreferences _prefs;
  static const String _keyPrefix = 'cached_diary_';

  SharedPrefsDiaryCache(this._prefs);

  /// Generate cache key for a specific user and date
  String _getKey(String uid, DateTime day) {
    final dateString = DateUtils.normalizeToIsoString(day);
    return '$_keyPrefix${uid}_$dateString';
  }

  @override
  Future<List<DiaryEntry>> loadEntriesForDay(String uid, DateTime day) async {
    try {
      final key = _getKey(uid, day);
      final jsonString = _prefs.getString(key);
      
      if (jsonString == null) {
        debugPrint('[SharedPrefsDiaryCache] ℹ️ No cached entries for uid=$uid, day=$day');
        return [];
      }

      final jsonList = json.decode(jsonString) as List<dynamic>;
      final entries = jsonList
          .map((json) => DiaryEntry.fromJson(json as Map<String, dynamic>))
          .toList();
      
      debugPrint('[SharedPrefsDiaryCache] ✅ Loaded ${entries.length} entries from cache for uid=$uid, day=$day');
      return entries;
    } catch (e, st) {
      debugPrint('[SharedPrefsDiaryCache] 🔥 Error loading entries from cache for uid=$uid, day=$day: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  @override
  Future<void> saveEntriesForDay(String uid, DateTime day, List<DiaryEntry> entries) async {
    try {
      final key = _getKey(uid, day);
      final jsonList = entries.map((entry) => entry.toJson()).toList();
      final jsonString = json.encode(jsonList);
      
      await _prefs.setString(key, jsonString);
      
      debugPrint('[SharedPrefsDiaryCache] ✅ Saved ${entries.length} entries to cache for uid=$uid, day=$day');
    } catch (e, st) {
      debugPrint('[SharedPrefsDiaryCache] 🔥 Error saving entries to cache for uid=$uid, day=$day: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Future<void> clearEntriesForDay(String uid, DateTime day) async {
    try {
      final key = _getKey(uid, day);
      await _prefs.remove(key);
      
      debugPrint('[SharedPrefsDiaryCache] ✅ Cleared cached entries for uid=$uid, day=$day');
    } catch (e, st) {
      debugPrint('[SharedPrefsDiaryCache] 🔥 Error clearing cached entries for uid=$uid, day=$day: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Future<void> clearAllForUser(String uid) async {
    try {
      final keys = _prefs.getKeys().where((key) => key.startsWith('$_keyPrefix${uid}_'));
      for (final key in keys) {
        await _prefs.remove(key);
      }
      
      debugPrint('[SharedPrefsDiaryCache] ✅ Cleared all cached entries for uid=$uid');
    } catch (e, st) {
      debugPrint('[SharedPrefsDiaryCache] 🔥 Error clearing all cached entries for uid=$uid: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}

