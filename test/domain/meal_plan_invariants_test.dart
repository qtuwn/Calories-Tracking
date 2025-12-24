import 'package:flutter_test/flutter_test.dart';
import 'package:calories_app/domain/meal_plans/services/meal_plan_invariants.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;
import 'package:calories_app/domain/meal_plans/explore_meal_plan.dart' show MealSlot;

void main() {
  group('MealPlanInvariants.validateMealItem', () {
    test('throws on empty foodId', () {
      final item = MealItem(
        id: 'meal1',
        mealType: 'breakfast',
        foodId: '', // Empty
        servingSize: 1.0,
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        () => MealPlanInvariants.validateMealItem(item),
        throwsA(isA<MealPlanInvariantException>()),
      );
    });

    test('throws on servingSize <= 0', () {
      final item = MealItem(
        id: 'meal1',
        mealType: 'breakfast',
        foodId: 'food1',
        servingSize: 0.0, // Invalid
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        () => MealPlanInvariants.validateMealItem(item),
        throwsA(isA<MealPlanInvariantException>()),
      );
    });

    test('throws on negative calories', () {
      final item = MealItem(
        id: 'meal1',
        mealType: 'breakfast',
        foodId: 'food1',
        servingSize: 1.0,
        calories: -10.0, // Invalid
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        () => MealPlanInvariants.validateMealItem(item),
        throwsA(isA<MealPlanInvariantException>()),
      );
    });

    test('throws on NaN calories', () {
      final item = MealItem(
        id: 'meal1',
        mealType: 'breakfast',
        foodId: 'food1',
        servingSize: 1.0,
        calories: double.nan, // Invalid
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        () => MealPlanInvariants.validateMealItem(item),
        throwsA(isA<MealPlanInvariantException>()),
      );
    });

    test('does not throw on valid values', () {
      final item = MealItem(
        id: 'meal1',
        mealType: 'breakfast',
        foodId: 'food1',
        servingSize: 1.0,
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        () => MealPlanInvariants.validateMealItem(item),
        returnsNormally,
      );
    });

    test('toString includes context fields', () {
      final item = MealItem(
        id: 'meal1',
        mealType: 'breakfast',
        foodId: '',
        servingSize: 1.0,
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      try {
        MealPlanInvariants.validateMealItem(
          item,
          userId: 'user123',
          planId: 'plan456',
          dayIndex: 1,
          docPath: 'path/to/doc',
        );
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<MealPlanInvariantException>());
        final str = e.toString();
        expect(str, contains('userId=user123'));
        expect(str, contains('planId=plan456'));
        expect(str, contains('dayIndex=1'));
        expect(str, contains('docPath=path/to/doc'));
      }
    });
  });

  group('MealPlanInvariants.validateMealSlot', () {
    test('throws on empty foodId string (if provided)', () {
      final slot = MealSlot(
        id: 'slot1',
        name: 'Test Meal',
        mealType: 'breakfast',
        foodId: '', // Empty string (invalid)
        servingSize: 1.0,
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        () => MealPlanInvariants.validateMealSlot(slot),
        throwsA(isA<MealPlanInvariantException>()),
      );
    });

    test('does not throw on null foodId', () {
      final slot = MealSlot(
        id: 'slot1',
        name: 'Test Meal',
        mealType: 'breakfast',
        foodId: null, // Null is allowed
        servingSize: 1.0,
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        () => MealPlanInvariants.validateMealSlot(slot),
        returnsNormally,
      );
    });

    test('throws on servingSize <= 0', () {
      final slot = MealSlot(
        id: 'slot1',
        name: 'Test Meal',
        mealType: 'breakfast',
        foodId: 'food1',
        servingSize: 0.0, // Invalid
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        () => MealPlanInvariants.validateMealSlot(slot),
        throwsA(isA<MealPlanInvariantException>()),
      );
    });

    test('does not throw on valid values', () {
      final slot = MealSlot(
        id: 'slot1',
        name: 'Test Meal',
        mealType: 'breakfast',
        foodId: 'food1',
        servingSize: 1.0,
        calories: 100.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );

      expect(
        () => MealPlanInvariants.validateMealSlot(slot),
        returnsNormally,
      );
    });
  });
}
