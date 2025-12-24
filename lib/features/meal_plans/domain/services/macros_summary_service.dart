import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;
import 'package:calories_app/features/meal_plans/domain/models/shared/macros_summary.dart';
import 'package:calories_app/domain/meal_plans/services/meal_nutrition_calculator.dart';

/// Pure domain service for calculating macro summaries
/// 
/// No Flutter or Firestore dependencies.
/// All calculations are pure functions.
class MacrosSummaryService {
  /// Sum macros from a list of meal items
  /// 
  /// Returns a MacrosSummary with totals for calories, protein, carb, and fat
  static MacrosSummary sumMacros(List<MealItem> items) {
    final nutrition = MealNutritionCalculator.sumMeals(items);
    return MacrosSummary(
      calories: nutrition.calories,
      protein: nutrition.protein,
      carb: nutrition.carb,
      fat: nutrition.fat,
    );
  }

  /// Calculate average daily macros from multiple day summaries
  /// 
  /// Returns average macros across all days
  static MacrosSummary averageDailyMacros(List<MacrosSummary> daySummaries) {
    if (daySummaries.isEmpty) {
      return const MacrosSummary.empty();
    }

    // Use fold to accumulate totals (avoids forbidden += pattern)
    final totals = daySummaries.fold<MacrosSummary>(
      const MacrosSummary.empty(),
      (acc, summary) => MacrosSummary(
        calories: acc.calories + summary.calories,
        protein: acc.protein + summary.protein,
        carb: acc.carb + summary.carb,
        fat: acc.fat + summary.fat,
      ),
    );

    final count = daySummaries.length;
    return MacrosSummary(
      calories: totals.calories / count,
      protein: totals.protein / count,
      carb: totals.carb / count,
      fat: totals.fat / count,
    );
  }

  /// Calculate total macros for an entire plan (sum of all days)
  /// 
  /// Returns total macros across all days
  static MacrosSummary sumPlanMacros(List<MacrosSummary> daySummaries) {
    // Use fold to accumulate totals (avoids forbidden += pattern)
    return daySummaries.fold<MacrosSummary>(
      const MacrosSummary.empty(),
      (acc, summary) => MacrosSummary(
        calories: acc.calories + summary.calories,
        protein: acc.protein + summary.protein,
        carb: acc.carb + summary.carb,
        fat: acc.fat + summary.fat,
      ),
    );
  }
}

