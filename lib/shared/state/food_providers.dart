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
final foodCacheProvider = Provider<FoodCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) {
    debugPrint('[FoodCacheProvider] ⚠️ SharedPreferences not ready, returning dummy cache');
    return _DummyFoodCache(); // Fallback
  }
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

/// Dummy FoodCache implementation for when SharedPreferences is not ready
class _DummyFoodCache implements FoodCache {
  @override
  Future<void> clear() async {
    debugPrint('[DummyFoodCache] clear called (no-op)');
  }

  @override
  Future<List<Food>> loadAll() async {
    debugPrint('[DummyFoodCache] loadAll called (no-op)');
    return [];
  }

  @override
  Future<void> saveAll(List<Food> foods) async {
    debugPrint('[DummyFoodCache] saveAll called (no-op)');
  }
}

