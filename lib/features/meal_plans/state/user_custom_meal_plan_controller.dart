import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_service.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart'; // For MealItem
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';
import 'package:calories_app/features/meal_plans/domain/services/meal_plan_validation_service.dart';
import 'package:calories_app/shared/state/user_meal_plan_providers.dart' as user_meal_plan_providers;
import 'package:calories_app/domain/profile/profile.dart';

/// State for user custom meal plan controller
class UserCustomMealPlanState {
  final List<UserMealPlan> plans;
  final UserMealPlan? editingPlan;
  final bool isLoading;
  final String? errorMessage;

  const UserCustomMealPlanState({
    this.plans = const [],
    this.editingPlan,
    this.isLoading = false,
    this.errorMessage,
  });

  UserCustomMealPlanState copyWith({
    List<UserMealPlan>? plans,
    UserMealPlan? editingPlan,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool clearEditingPlan = false,
  }) {
    return UserCustomMealPlanState(
      plans: plans ?? this.plans,
      editingPlan: clearEditingPlan ? null : (editingPlan ?? this.editingPlan),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller for managing user-created custom meal plans
/// 
/// Responsibilities:
/// - Manage list of user-created custom plans
/// - Handle plan creation, editing, deletion
/// - Run domain validations before saving plans
/// - Provide aggregated kcal/macros using domain services
/// 
/// Dependencies:
/// - UserMealPlanService (new DDD service with cache-first architecture)
/// - KcalCalculator (domain service)
/// - MacrosSummaryService (domain service)
/// - MealPlanValidationService (domain service)
class UserCustomMealPlanController extends Notifier<UserCustomMealPlanState> {
  UserMealPlanService? _service;
  StreamSubscription<List<UserMealPlan>>? _plansSubscription;
  String? _currentUserId;

  @override
  UserCustomMealPlanState build() {
    _service = ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
    
    // Cancel subscription when provider is disposed to prevent "Ref after disposed" errors
    ref.onDispose(() {
      _plansSubscription?.cancel();
      _plansSubscription = null;
    });
    
    return const UserCustomMealPlanState();
  }

  /// Load all custom plans for a user
  Future<void> loadPlans(String userId) async {
    try {
      if (_currentUserId == userId && _plansSubscription != null) {
        // Already loading for this user
        return;
      }

      _currentUserId = userId;
      state = state.copyWith(isLoading: true, errorMessage: null);

      final service = _service ?? ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      if (service == null) {
        throw Exception('Service not initialized');
      }

      // Cancel previous subscription if any
      await _plansSubscription?.cancel();

      // Subscribe to plans stream (cache-first)
      _plansSubscription = service.watchPlansForUserWithCache(userId).listen(
        (plans) {
          // Check if provider is still mounted before updating state
          // This prevents "Cannot use the Ref after it has been disposed" errors
          if (!ref.mounted) return;
          
          // IMPORTANT: Show ALL user plans (both custom and template-applied)
          // The "Your Meal Plans" tab should show all personal plans, not just custom ones
          // Filter removed - show all plans that belong to the user
          debugPrint('[UserCustomMealPlanController] 📊 Loaded ${plans.length} user plans (custom + template-applied)');
          
          // Sort: active plan first, then by creation date (newest first)
          final sortedPlans = List<UserMealPlan>.from(plans)
            ..sort((a, b) {
              // Active plan first
              if (a.isActive && !b.isActive) return -1;
              if (!a.isActive && b.isActive) return 1;
              // Then by creation date (newest first)
              final aDate = a.createdAt ?? DateTime(1970);
              final bDate = b.createdAt ?? DateTime(1970);
              return bDate.compareTo(aDate);
            });
          
          state = state.copyWith(
            plans: sortedPlans,
            isLoading: false,
            clearErrorMessage: true,
          );
        },
        onError: (error, stackTrace) {
          // Check if provider is still mounted before updating state
          if (!ref.mounted) return;
          
          debugPrint('[UserCustomMealPlanController] 🔥 Error loading plans: $error');
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to load plans: ${error.toString()}',
          );
        },
      );
    } catch (e) {
      debugPrint('[UserCustomMealPlanController] 🔥 Error in loadPlans: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load plans: ${e.toString()}',
      );
    }
  }

  /// Start editing an existing plan
  void startEditing(UserMealPlan plan) {
    state = state.copyWith(editingPlan: plan);
  }

  /// Create a new draft plan for editing
  void createNewDraft({
    required String userId,
    required String name,
    required String goalType,
    required int dailyCalories,
    required int durationDays,
  }) {
    final draft = UserMealPlan(
      id: '', // Will be generated on save
      userId: userId,
      planTemplateId: null,
      name: name,
      goalType: MealPlanGoalType.fromString(goalType), // Using domain enum
      type: UserMealPlanType.custom,
      startDate: DateTime.now(),
      currentDayIndex: 1,
      status: UserMealPlanStatus.active,
      dailyCalories: dailyCalories,
      durationDays: durationDays,
      isActive: false,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(editingPlan: draft);
  }

  /// Save the currently editing plan
  /// 
  /// Validates the plan using domain services before saving.
  Future<void> saveCurrentEditing({Profile? profile}) async {
    final editingPlan = state.editingPlan;
    if (editingPlan == null) {
      debugPrint('[UserCustomMealPlanController] ⚠️ No plan to save');
      return;
    }

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      // Validate using domain service
      if (profile != null && profile.targetKcal != null) {
        final validation = MealPlanValidationService.validateKcalDeviation(
          actualKcal: editingPlan.dailyCalories,
          targetKcal: profile.targetKcal!.toInt(),
        );

        if (validation.isWarning) {
          // Show warning but don't block save
          debugPrint('[UserCustomMealPlanController] ⚠️ Kcal deviation warning: ${validation.percentage.toStringAsFixed(1)}%');
        }
      }

      final service = _service ?? ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      if (service == null) {
        throw Exception('Service not initialized');
      }

      // Save the plan using service (handles cache updates)
      debugPrint('[UserCustomMealPlanController] 💾 Saving plan: ${editingPlan.id}');
      debugPrint('[UserCustomMealPlanController] 💾 Plan path: users/${editingPlan.userId}/user_meal_plans/${editingPlan.id}');
      
      try {
        await service.savePlan(editingPlan);
        debugPrint('[UserCustomMealPlanController] ✅ Successfully saved plan: ${editingPlan.id}');
      } catch (e, stackTrace) {
        debugPrint('[UserCustomMealPlanController] 🔥 ========== ERROR saving plan ==========');
        debugPrint('[UserCustomMealPlanController] 🔥 Plan ID: ${editingPlan.id}');
        debugPrint('[UserCustomMealPlanController] 🔥 User ID: ${editingPlan.userId}');
        debugPrint('[UserCustomMealPlanController] 🔥 Collection path: users/${editingPlan.userId}/user_meal_plans');
        debugPrint('[UserCustomMealPlanController] 🔥 Error: $e');
        debugPrint('[UserCustomMealPlanController] 🔥 Stack trace: $stackTrace');
        debugPrint('[UserCustomMealPlanController] 🔥 =======================================');
        rethrow;
      }

      // Reload plans and clear editing state
      if (_currentUserId != null) {
        await loadPlans(_currentUserId!);
      }
      state = state.copyWith(
        editingPlan: null,
        isLoading: false,
        clearEditingPlan: true,
      );
    } catch (e) {
      debugPrint('[UserCustomMealPlanController] 🔥 Error saving plan: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to save plan: ${e.toString()}',
      );
    }
  }

  /// Save plan and all meals in a single operation
  /// 
  /// This method handles saving both the plan document and all day meals.
  /// It's designed to be called from the UI without requiring ref usage after async operations.
  /// 
  /// [mealsByDay] is a map of dayIndex -> list of meals for that day.
  Future<String?> savePlanAndMeals({
    required UserMealPlan plan,
    required Map<int, List<MealItem>> mealsByDay,
    Profile? profile,
  }) async {
    if (!ref.mounted) return null;
    
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      // Use service for plan operations (handles cache)
      final service = _service ?? ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      if (service == null) {
        throw Exception('Service not initialized');
      }
      
      // Validate plan if profile is provided
      if (profile != null && profile.targetKcal != null) {
        final validation = MealPlanValidationService.validateKcalDeviation(
          actualKcal: plan.dailyCalories,
          targetKcal: profile.targetKcal!.toInt(),
        );
        if (validation.isWarning) {
          debugPrint('[UserCustomMealPlanController] ⚠️ Kcal deviation warning: ${validation.percentage.toStringAsFixed(1)}%');
        }
      }

      // Save the plan document using service (handles cache)
      debugPrint('[UserCustomMealPlanController] 💾 Saving plan: ${plan.id}');
      debugPrint('[UserCustomMealPlanController] 💾 Plan path: users/${plan.userId}/user_meal_plans/${plan.id}');
      
      try {
        await service.savePlan(plan);
        debugPrint('[UserCustomMealPlanController] ✅ Successfully saved plan: ${plan.id}');
      } catch (e, stackTrace) {
        debugPrint('[UserCustomMealPlanController] 🔥 ========== ERROR saving plan ==========');
        debugPrint('[UserCustomMealPlanController] 🔥 Plan ID: ${plan.id}');
        debugPrint('[UserCustomMealPlanController] 🔥 User ID: ${plan.userId}');
        debugPrint('[UserCustomMealPlanController] 🔥 Collection path: users/${plan.userId}/user_meal_plans');
        debugPrint('[UserCustomMealPlanController] 🔥 Error: $e');
        debugPrint('[UserCustomMealPlanController] 🔥 Stack trace: $stackTrace');
        debugPrint('[UserCustomMealPlanController] 🔥 =======================================');
        rethrow;
      }
      
      if (!ref.mounted) return plan.id;

      debugPrint('[UserCustomMealPlanController] 💾 Saving meals for ${mealsByDay.length} days');

      // Save meals for each day using batch writes (via service)
      for (final entry in mealsByDay.entries) {
        if (!ref.mounted) return plan.id;
        
        final dayIndex = entry.key;
        final meals = entry.value;
        
        // Get existing meals for this day to determine deletions
        final existingMeals = await service
            .getDayMeals(plan.id, plan.userId, dayIndex)
            .first;
        
        if (!ref.mounted) return plan.id;
        
        final existingMealIds = existingMeals.map((m) => m.id).toSet();
        final currentMealIds = meals.where((m) => m.id.isNotEmpty).map((m) => m.id).toSet();
        final mealsToDelete = existingMealIds.difference(currentMealIds).toList();
        
        // Use batch write for this day (via service)
        await service.saveDayMealsBatch(
          planId: plan.id,
          userId: plan.userId,
          dayIndex: dayIndex,
          mealsToSave: meals,
          mealsToDelete: mealsToDelete,
        );
        
        if (!ref.mounted) return plan.id;
      }

      debugPrint('[UserCustomMealPlanController] ✅ Saved plan and all meals: ${plan.id}');

      // Reload plans if user ID is available
      if (_currentUserId != null && _currentUserId == plan.userId) {
        await loadPlans(_currentUserId!);
      }
      
      if (!ref.mounted) return plan.id;
      
      state = state.copyWith(
        editingPlan: null,
        isLoading: false,
        clearEditingPlan: true,
        clearErrorMessage: true,
      );
      
      return plan.id;
    } catch (e) {
      if (!ref.mounted) return null;
      debugPrint('[UserCustomMealPlanController] 🔥 Error saving plan and meals: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to save plan: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Delete a plan
  Future<void> deletePlan(String planId) async {
    if (_currentUserId == null) {
      debugPrint('[UserCustomMealPlanController] ⚠️ No user ID available');
      return;
    }

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final service = _service ?? ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      if (service == null) {
        throw Exception('Service not initialized');
      }

      await service.deletePlan(planId, _currentUserId!);

      debugPrint('[UserCustomMealPlanController] ✅ Deleted plan: $planId');

      // Reload plans
      await loadPlans(_currentUserId!);
    } catch (e) {
      debugPrint('[UserCustomMealPlanController] 🔥 Error deleting plan: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete plan: ${e.toString()}',
      );
    }
  }
}

/// Provider for user custom meal plan controller
final userCustomMealPlanControllerProvider =
    NotifierProvider.autoDispose<UserCustomMealPlanController, UserCustomMealPlanState>(
  UserCustomMealPlanController.new,
);

