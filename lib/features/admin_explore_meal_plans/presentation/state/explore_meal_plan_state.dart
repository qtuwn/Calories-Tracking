import '../../../../domain/meal_plans/explore_meal_plan.dart';
import '../../../../domain/meal_plans/meal_plan_goal_type.dart';

/// State for meal plan list page
class MealPlanListState {
  final List<ExploreMealPlan> plans;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final MealPlanGoalType? selectedGoalType;
  final int? minKcal;
  final int? maxKcal;
  final List<String> selectedTags;
  final bool showUnpublished;

  const MealPlanListState({
    this.plans = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedGoalType,
    this.minKcal,
    this.maxKcal,
    this.selectedTags = const [],
    this.showUnpublished = false,
  });

  MealPlanListState copyWith({
    List<ExploreMealPlan>? plans,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    MealPlanGoalType? selectedGoalType,
    int? minKcal,
    int? maxKcal,
    List<String>? selectedTags,
    bool? showUnpublished,
  }) {
    return MealPlanListState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedGoalType: selectedGoalType ?? this.selectedGoalType,
      minKcal: minKcal ?? this.minKcal,
      maxKcal: maxKcal ?? this.maxKcal,
      selectedTags: selectedTags ?? this.selectedTags,
      showUnpublished: showUnpublished ?? this.showUnpublished,
    );
  }
}

/// State for meal plan form page
class MealPlanFormState {
  final ExploreMealPlan? plan;
  final bool isLoading;
  final String? errorMessage;
  final bool isEditing;

  const MealPlanFormState({
    this.plan,
    this.isLoading = false,
    this.errorMessage,
    this.isEditing = false,
  });

  MealPlanFormState copyWith({
    ExploreMealPlan? plan,
    bool? isLoading,
    String? errorMessage,
    bool? isEditing,
  }) {
    return MealPlanFormState(
      plan: plan ?? this.plan,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isEditing: isEditing ?? this.isEditing,
    );
  }
}

