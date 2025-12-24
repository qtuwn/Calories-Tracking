import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/domain/foods/food.dart';
import 'package:calories_app/shared/state/food_providers.dart' as food_providers;

/// Notifier for food search query
class FoodSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Provider for food search query
final foodSearchQueryProvider =
    NotifierProvider<FoodSearchQueryNotifier, String>(
      FoodSearchQueryNotifier.new,
    );

/// Provider for food search results
/// Uses the new cache-aware food search from food_providers
final foodSearchResultsProvider = StreamProvider.autoDispose<List<Food>>((ref) {
  final query = ref.watch(foodSearchQueryProvider);
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return Stream.value([]);
  }
  final searchAsync = ref.watch(food_providers.foodSearchProvider(trimmed));
  return searchAsync.when(
    data: (foods) => Stream.value(foods),
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

/// Notifier for selected food (local state for the bottom sheet)
class SelectedFoodNotifier extends Notifier<Food?> {
  @override
  Food? build() => null;

  void setFood(Food? food) {
    state = food;
  }

  void clear() {
    state = null;
  }
}

/// Provider for selected food
final selectedFoodProvider = NotifierProvider<SelectedFoodNotifier, Food?>(
  SelectedFoodNotifier.new,
);

