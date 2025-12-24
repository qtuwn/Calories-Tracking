import 'package:calories_app/features/meal_plans/domain/services/kcal_calculator.dart';
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';
import 'package:calories_app/domain/profile/profile.dart';

/// Pure domain service for meal plan validation
/// 
/// No Flutter or Firestore dependencies.
/// All validation logic is pure functions.
class MealPlanValidationService {
  /// Default threshold for kcal deviation warning (15%)
  static const double defaultKcalDeviationThreshold = 0.15;

  /// Validate kcal deviation against user's target
  /// 
  /// Returns ValidationResult with:
  /// - isValid: true if within acceptable range
  /// - deviation: actual - target
  /// - percentage: percentage deviation
  /// - ratio: absolute deviation ratio
  /// - isWarning: true if deviation exceeds threshold
  static KcalValidationResult validateKcalDeviation({
    required int actualKcal,
    required int targetKcal,
    double threshold = defaultKcalDeviationThreshold,
  }) {
    final deviation = KcalCalculator.calculateDeviation(actualKcal, targetKcal);
    final percentage = KcalCalculator.calculatePercentage(actualKcal, targetKcal);
    final ratio = KcalCalculator.calculateRatio(actualKcal, targetKcal);
    final isWarning = ratio > threshold;

    return KcalValidationResult(
      isValid: !isWarning,
      deviation: deviation,
      percentage: percentage,
      ratio: ratio,
      isWarning: isWarning,
    );
  }

  /// Validate if meal count per day is within reasonable range
  /// 
  /// Returns true if valid (typically 3-6 meals per day)
  static bool validateMealCount(int mealsPerDay) {
    return mealsPerDay >= 3 && mealsPerDay <= 6;
  }

  /// Validate if macros are within reasonable ranges
  /// 
  /// Basic validation: all values should be non-negative
  /// More sophisticated validation can be added later
  static bool validateMacros({
    required double protein,
    required double carb,
    required double fat,
  }) {
    return protein >= 0 && carb >= 0 && fat >= 0;
  }

  /// Validate user meal plan kcal against profile target
  /// 
  /// Uses KcalCalculator to check if plan kcal is within recommended range
  static KcalValidationResult validateUserPlanKcal({
    required int planKcal,
    required Profile? profile,
    required MealPlanGoalType goalType,
    double threshold = defaultKcalDeviationThreshold,
  }) {
    if (profile == null || profile.targetKcal == null || profile.targetKcal! <= 0) {
      // No profile data - can't validate
      return KcalValidationResult(
        isValid: true, // Don't block if no profile
        deviation: 0,
        percentage: 0.0,
        ratio: 0.0,
        isWarning: false,
      );
    }

    final targetKcal = profile.targetKcal!.toInt();
    return validateKcalDeviation(
      actualKcal: planKcal,
      targetKcal: targetKcal,
      threshold: threshold,
    );
  }
}

/// Result of kcal validation
class KcalValidationResult {
  final bool isValid;
  final int deviation; // actual - target
  final double percentage; // ((actual - target) / target) * 100
  final double ratio; // abs(actual - target) / target
  final bool isWarning; // true if ratio > threshold

  const KcalValidationResult({
    required this.isValid,
    required this.deviation,
    required this.percentage,
    required this.ratio,
    required this.isWarning,
  });
}

