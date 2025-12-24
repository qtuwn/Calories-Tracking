import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_providers.dart';

/// Provider for onboarding completion cache
/// 
/// This provides fast, synchronous access to onboarding status
/// without waiting for Firestore queries.
final onboardingCacheProvider = Provider<OnboardingCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingCache(prefs);
});

/// Cache for onboarding completion status
/// 
/// Stores onboardingCompleted flag in SharedPreferences for fast access.
/// This allows ProfileGate to render HomeScreen immediately without waiting
/// for Firestore queries.
class OnboardingCache {
  final SharedPreferences _prefs;
  static const String _keyPrefix = 'onboardingCompleted_';

  OnboardingCache(this._prefs);

  /// Get cached onboarding status for a user
  /// Returns null if not cached
  bool? getCachedStatus(String uid) {
    final key = '$_keyPrefix$uid';
    final cached = _prefs.getBool(key);
    if (kDebugMode && cached != null) {
      debugPrint('[OnboardingCache] ✅ Loaded cached status for $uid: $cached');
    }
    return cached;
  }

  /// Set cached onboarding status for a user
  Future<void> setCachedStatus(String uid, bool completed) async {
    final key = '$_keyPrefix$uid';
    await _prefs.setBool(key, completed);
    if (kDebugMode) {
      debugPrint('[OnboardingCache] 💾 Cached status for $uid: $completed');
    }
  }

  /// Clear cached status for a user (e.g., on logout)
  Future<void> clearCachedStatus(String uid) async {
    final key = '$_keyPrefix$uid';
    await _prefs.remove(key);
    if (kDebugMode) {
      debugPrint('[OnboardingCache] 🗑️ Cleared cached status for $uid');
    }
  }
}

