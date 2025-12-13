import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../domain/meal_plans/explore_meal_plan.dart';
import '../../domain/meal_plans/explore_meal_plan_cache.dart';
import '../../domain/meal_plans/explore_meal_plan_repository.dart';
import '../../domain/meal_plans/explore_meal_plan_service.dart';
import '../../data/meal_plans/firestore_explore_meal_plan_repository.dart';
import '../../data/meal_plans/shared_prefs_explore_meal_plan_cache.dart';
import 'profile_providers.dart'; // For sharedPreferencesProvider

/// Provider for ExploreMealPlanCache implementation
/// 
/// SharedPreferences is guaranteed to be available since it's preloaded in main.dart
/// and provided via ProviderScope.overrides. No null return needed.
final exploreMealPlanCacheProvider = Provider<ExploreMealPlanCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPrefsExploreMealPlanCache(prefs);
});

/// Provider for ExploreMealPlanRepository implementation
final exploreMealPlanRepositoryProvider = Provider<ExploreMealPlanRepository>((ref) {
  return FirestoreExploreMealPlanRepository();
});

/// Provider for ExploreMealPlanService
/// 
/// Cache is guaranteed to be non-null since SharedPreferences is preloaded in main.dart
final exploreMealPlanServiceProvider = Provider<ExploreMealPlanService>((ref) {
  final repository = ref.read(exploreMealPlanRepositoryProvider);
  final cache = ref.read(exploreMealPlanCacheProvider);
  return ExploreMealPlanService(repository, cache); // cache is now always non-null
});

/// Stream provider for published meal plans, with cache-first logic.
/// 
/// This is the primary provider for UI to consume published meal plans.
/// 
/// Usage:
/// ```dart
/// final plansAsync = ref.watch(publishedMealPlansProvider);
/// plansAsync.when(
///   data: (plans) => ListView(...),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final publishedMealPlansProvider = StreamProvider.autoDispose<List<ExploreMealPlan>>((ref) {
  debugPrint('[PublishedMealPlansProvider] 🔵 Setting up published plans stream');
  final service = ref.watch(exploreMealPlanServiceProvider);
  return service.watchPublishedPlansWithCache();
});

/// Future provider to load published plans once, prioritizing cache.
final publishedMealPlansLoadOnceProvider = FutureProvider.autoDispose<List<ExploreMealPlan>>((ref) {
  debugPrint('[PublishedMealPlansLoadOnceProvider] 🔵 Loading published plans once');
  final service = ref.watch(exploreMealPlanServiceProvider);
  return service.loadPublishedPlansOnce();
});

/// Stream provider for a specific meal plan by ID, with cache-first logic.
final exploreMealPlanByIdProvider = StreamProvider.autoDispose
    .family<ExploreMealPlan?, String>((ref, planId) {
  debugPrint('[ExploreMealPlanByIdProvider] 🔵 Setting up plan stream for id=$planId');
  final service = ref.watch(exploreMealPlanServiceProvider);
  return service.watchPlanByIdWithCache(planId);
});

/// Future provider to load a plan by ID once, prioritizing cache.
final exploreMealPlanLoadOnceProvider = FutureProvider.autoDispose
    .family<ExploreMealPlan?, String>((ref, planId) {
  debugPrint('[ExploreMealPlanLoadOnceProvider] 🔵 Loading plan once for id=$planId');
  final service = ref.watch(exploreMealPlanServiceProvider);
  return service.loadPlanByIdOnce(planId);
});

/// Stream provider for all meal plans (admin), with cache-first logic.
final allMealPlansProvider = StreamProvider.autoDispose<List<ExploreMealPlan>>((ref) {
  debugPrint('[AllMealPlansProvider] 🔵 Setting up all plans stream (admin)');
  final repository = ref.watch(exploreMealPlanRepositoryProvider);
  return repository.watchAllPlans();
});

/// Stream provider for featured meal plans.
final featuredMealPlansProvider = StreamProvider.autoDispose<List<ExploreMealPlan>>((ref) {
  debugPrint('[FeaturedMealPlansProvider] 🔵 Setting up featured plans stream');
  final repository = ref.watch(exploreMealPlanRepositoryProvider);
  return repository.getFeaturedPlans();
});

