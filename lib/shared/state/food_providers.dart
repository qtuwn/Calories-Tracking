import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../domain/foods/food.dart';
import '../../domain/foods/food_cache.dart';
import '../../domain/foods/food_repository.dart';
import '../../domain/foods/food_service.dart';
import '../../data/foods/firestore_food_repository.dart';
import '../../data/foods/shared_prefs_food_cache.dart';
import 'profile_providers.dart'; // For sharedPreferencesProvider

/// Provider for FoodCache implementation
/// 
/// SharedPreferences is guaranteed to be available since it's preloaded in main.dart
/// and provided via ProviderScope.overrides. No Dummy cache needed.
final foodCacheProvider = Provider<FoodCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPrefsFoodCache(prefs);
});

/// Provider for FoodRepository implementation
final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FirestoreFoodRepository();
});

/// Provider for FoodService
final foodServiceProvider = Provider<FoodService>((ref) {
  final repository = ref.read(foodRepositoryProvider);
  final cache = ref.read(foodCacheProvider);
  return FoodService(repository, cache);
});

/// Stream provider for all foods, with cache-first logic.
/// This is the primary provider for UI to consume the food catalog.
final allFoodsProvider = StreamProvider<List<Food>>((ref) {
  debugPrint('[AllFoodsProvider] 🔵 Setting up foods stream');
  final service = ref.watch(foodServiceProvider);
  return service.watchAllWithCache();
});

/// Future provider to load all foods once, prioritizing cache.
final foodsLoadOnceProvider = FutureProvider<List<Food>>((ref) {
  debugPrint('[FoodsLoadOnceProvider] 🔵 Loading all foods once');
  final service = ref.watch(foodServiceProvider);
  return service.loadAllOnce();
});

/// Stream provider for food search, with cache support.
final foodSearchProvider = StreamProvider.family<List<Food>, String>((ref, query) {
  debugPrint('[FoodSearchProvider] 🔵 Setting up food search stream: query="$query"');
  final service = ref.watch(foodServiceProvider);
  return service.searchWithCache(query);
});

/// Future provider for getting a single food by ID, with memoization.
/// 
/// This provider caches results per foodId to prevent repeated lookups
/// during a single page session. Use this instead of calling repository.getById directly.
/// 
/// Example:
/// ```dart
/// final foodAsync = ref.watch(foodByIdProvider('food-123'));
/// foodAsync.when(
///   data: (food) => Text(food?.name ?? 'Unknown'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => Text('Error: $e'),
/// );
/// ```
final foodByIdProvider = FutureProvider.autoDispose.family<Food?, String>((ref, foodId) {
  if (foodId.isEmpty) {
    return Future.value(null);
  }
  
  final repository = ref.read(foodRepositoryProvider);
  return repository.getById(foodId);
});


