import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/domain/meal_plans/explore_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';
import 'package:calories_app/shared/state/explore_meal_plan_providers.dart' as explore_shared;

/// State for explore meal plan controller
class ExploreMealPlanState {
  final List<ExploreMealPlan> templates;
  final MealPlanGoalType? filterGoal;
  final bool isLoading;
  final String? errorMessage;

  const ExploreMealPlanState({
    this.templates = const [],
    this.filterGoal,
    this.isLoading = false,
    this.errorMessage,
  });

  ExploreMealPlanState copyWith({
    List<ExploreMealPlan>? templates,
    MealPlanGoalType? filterGoal,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ExploreMealPlanState(
      templates: templates ?? this.templates,
      filterGoal: filterGoal ?? this.filterGoal,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller for managing explore meal plan templates
/// 
/// Responsibilities:
/// - Load and expose all explore templates
/// - Manage filtering by goal type
/// - Provide refresh operations
/// 
/// Dependencies:
/// - ExploreMealPlanRepository (domain interface)
/// 
/// Uses Notifier pattern with pure build() to avoid circular dependencies.
/// 
/// IMPORTANT: build() is pure and does not read its own state or call async methods.
/// All loading is triggered externally (e.g., from page initState).
class ExploreMealPlanController extends Notifier<ExploreMealPlanState> {
  StreamSubscription<List<ExploreMealPlan>>? _templatesSubscription;
  MealPlanGoalType? _currentFilterGoal; // Store filter separately to avoid reading state during init

  @override
  ExploreMealPlanState build() {
    // Only read independent providers - never read own provider or state
    _currentFilterGoal = null;
    
    ref.onDispose(() {
      _templatesSubscription?.cancel();
    });
    
    // Return initial state only - no side effects in build()
    // Loading will be triggered from the page's initState
    return const ExploreMealPlanState();
  }

  /// Load all explore templates
  /// 
  /// If a goal filter is set, only templates matching that goal are loaded.
  /// 
  /// IMPORTANT: This method only reads repository providers, never its own provider.
  Future<void> loadTemplates() async {
    if (!ref.mounted) return;
    
    try {
      // Use stored filter goal instead of reading state to avoid circular dependency
      final filterGoal = _currentFilterGoal ?? state.filterGoal;
      state = state.copyWith(isLoading: true, errorMessage: null);
      
      // Use shared repository provider
      final repository = ref.read(explore_shared.exploreMealPlanRepositoryProvider);
      
      // Cancel previous subscription if any
      await _templatesSubscription?.cancel();
      
      if (!ref.mounted) return;
      
      // Subscribe to templates stream based on stored filter
      Stream<List<ExploreMealPlan>> stream;
      if (filterGoal != null) {
        stream = repository.searchPlans(goalType: filterGoal);
      } else {
        stream = repository.watchAllPlans();
      }
      
      _templatesSubscription = stream.listen(
        (templates) {
          if (!ref.mounted) return;
          debugPrint('[ExploreMealPlanController] 📊 Loaded ${templates.length} templates');
          state = state.copyWith(
            templates: templates,
            isLoading: false,
            clearErrorMessage: true,
          );
        },
        onError: (error, stackTrace) {
          if (!ref.mounted) return;
          debugPrint('[ExploreMealPlanController] 🔥 Error loading templates: $error');
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to load templates: ${error.toString()}',
          );
        },
      );
    } catch (e) {
      if (!ref.mounted) return;
      debugPrint('[ExploreMealPlanController] 🔥 Error in loadTemplates: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load templates: ${e.toString()}',
      );
    }
  }

  /// Refresh templates (reload from repository)
  Future<void> refresh() async {
    await loadTemplates();
  }

  /// Set goal filter and reload templates
  Future<void> setGoalFilter(MealPlanGoalType? goal) async {
    if (!ref.mounted) return;
    
    // Store filter in both state and local field to avoid reading state during load
    _currentFilterGoal = goal;
    state = state.copyWith(filterGoal: goal);
    await loadTemplates();
  }
}

/// Provider for explore meal plan controller
final exploreMealPlanControllerProvider =
    NotifierProvider.autoDispose<ExploreMealPlanController, ExploreMealPlanState>(
  ExploreMealPlanController.new,
);

