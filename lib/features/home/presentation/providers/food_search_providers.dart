import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/features/foods/data/food_model.dart';
import 'package:calories_app/features/foods/data/food_providers.dart';

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
final foodSearchResultsProvider = StreamProvider.autoDispose<List<Food>>((ref) {
  final query = ref.watch(foodSearchQueryProvider);
  final repo = ref.watch(foodRepositoryProvider);

  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return const Stream.empty();
  }

  return repo.searchFoods(trimmed);
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

