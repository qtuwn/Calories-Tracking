import 'package:flutter_test/flutter_test.dart';
import 'package:calories_app/features/admin_tools/domain/repair_planner.dart';
import 'package:calories_app/domain/meal_plans/services/meal_nutrition_calculator.dart'
    show MealNutrition;

void main() {
  group('RepairPlanner.shouldRepairDouble', () {
    test('exact match => false', () {
      expect(
        RepairPlanner.shouldRepairDouble(100.0, 100.0, 0.0001),
        false,
      );
    });

    test('small diff within epsilon => false', () {
      expect(
        RepairPlanner.shouldRepairDouble(100.0, 100.00005, 0.0001),
        false,
      );
      expect(
        RepairPlanner.shouldRepairDouble(100.0, 99.99995, 0.0001),
        false,
      );
    });

    test('diff beyond epsilon => true', () {
      expect(
        RepairPlanner.shouldRepairDouble(100.0, 100.0002, 0.0001),
        true,
      );
      expect(
        RepairPlanner.shouldRepairDouble(100.0, 99.9998, 0.0001),
        true,
      );
    });

    test('negative epsilon throws ArgumentError', () {
      expect(
        () => RepairPlanner.shouldRepairDouble(100.0, 100.0, -0.1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('NaN stored throws ArgumentError', () {
      expect(
        () => RepairPlanner.shouldRepairDouble(
          double.nan,
          100.0,
          0.0001,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('NaN computed throws ArgumentError', () {
      expect(
        () => RepairPlanner.shouldRepairDouble(
          100.0,
          double.nan,
          0.0001,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('infinite stored throws ArgumentError', () {
      expect(
        () => RepairPlanner.shouldRepairDouble(
          double.infinity,
          100.0,
          0.0001,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('infinite computed throws ArgumentError', () {
      expect(
        () => RepairPlanner.shouldRepairDouble(
          100.0,
          double.negativeInfinity,
          0.0001,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('RepairPlanner.shouldRepairDayTotals', () {
    test('exact match => false', () {
      const stored = MealNutrition(
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );
      const computed = MealNutrition(
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        RepairPlanner.shouldRepairDayTotals(
          storedTotals: stored,
          computedTotals: computed,
          epsilon: 0.0001,
        ),
        false,
      );
    });

    test('small diff within epsilon => false', () {
      const stored = MealNutrition(
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );
      const computed = MealNutrition(
        calories: 100.00005,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        RepairPlanner.shouldRepairDayTotals(
          storedTotals: stored,
          computedTotals: computed,
          epsilon: 0.0001,
        ),
        false,
      );
    });

    test('diff beyond epsilon in calories => true', () {
      const stored = MealNutrition(
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );
      const computed = MealNutrition(
        calories: 100.0002,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        RepairPlanner.shouldRepairDayTotals(
          storedTotals: stored,
          computedTotals: computed,
          epsilon: 0.0001,
        ),
        true,
      );
    });

    test('diff beyond epsilon in protein => true', () {
      const stored = MealNutrition(
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );
      const computed = MealNutrition(
        calories: 100.0,
        protein: 20.0002,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        RepairPlanner.shouldRepairDayTotals(
          storedTotals: stored,
          computedTotals: computed,
          epsilon: 0.0001,
        ),
        true,
      );
    });

    test('negative epsilon throws ArgumentError', () {
      const stored = MealNutrition(
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );
      const computed = MealNutrition(
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        () => RepairPlanner.shouldRepairDayTotals(
          storedTotals: stored,
          computedTotals: computed,
          epsilon: -0.1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
