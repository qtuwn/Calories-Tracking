import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../domain/profile/profile.dart';
import '../../domain/profile/profile_cache.dart';

/// SharedPreferences implementation of ProfileCache
/// 
/// Stores profiles as JSON strings in SharedPreferences.
/// Key pattern: cached_profile_{uid}
class SharedPrefsProfileCache implements ProfileCache {
  final SharedPreferences _prefs;
  static const String _keyPrefix = 'cached_profile_';

  SharedPrefsProfileCache(this._prefs);

  @override
  Future<Profile?> loadProfile(String uid) async {
    try {
      final key = '$_keyPrefix$uid';
      final jsonString = _prefs.getString(key);

      if (jsonString == null) {
        debugPrint('[SharedPrefsProfileCache] ℹ️ No cached profile for uid=$uid');
        return null;
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final profile = Profile.fromJson(json);

      debugPrint('[SharedPrefsProfileCache] ✅ Loaded cached profile for uid=$uid');
      return profile;
    } catch (e, stackTrace) {
      debugPrint('[SharedPrefsProfileCache] 🔥 Error loading cached profile for uid=$uid: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<void> saveProfile(String uid, Profile profile) async {
    try {
      final key = '$_keyPrefix$uid';
      final jsonString = jsonEncode(profile.toJson());

      await _prefs.setString(key, jsonString);

      debugPrint('[SharedPrefsProfileCache] ✅ Saved profile to cache for uid=$uid');
    } catch (e, stackTrace) {
      debugPrint('[SharedPrefsProfileCache] 🔥 Error saving profile to cache for uid=$uid: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> clearProfile(String uid) async {
    try {
      final key = '$_keyPrefix$uid';
      await _prefs.remove(key);

      debugPrint('[SharedPrefsProfileCache] ✅ Cleared cached profile for uid=$uid');
    } catch (e, stackTrace) {
      debugPrint('[SharedPrefsProfileCache] 🔥 Error clearing cached profile for uid=$uid: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final keys = _prefs.getKeys().where((key) => key.startsWith(_keyPrefix));
      for (final key in keys) {
        await _prefs.remove(key);
      }

      debugPrint('[SharedPrefsProfileCache] ✅ Cleared all cached profiles');
    } catch (e, stackTrace) {
      debugPrint('[SharedPrefsProfileCache] 🔥 Error clearing all cached profiles: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

