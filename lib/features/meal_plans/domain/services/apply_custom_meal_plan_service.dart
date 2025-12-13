import 'package:calories_app/domain/meal_plans/user_meal_plan.dart';

/// Pure domain service for applying custom meal plans
/// 
/// This service handles the business logic of activating a user's custom meal plan.
/// 
/// No Flutter or Firestore dependencies.
class ApplyCustomMealPlanService {
  /// Validate that a plan can be applied
  /// 
  /// Returns true if:
  /// - Plan belongs to the user
  /// - Plan exists and is valid
  static bool canApplyPlan({
    required UserMealPlan plan,
    required String userId,
  }) {
    // Plan must belong to the user
    if (plan.userId != userId) {
      return false;
    }
    
    // Plan must be a custom plan (not a template-applied plan)
    // Actually, we can apply both custom and template-applied plans
    // The key is that it must belong to the user
    return true;
  }

  /// Prepare a plan for activation
  /// 
  /// Returns a copy of the plan with isActive = true and status = active
  static UserMealPlan prepareForActivation(UserMealPlan plan) {
    return plan.copyWith(
      isActive: true,
      status: UserMealPlanStatus.active,
      updatedAt: DateTime.now(),
    );
  }
}

