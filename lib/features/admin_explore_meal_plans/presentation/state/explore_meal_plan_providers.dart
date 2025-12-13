import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/meal_plans/explore_meal_plan.dart';
import '../../../../domain/meal_plans/meal_plan_goal_type.dart';
import '../../../../shared/state/explore_meal_plan_providers.dart' as shared_providers;

/// Provider for all meal plans including unpublished (admin use)
/// Uses cache-first architecture from shared providers
final allMealPlansProvider = shared_providers.allMealPlansProvider;

/// Provider for meal plan search with filters
/// Uses cache-first architecture from shared providers
final mealPlanSearchProvider = StreamProvider.autoDispose
    .family<List<ExploreMealPlan>, ({
  String? query,
  MealPlanGoalType? goalType,
  int? minKcal,
  int? maxKcal,
  List<String>? tags,
})>((ref, args) {
  final repository = ref.watch(shared_providers.exploreMealPlanRepositoryProvider);
  return repository.searchPlans(
    query: args.query,
    goalType: args.goalType,
    minKcal: args.minKcal,
    maxKcal: args.maxKcal,
    tags: args.tags,
  );
});

/// Provider for a single meal plan by ID (cache-first)
/// Uses cache-first architecture from shared providers
final mealPlanByIdProvider = shared_providers.exploreMealPlanByIdProvider;

/// Provider for meal plan days
final mealPlanDaysProvider =
    StreamProvider.autoDispose.family<List<MealPlanDay>, String>((ref, planId) {
  final repository = ref.watch(shared_providers.exploreMealPlanRepositoryProvider);
  return repository.getPlanDays(planId);
});

/// Provider for day meals
final dayMealsProvider = StreamProvider.autoDispose
    .family<List<MealSlot>, ({String planId, int dayIndex})>((ref, args) {
  final repository = ref.watch(shared_providers.exploreMealPlanRepositoryProvider);
  return repository.getDayMeals(args.planId, args.dayIndex);
});

