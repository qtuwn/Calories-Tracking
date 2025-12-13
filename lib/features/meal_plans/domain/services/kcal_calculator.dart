import 'package:calories_app/domain/profile/profile.dart';
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';

/// Pure domain service for kcal calculations and validation
/// 
/// No Flutter or Firestore dependencies.
/// All calculations are pure functions.
class KcalCalculator {
  /// Calculate deviation between actual and target kcal
  /// Returns: actual - target
  static int calculateDeviation(int actual, int target) {
    return actual - target;
  }

  /// Calculate percentage deviation
  /// Returns: ((actual - target) / target) * 100
  /// Returns 0.0 if target is 0
  static double calculatePercentage(int actual, int target) {
    if (target == 0) return 0.0;
    return ((actual - target) / target) * 100;
  }

  /// Calculate ratio (absolute deviation / target)
  /// Returns: abs(actual - target) / target
  /// Returns 0.0 if target is 0
  static double calculateRatio(int actual, int target) {
    if (target == 0) return 0.0;
    final diff = (actual - target).abs();
    return diff / target;
  }

  /// Get the recommended daily calorie range for a goal type based on user profile
  /// 
  /// Returns a map with 'min' and 'max' keys representing the allowed range
  /// Returns null if profile data is insufficient (missing TDEE)
  static Map<String, double>? getDailyCalorieRangeForGoal(
    Profile? profile,
    MealPlanGoalType goalType,
  ) {
    if (profile == null) {
      return null;
    }

    final tdee = profile.tdee;
    if (tdee == null || tdee <= 0) {
      return null;
    }

    switch (goalType) {
      case MealPlanGoalType.loseFat:
      case MealPlanGoalType.loseWeight:
        // Fat/weight loss: 200-500 kcal deficit
        return {
          'min': (tdee - 500).clamp(1200.0, double.infinity), // Minimum 1200 kcal for safety
          'max': tdee - 200,
        };
      case MealPlanGoalType.muscleGain:
      case MealPlanGoalType.gainWeight:
        // Muscle gain / weight gain: 200-500 kcal surplus
        return {
          'min': tdee + 200,
          'max': tdee + 500,
        };
      case MealPlanGoalType.vegan:
      case MealPlanGoalType.maintain:
      case MealPlanGoalType.maintainWeight:
      case MealPlanGoalType.other:
        // Maintenance: ±100 kcal from TDEE
        return {
          'min': (tdee - 100).clamp(1200.0, double.infinity),
          'max': tdee + 100,
        };
    }
  }

  /// Get the maximum daily calorie limit for a goal type
  /// 
  /// This is the upper bound that should not be exceeded
  /// Returns null if profile data is insufficient
  static double? getDailyCalorieLimitForGoal(
    Profile? profile,
    MealPlanGoalType goalType,
  ) {
    final range = getDailyCalorieRangeForGoal(profile, goalType);
    return range?['max'];
  }

  /// Get the minimum daily calorie limit for a goal type
  /// 
  /// This is the lower bound that should not be undercut
  /// Returns null if profile data is insufficient
  static double? getDailyCalorieMinimumForGoal(
    Profile? profile,
    MealPlanGoalType goalType,
  ) {
    final range = getDailyCalorieRangeForGoal(profile, goalType);
    return range?['min'];
  }

  /// Validate if a calorie value is within the allowed range for a goal
  /// 
  /// Returns true if valid, false otherwise
  static bool isValidCalorieForGoal(
    Profile? profile,
    MealPlanGoalType goalType,
    int calories,
  ) {
    final range = getDailyCalorieRangeForGoal(profile, goalType);
    if (range == null) {
      // If no profile data, allow any reasonable value (1200-4000)
      return calories >= 1200 && calories <= 4000;
    }

    return calories >= range['min']! && calories <= range['max']!;
  }

  /// Get a user-friendly error message for invalid calorie values
  /// 
  /// Returns null if valid, error message string if invalid
  static String? getCalorieValidationError(
    Profile? profile,
    MealPlanGoalType goalType,
    int calories,
  ) {
    if (profile == null || profile.tdee == null || profile.tdee! <= 0) {
      return 'Vui lòng hoàn thành hồ sơ của bạn để tính toán giới hạn calo phù hợp.';
    }

    final range = getDailyCalorieRangeForGoal(profile, goalType);
    if (range == null) {
      return 'Không thể tính toán giới hạn calo. Vui lòng kiểm tra hồ sơ của bạn.';
    }

    final min = range['min']!;
    final max = range['max']!;

    if (calories < min) {
      final goalName = _getGoalDisplayName(goalType);
      return 'Calo quá thấp cho mục tiêu "$goalName". Tối thiểu: ${min.toInt()} kcal/ngày.';
    }

    if (calories > max) {
      final goalName = _getGoalDisplayName(goalType);
      return 'Calo quá cao cho mục tiêu "$goalName". Tối đa: ${max.toInt()} kcal/ngày.';
    }

    return null; // Valid
  }

  /// Get display name for goal type (for error messages)
  static String _getGoalDisplayName(MealPlanGoalType goalType) {
    switch (goalType) {
      case MealPlanGoalType.loseFat:
        return 'Giảm mỡ';
      case MealPlanGoalType.loseWeight:
        return 'Giảm cân';
      case MealPlanGoalType.muscleGain:
        return 'Tăng cơ';
      case MealPlanGoalType.gainWeight:
        return 'Tăng cân';
      case MealPlanGoalType.vegan:
        return 'Thuần chay';
      case MealPlanGoalType.maintain:
        return 'Giữ dáng';
      case MealPlanGoalType.maintainWeight:
        return 'Duy trì cân nặng';
      case MealPlanGoalType.other:
        return 'Khác';
    }
  }
}

