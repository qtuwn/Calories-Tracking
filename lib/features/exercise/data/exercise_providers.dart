import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/features/exercise/data/exercise_repository.dart';

/// Provider for ExerciseRepository
final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository();
});

/// Notifier for exercise search query state
class ExerciseSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) {
    state = value;
  }

  void clear() {
    state = '';
  }
}

/// Provider for exercise search query
final exerciseSearchProvider =
    NotifierProvider<ExerciseSearchNotifier, String>(
  ExerciseSearchNotifier.new,
);

