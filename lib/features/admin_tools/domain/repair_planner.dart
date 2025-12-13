import 'package:calories_app/domain/meal_plans/services/meal_nutrition_calculator.dart'
    show MealNutrition;

/// Pure domain functions for repair planning (unit-testable, no Flutter/Firebase)
class RepairPlanner {
  RepairPlanner._(); // Prevent instantiation

  /// Check if a double value needs repair (difference > epsilon)
  /// 
  /// Throws ArgumentError if inputs are invalid (fail-fast).
  static bool shouldRepairDouble(
    double stored,
    double computed,
    double epsilon,
  ) {
    if (epsilon < 0) {
      throw ArgumentError('epsilon must be non-negative, got $epsilon');
    }

    if (stored.isNaN || computed.isNaN) {
      throw ArgumentError(
        'Cannot compare NaN values: stored=$stored, computed=$computed',
      );
    }

    if (stored.isInfinite || computed.isInfinite) {
      throw ArgumentError(
        'Cannot compare infinite values: stored=$stored, computed=$computed',
      );
    }

    final diff = (stored - computed).abs();
    return diff > epsilon;
  }

  /// Check if day totals need repair (any macro difference > epsilon)
  /// 
  /// Throws ArgumentError if inputs are invalid (fail-fast).
  static bool shouldRepairDayTotals({
    required MealNutrition storedTotals,
    required MealNutrition computedTotals,
    required double epsilon,
  }) {
    if (epsilon < 0) {
      throw ArgumentError('epsilon must be non-negative, got $epsilon');
    }

    // Check each macro
    if (shouldRepairDouble(storedTotals.calories, computedTotals.calories, epsilon)) {
      return true;
    }
    if (shouldRepairDouble(storedTotals.protein, computedTotals.protein, epsilon)) {
      return true;
    }
    if (shouldRepairDouble(storedTotals.carb, computedTotals.carb, epsilon)) {
      return true;
    }
    if (shouldRepairDouble(storedTotals.fat, computedTotals.fat, epsilon)) {
      return true;
    }

    return false;
  }
}
