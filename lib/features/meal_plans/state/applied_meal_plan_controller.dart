// Controller: Applied meal plan state management
// 
// IMPORTANT: This controller is NOT the source of truth for the active plan.
// The single source of truth is `activeMealPlanProvider` which watches Firestore directly.
// 
// This controller is responsible for:
// - Computing today's macros and kcal from meals (side calculations)
// - Applying explore templates and custom plans (mutations)
// - Providing convenience methods for plan operations
// 
// For displaying the active plan in UI, always use:
// ```dart
// final activePlanAsync = ref.watch(activeMealPlanProvider);
// ```
//
// Used by: MealUserActivePage (for macros), MealDetailPage (for applying plans)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_service.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/macros_summary.dart';
import 'package:calories_app/features/meal_plans/domain/services/apply_custom_meal_plan_service.dart';
import 'package:calories_app/shared/state/user_meal_plan_providers.dart' as user_meal_plan_providers;
import 'package:calories_app/shared/state/explore_meal_plan_providers.dart' as explore_meal_plan_providers;
import 'package:calories_app/domain/profile/profile.dart';

/// State for applied meal plan controller
/// 
/// NOTE: This controller does NOT maintain the active plan as source of truth.
/// The active plan should be read from activeMealPlanProvider.
/// This state only tracks:
/// - Loading/error status for apply operations
/// - Computed macros (if needed for specific UI)
class AppliedMealPlanState {
  final MacrosSummary? todayMacros;
  final int? todayKcal;
  final bool isLoading;
  final String? errorMessage;

  const AppliedMealPlanState({
    this.todayMacros,
    this.todayKcal,
    this.isLoading = false,
    this.errorMessage,
  });

  AppliedMealPlanState copyWith({
    MacrosSummary? todayMacros,
    int? todayKcal,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AppliedMealPlanState(
      todayMacros: todayMacros ?? this.todayMacros,
      todayKcal: todayKcal ?? this.todayKcal,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller for managing the currently active meal plan for the user
/// 
/// Responsibilities:
/// - Manage the currently active/applied plan for the logged-in user
/// - Apply explore templates to user profiles
/// - Compute derived daily totals (kcal/macros) for presentation
/// 
/// Dependencies:
/// - UserMealPlanService (new DDD service with cache-first architecture)
/// - ApplyExploreTemplateService (domain service)
/// - MacrosSummaryService (domain service)
class AppliedMealPlanController extends Notifier<AppliedMealPlanState> {
  UserMealPlanService? _service;

  @override
  AppliedMealPlanState build() {
    _service = ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
    return const AppliedMealPlanState();
  }

  /// Apply an explore template by templateId
  /// 
  /// This is the public API for applying explore templates.
  /// It uses the service's atomic applyExploreTemplateAsActivePlan method
  /// which ensures proper deactivation of old plans and creation of new active plan.
  /// 
  /// After applying, the user should be redirected to "Your Meal Plans" tab.
  Future<void> applyExploreTemplate({
    required String templateId,
    required Profile profile,
    required String userId,
  }) async {
    if (!ref.mounted) return;
    
    try {
      debugPrint('[AppliedMealPlanController] [Explore] 🚀 Starting apply explore template flow for templateId: $templateId');
      debugPrint('[AppliedMealPlanController] [Explore] User ID: $userId');
      
      state = state.copyWith(isLoading: true, errorMessage: null);
      
      final service = _service ?? ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      if (service == null) {
        throw Exception('Service not initialized');
      }
      
      // Load template from explore repository
      final exploreRepo = ref.read(explore_meal_plan_providers.exploreMealPlanRepositoryProvider);
      debugPrint('[AppliedMealPlanController] [Explore] 📋 Loading template: $templateId');
      
      final template = await exploreRepo.getPlanById(templateId);
      
      if (template == null) {
        throw Exception('Template not found: $templateId');
      }
      
      debugPrint('[AppliedMealPlanController] [Explore] ✅ Template loaded: ${template.name}');
      debugPrint('[AppliedMealPlanController] [Explore] 📋 Template details: days=${template.durationDays}, kcal=${template.templateKcal}');
      
      // Convert Profile to Map for service method (using correct Profile field names)
      final profileData = {
        'targetKcal': profile.targetKcal,
        'proteinGrams': profile.proteinGrams,
        'carbGrams': profile.carbGrams,
        'fatGrams': profile.fatGrams,
      };
      
      // Use service's atomic method to apply template (handles cache)
      debugPrint('[AppliedMealPlanController] [Explore] 🔄 Calling service.applyExploreTemplateAsActivePlan()...');
      final newPlan = await service.applyExploreTemplateAsActivePlan(
        userId: userId,
        templateId: templateId,
        template: template,
        profileData: profileData,
      );
      
      if (!ref.mounted) return;
      
      debugPrint('[AppliedMealPlanController] [Explore] ✅ Successfully applied explore template: $templateId');
      debugPrint('[AppliedMealPlanController] [Explore] ✅ New active plan: planId=${newPlan.id}, name="${newPlan.name}"');
      
      // The service has already:
      // 1. Cleared stale cache
      // 2. Applied the plan via repository
      // 3. Saved new plan to cache
      // 
      // The activeMealPlanProvider stream will automatically emit the new plan
      // from Firestore, which will override any cached value.
      // 
      // We invalidate the provider to ensure it re-subscribes and gets the latest data.
      debugPrint('[AppliedMealPlanController] [Explore] 🔄 Invalidating activeMealPlanProvider to trigger refresh...');
      ref.invalidate(user_meal_plan_providers.activeMealPlanProvider);
      
      debugPrint('[AppliedMealPlanController] [Explore] ✅ Apply complete - activeMealPlanProvider will emit new plan from Firestore');
      
      state = state.copyWith(
        isLoading: false,
        clearErrorMessage: true,
      );
    } catch (e, stackTrace) {
      if (!ref.mounted) return;
      debugPrint('[AppliedMealPlanController] [Explore] 🔥 Error applying explore template: $e');
      debugPrint('[AppliedMealPlanController] [Explore] 🔥 Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to apply template: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Apply a custom meal plan by planId
  /// 
  /// This validates ownership and sets the plan as active.
  /// Only the plan owner can apply their own custom plans.
  /// 
  /// After applying, the user should see the plan in "Your Meal Plans" tab.
  /// 
  /// Call chain: Controller → Service → Repository → Firestore batch write
  /// 
  /// IMPORTANT: This method completes the Firestore write even if the widget unmounts.
  /// Only UI-related operations (state updates, provider invalidation) are guarded by mounted checks.
  Future<void> applyCustomPlan({
    required String planId,
    required String userId,
  }) async {
    try {
      debugPrint('[AppliedMealPlanController] [Custom] 🚀 Starting apply custom plan: planId=$planId, userId=$userId');
      
      // Validate userId is not empty
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty');
      }
      if (planId.isEmpty) {
        throw Exception('Plan ID cannot be empty');
      }
      
      // Get service - this must happen before any async operations
      final service = _service ?? ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      if (service == null) {
        throw Exception('Service not initialized');
      }
      
      // Update state only if widget is still mounted
      if (ref.mounted) {
        state = state.copyWith(isLoading: true, errorMessage: null);
      }
      
      // Load the plan to validate ownership (using service for cache-first read)
      final plan = await service.loadPlanByIdOnce(userId, planId);
      
      if (plan == null) {
        throw Exception('Plan not found: $planId');
      }
      
      debugPrint('[AppliedMealPlanController] [Custom] ✅ Plan loaded: ${plan.name}');
      
      // Validate ownership using domain service
      if (!ApplyCustomMealPlanService.canApplyPlan(plan: plan, userId: userId)) {
        throw Exception('Plan does not belong to user');
      }
      
      // CRITICAL: Apply the plan via service - this MUST complete even if widget unmounts
      // This is the actual Firestore write that persists isActive=true
      debugPrint('[AppliedMealPlanController] [Custom] 🔄 Applying plan to Firestore...');
      final activatedPlan = await service.applyCustomPlanAsActive(
        userId: userId,
        planId: planId,
      );
      
      // Verify the returned plan is actually active
      if (!activatedPlan.isActive) {
        throw Exception('Service returned inactive plan - Firestore write may have failed');
      }
      
      debugPrint('[AppliedMealPlanController] [Custom] ✅ Plan applied successfully: planId=${activatedPlan.id}, isActive=${activatedPlan.isActive}');
      
      // Invalidate provider to trigger refresh - only if widget is still mounted
      if (ref.mounted) {
        ref.invalidate(user_meal_plan_providers.activeMealPlanProvider);
        state = state.copyWith(
          isLoading: false,
          clearErrorMessage: true,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[AppliedMealPlanController] [Custom] 🔥 Error applying plan: $e');
      debugPrint('[AppliedMealPlanController] [Custom] 🔥 Stack trace: $stackTrace');
      
      // Update state only if widget is still mounted
      if (ref.mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to apply plan: ${e.toString()}',
        );
      }
      rethrow; // Re-throw to let UI handle the error
    }
  }


  /// Set a user meal plan as active by ID
  /// 
  /// DEPRECATED: Use applyCustomPlan() instead for better validation and logging.
  /// This method is kept for backward compatibility but will be removed.
  @Deprecated('Use applyCustomPlan() instead')
  Future<void> setActivePlanById({
    required String userId,
    required String planId,
  }) async {
    debugPrint('[AppliedMealPlanController] ⚠️ setActivePlanById() is deprecated, use applyCustomPlan() instead');
    await applyCustomPlan(planId: planId, userId: userId);
  }

  /// Clear the active plan (deactivate it)
  /// 
  /// NOTE: This method is kept for backward compatibility but should be
  /// replaced with direct service calls in the future.
  Future<void> clearActivePlan(String userId) async {
    if (!ref.mounted) return;
    
    try {
      // Get active plan from provider (source of truth)
      final activePlanAsync = ref.read(user_meal_plan_providers.activeMealPlanProvider);
      final activePlan = activePlanAsync.value;
      
      if (activePlan == null) {
        debugPrint('[AppliedMealPlanController] ⚠️ No active plan to clear');
        return;
      }

      state = state.copyWith(isLoading: true, errorMessage: null);

      final service = _service ?? ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      if (service == null) {
        throw Exception('Service not initialized');
      }

      // Update plan status to paused using service
      await service.updatePlanStatus(
        planId: activePlan.id,
        userId: userId,
        status: 'paused',
      );
      
      if (!ref.mounted) return;

      debugPrint('[AppliedMealPlanController] ✅ Cleared active plan');

      // Invalidate provider to refresh
      ref.invalidate(user_meal_plan_providers.activeMealPlanProvider);
      
      state = state.copyWith(
        isLoading: false,
        clearErrorMessage: true,
      );
    } catch (e) {
      if (!ref.mounted) return;
      debugPrint('[AppliedMealPlanController] 🔥 Error clearing active plan: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to clear active plan: ${e.toString()}',
      );
    }
  }
}

/// Provider for applied meal plan controller
final appliedMealPlanControllerProvider =
    NotifierProvider.autoDispose<AppliedMealPlanController, AppliedMealPlanState>(
  AppliedMealPlanController.new,
);

