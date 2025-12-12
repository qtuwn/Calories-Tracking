import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../domain/meal_plans/user_meal_plan.dart';
import '../../domain/meal_plans/user_meal_plan_cache.dart';
import '../../domain/meal_plans/user_meal_plan_repository.dart';
import '../../domain/meal_plans/user_meal_plan_service.dart';
import '../../data/meal_plans/firestore_user_meal_plan_repository.dart';
import '../../data/meal_plans/shared_prefs_user_meal_plan_cache.dart';
import 'profile_providers.dart'; // For sharedPreferencesProvider
import 'auth_providers.dart'; // For authStateProvider

/// Provider for UserMealPlanCache implementation
final userMealPlanCacheProvider = Provider<UserMealPlanCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) {
    debugPrint('[UserMealPlanCacheProvider] ⚠️ SharedPreferences not ready, returning dummy cache');
    return _DummyUserMealPlanCache(); // Fallback
  }
  return SharedPrefsUserMealPlanCache(prefs);
});

/// Provider for UserMealPlanRepository implementation
final userMealPlanRepositoryProvider = Provider<UserMealPlanRepository>((ref) {
  return FirestoreUserMealPlanRepository();
});

/// Provider for UserMealPlanService
final userMealPlanServiceProvider = Provider<UserMealPlanService>((ref) {
  final repository = ref.read(userMealPlanRepositoryProvider);
  final cache = ref.read(userMealPlanCacheProvider);
  return UserMealPlanService(repository, cache);
});

/// Stream provider for active meal plan, with cache-first logic.
/// 
/// This is the SINGLE SOURCE OF TRUTH for the active meal plan.
/// Uses keepAlive to maintain the stream across navigation, ensuring
/// consistent state even when switching tabs.
/// 
/// Usage:
/// ```dart
/// final activePlanAsync = ref.watch(activeMealPlanProvider);
/// activePlanAsync.when(
///   data: (plan) {
///     if (plan == null) return Text('No active plan');
///     return Text(plan.name);
///   },
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final activeMealPlanProvider = StreamProvider<UserMealPlan?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) {
    debugPrint('[ActiveMealPlanProvider] ⚠️ No user, returning empty stream');
    return const Stream.empty();
  }

  debugPrint('[ActiveMealPlanProvider] 🔵 Setting up active plan stream for uid=${user.uid}');
  final service = ref.watch(userMealPlanServiceProvider);
  return service.watchActivePlanWithCache(user.uid);
});

/// Future provider to load active plan once, prioritizing cache.
final activeMealPlanLoadOnceProvider = FutureProvider.autoDispose.family<UserMealPlan?, String>((ref, uid) {
  debugPrint('[ActiveMealPlanLoadOnceProvider] 🔵 Loading active plan once for uid=$uid');
  final service = ref.watch(userMealPlanServiceProvider);
  return service.loadActivePlanOnce(uid);
});

/// Stream provider for all user meal plans, with cache-first logic.
/// 
/// Usage:
/// ```dart
/// final plansAsync = ref.watch(userMealPlansProvider(uid));
/// ```
final userMealPlansProvider = StreamProvider.autoDispose
    .family<List<UserMealPlan>, String>((ref, uid) {
  debugPrint('[UserMealPlansProvider] 🔵 Setting up plans stream for uid=$uid');
  final service = ref.watch(userMealPlanServiceProvider);
  return service.watchPlansForUserWithCache(uid);
});

/// Future provider to load all plans once, prioritizing cache.
final userMealPlansLoadOnceProvider = FutureProvider.autoDispose
    .family<List<UserMealPlan>, String>((ref, uid) {
  debugPrint('[UserMealPlansLoadOnceProvider] 🔵 Loading plans once for uid=$uid');
  final service = ref.watch(userMealPlanServiceProvider);
  return service.loadPlansForUserOnce(uid);
});

/// Dummy UserMealPlanCache implementation for when SharedPreferences is not ready
/// 
/// This is a no-op implementation that silently returns empty/null values.
/// Logging is removed to prevent console spam during normal operation.
class _DummyUserMealPlanCache implements UserMealPlanCache {
  @override
  Future<void> clearAllForUser(String userId) async {
    // Silent no-op
  }

  @override
  Future<void> clearPlan(String userId, String planId) async {
    // Silent no-op
  }

  @override
  Future<void> clearActivePlan(String userId) async {
    // Silent no-op
  }

  @override
  Future<UserMealPlan?> loadActivePlan(String userId) async {
    // Silent no-op
    return null;
  }

  @override
  Future<UserMealPlan?> loadPlanById(String userId, String planId) async {
    // Silent no-op
    return null;
  }

  @override
  Future<List<UserMealPlan>> loadPlansForUser(String userId) async {
    // Silent no-op
    return [];
  }

  @override
  Future<void> saveActivePlan(String userId, UserMealPlan? plan) async {
    // Silent no-op
  }

  @override
  Future<void> savePlan(String userId, UserMealPlan plan) async {
    // Silent no-op
  }

  @override
  Future<void> savePlansForUser(String userId, List<UserMealPlan> plans) async {
    // Silent no-op
  }
}

