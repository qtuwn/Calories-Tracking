import 'package:flutter_test/flutter_test.dart';
import 'package:calories_app/features/meal_plans/domain/services/macros_summary_service.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;
import 'package:calories_app/features/meal_plans/domain/models/shared/macros_summary.dart';

void main() {
  group('MacrosSummaryService', () {
    group('sumMacros', () {
      test('returns empty summary for empty list', () {
        final result = MacrosSummaryService.sumMacros([]);
        expect(result.calories, 0.0);
        expect(result.protein, 0.0);
        expect(result.carb, 0.0);
        expect(result.fat, 0.0);
      });

      test('returns correct totals for single meal item', () {
        final items = [
          MealItem(
            id: '1',
            mealType: 'breakfast',
            foodId: 'food1',
            servingSize: 1.0,
            calories: 300.0,
            protein: 20.0,
            carb: 30.0,
            fat: 10.0,
          ),
        ];

        final result = MacrosSummaryService.sumMacros(items);
        expect(result.calories, 300.0);
        expect(result.protein, 20.0);
        expect(result.carb, 30.0);
        expect(result.fat, 10.0);
      });

      test('returns correct totals for multiple meal items', () {
        final items = [
          MealItem(
            id: '1',
            mealType: 'breakfast',
            foodId: 'food1',
            servingSize: 1.0,
            calories: 300.0,
            protein: 20.0,
            carb: 30.0,
            fat: 10.0,
          ),
          MealItem(
            id: '2',
            mealType: 'lunch',
            foodId: 'food2',
            servingSize: 1.5,
            calories: 500.0,
            protein: 35.0,
            carb: 50.0,
            fat: 15.0,
          ),
          MealItem(
            id: '3',
            mealType: 'dinner',
            foodId: 'food3',
            servingSize: 2.0,
            calories: 700.0,
            protein: 45.0,
            carb: 70.0,
            fat: 20.0,
          ),
        ];

        final result = MacrosSummaryService.sumMacros(items);
        expect(result.calories, 1500.0);
        expect(result.protein, 100.0);
        expect(result.carb, 150.0);
        expect(result.fat, 45.0);
      });

      test('handles decimal values correctly', () {
        final items = [
          MealItem(
            id: '1',
            mealType: 'breakfast',
            foodId: 'food1',
            servingSize: 1.5,
            calories: 337.5,
            protein: 22.5,
            carb: 33.75,
            fat: 11.25,
          ),
        ];

        final result = MacrosSummaryService.sumMacros(items);
        expect(result.calories, 337.5);
        expect(result.protein, 22.5);
        expect(result.carb, 33.75);
        expect(result.fat, 11.25);
      });

      test('handles zero values correctly', () {
        final items = [
          MealItem(
            id: '1',
            mealType: 'snack',
            foodId: 'food1',
            servingSize: 1.0,
            calories: 0.0,
            protein: 0.0,
            carb: 0.0,
            fat: 0.0,
          ),
        ];

        final result = MacrosSummaryService.sumMacros(items);
        expect(result.calories, 0.0);
        expect(result.protein, 0.0);
        expect(result.carb, 0.0);
        expect(result.fat, 0.0);
      });
    });

    group('averageDailyMacros', () {
      test('returns empty summary for empty list', () {
        final result = MacrosSummaryService.averageDailyMacros([]);
        expect(result.calories, 0.0);
        expect(result.protein, 0.0);
        expect(result.carb, 0.0);
        expect(result.fat, 0.0);
      });

      test('returns correct average for single day', () {
        final summaries = [
          MacrosSummary(
            calories: 2000.0,
            protein: 150.0,
            carb: 200.0,
            fat: 60.0,
          ),
        ];

        final result = MacrosSummaryService.averageDailyMacros(summaries);
        expect(result.calories, 2000.0);
        expect(result.protein, 150.0);
        expect(result.carb, 200.0);
        expect(result.fat, 60.0);
      });

      test('returns correct average for multiple days', () {
        final summaries = [
          MacrosSummary(
            calories: 2000.0,
            protein: 150.0,
            carb: 200.0,
            fat: 60.0,
          ),
          MacrosSummary(
            calories: 1800.0,
            protein: 140.0,
            carb: 180.0,
            fat: 55.0,
          ),
          MacrosSummary(
            calories: 2200.0,
            protein: 160.0,
            carb: 220.0,
            fat: 65.0,
          ),
        ];

        final result = MacrosSummaryService.averageDailyMacros(summaries);
        expect(result.calories, closeTo(2000.0, 0.01));
        expect(result.protein, closeTo(150.0, 0.01));
        expect(result.carb, closeTo(200.0, 0.01));
        expect(result.fat, closeTo(60.0, 0.01));
      });

      test('handles decimal averages correctly', () {
        final summaries = [
          MacrosSummary(
            calories: 2000.0,
            protein: 150.0,
            carb: 200.0,
            fat: 60.0,
          ),
          MacrosSummary(
            calories: 1800.0,
            protein: 140.0,
            carb: 180.0,
            fat: 55.0,
          ),
        ];

        final result = MacrosSummaryService.averageDailyMacros(summaries);
        expect(result.calories, 1900.0);
        expect(result.protein, 145.0);
        expect(result.carb, 190.0);
        expect(result.fat, 57.5);
      });
    });

    group('sumPlanMacros', () {
      test('returns empty summary for empty list', () {
        final result = MacrosSummaryService.sumPlanMacros([]);
        expect(result.calories, 0.0);
        expect(result.protein, 0.0);
        expect(result.carb, 0.0);
        expect(result.fat, 0.0);
      });

      test('returns correct total for single day', () {
        final summaries = [
          MacrosSummary(
            calories: 2000.0,
            protein: 150.0,
            carb: 200.0,
            fat: 60.0,
          ),
        ];

        final result = MacrosSummaryService.sumPlanMacros(summaries);
        expect(result.calories, 2000.0);
        expect(result.protein, 150.0);
        expect(result.carb, 200.0);
        expect(result.fat, 60.0);
      });

      test('returns correct total for multiple days', () {
        final summaries = [
          MacrosSummary(
            calories: 2000.0,
            protein: 150.0,
            carb: 200.0,
            fat: 60.0,
          ),
          MacrosSummary(
            calories: 1800.0,
            protein: 140.0,
            carb: 180.0,
            fat: 55.0,
          ),
          MacrosSummary(
            calories: 2200.0,
            protein: 160.0,
            carb: 220.0,
            fat: 65.0,
          ),
        ];

        final result = MacrosSummaryService.sumPlanMacros(summaries);
        expect(result.calories, 6000.0);
        expect(result.protein, 450.0);
        expect(result.carb, 600.0);
        expect(result.fat, 180.0);
      });
    });
  });
}

