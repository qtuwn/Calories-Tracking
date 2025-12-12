import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;
import 'package:calories_app/features/meal_plans/domain/models/shared/macros_summary.dart';

/// Pure domain service for calculating macro summaries
/// 
/// No Flutter or Firestore dependencies.
/// All calculations are pure functions.
class MacrosSummaryService {
  /// Sum macros from a list of meal items
  /// 
  /// Returns a MacrosSummary with totals for calories, protein, carb, and fat
  static MacrosSummary sumMacros(List<MealItem> items) {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarb = 0.0;
    double totalFat = 0.0;

    for (final item in items) {
      totalCalories += item.calories;
      totalProtein += item.protein;
      totalCarb += item.carb;
      totalFat += item.fat;
    }

    return MacrosSummary(
      calories: totalCalories,
      protein: totalProtein,
      carb: totalCarb,
      fat: totalFat,
    );
  }

  /// Calculate average daily macros from multiple day summaries
  /// 
  /// Returns average macros across all days
  static MacrosSummary averageDailyMacros(List<MacrosSummary> daySummaries) {
    if (daySummaries.isEmpty) {
      return const MacrosSummary.empty();
    }

    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarb = 0.0;
    double totalFat = 0.0;

    for (final summary in daySummaries) {
      totalCalories += summary.calories;
      totalProtein += summary.protein;
      totalCarb += summary.carb;
      totalFat += summary.fat;
    }

    final count = daySummaries.length;
    return MacrosSummary(
      calories: totalCalories / count,
      protein: totalProtein / count,
      carb: totalCarb / count,
      fat: totalFat / count,
    );
  }

  /// Calculate total macros for an entire plan (sum of all days)
  /// 
  /// Returns total macros across all days
  static MacrosSummary sumPlanMacros(List<MacrosSummary> daySummaries) {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarb = 0.0;
    double totalFat = 0.0;

    for (final summary in daySummaries) {
      totalCalories += summary.calories;
      totalProtein += summary.protein;
      totalCarb += summary.carb;
      totalFat += summary.fat;
    }

    return MacrosSummary(
      calories: totalCalories,
      protein: totalProtein,
      carb: totalCarb,
      fat: totalFat,
    );
  }
}

