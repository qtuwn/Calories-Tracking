import 'package:flutter_test/flutter_test.dart';
import 'package:calories_app/domain/meal_plans/explore_meal_plan.dart';
import 'package:calories_app/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart'
    show MealPlanApplyException, requireNonEmptyForTesting, requirePositiveForTesting;

/// Unit tests for apply explore template validation logic
/// 
/// Tests the helper validators and ensures fail-fast behavior for invalid data.
/// These tests do NOT call Firestore - they test pure validation logic.
void main() {
  group('requireNonEmptyForTesting validation', () {
    test('throws MealPlanApplyException when foodId is null', () {
      expect(
        () => requireNonEmptyForTesting(
          null,
          'foodId',
          userId: 'user-1',
          templateId: 'template-1',
          dayIndex: 1,
          slotIndex: 0,
          mealType: 'breakfast',
        ),
        throwsA(isA<MealPlanApplyException>()),
      );
    });

    test('throws MealPlanApplyException when foodId is empty string', () {
      expect(
        () => requireNonEmptyForTesting(
          '',
          'foodId',
          userId: 'user-1',
          templateId: 'template-1',
          dayIndex: 1,
          slotIndex: 0,
          mealType: 'breakfast',
        ),
        throwsA(isA<MealPlanApplyException>()),
      );
    });

    test('throws MealPlanApplyException when foodId is whitespace only', () {
      expect(
        () => requireNonEmptyForTesting(
          '   ',
          'foodId',
          userId: 'user-1',
          templateId: 'template-1',
          dayIndex: 1,
          slotIndex: 0,
          mealType: 'breakfast',
        ),
        throwsA(isA<MealPlanApplyException>()),
      );
    });

    test('returns trimmed value when foodId is valid', () {
      final result = requireNonEmptyForTesting(
        '  food-123  ',
        'foodId',
        userId: 'user-1',
        templateId: 'template-1',
        dayIndex: 1,
        slotIndex: 0,
        mealType: 'breakfast',
      );
      expect(result, equals('food-123'));
    });

    test('exception message contains templateId, dayIndex, slotIndex', () {
      try {
        requireNonEmptyForTesting(
          null,
          'foodId',
          userId: 'user-1',
          templateId: 'template-1',
          dayIndex: 2,
          slotIndex: 5,
          mealType: 'lunch',
        );
        fail('Should have thrown MealPlanApplyException');
      } on MealPlanApplyException catch (e) {
        expect(e.toString(), contains('template-1'));
        expect(e.toString(), contains('dayIndex=2'));
        expect(e.toString(), contains('slotIndex=5'));
        expect(e.toString(), contains('mealType=lunch'));
        expect(e.templateId, equals('template-1'));
        expect(e.dayIndex, equals(2));
        expect(e.slotIndex, equals(5));
        expect(e.mealType, equals('lunch'));
      }
    });
  });

  group('requirePositiveForTesting validation', () {
    test('throws MealPlanApplyException when value is null', () {
      expect(
        () => requirePositiveForTesting(
          null,
          'servingSize',
          userId: 'user-1',
          templateId: 'template-1',
          dayIndex: 1,
          slotIndex: 0,
          mealType: 'breakfast',
        ),
        throwsA(isA<MealPlanApplyException>()),
      );
    });

    test('throws MealPlanApplyException when value is zero', () {
      expect(
        () => requirePositiveForTesting(
          0,
          'servingSize',
          userId: 'user-1',
          templateId: 'template-1',
          dayIndex: 1,
          slotIndex: 0,
          mealType: 'breakfast',
        ),
        throwsA(isA<MealPlanApplyException>()),
      );
    });

    test('throws MealPlanApplyException when value is negative', () {
      expect(
        () => requirePositiveForTesting(
          -1.5,
          'servingSize',
          userId: 'user-1',
          templateId: 'template-1',
          dayIndex: 1,
          slotIndex: 0,
          mealType: 'breakfast',
        ),
        throwsA(isA<MealPlanApplyException>()),
      );
    });

    test('returns value when positive', () {
      final result = requirePositiveForTesting(
        2.5,
        'servingSize',
        userId: 'user-1',
        templateId: 'template-1',
        dayIndex: 1,
        slotIndex: 0,
        mealType: 'breakfast',
      );
      expect(result, equals(2.5));
    });

    test('exception message contains full context when null', () {
      try {
        requirePositiveForTesting(
          null,
          'servingSize',
          userId: 'user-1',
          templateId: 'template-1',
          dayIndex: 2,
          slotIndex: 5,
          mealType: 'lunch',
        );
        fail('Should have thrown MealPlanApplyException');
      } on MealPlanApplyException catch (e) {
        expect(e.toString(), contains('MealSlot has no servingSize'));
        expect(e.toString(), contains('template-1'));
        expect(e.toString(), contains('dayIndex=2'));
        expect(e.toString(), contains('slotIndex=5'));
        expect(e.templateId, equals('template-1'));
        expect(e.dayIndex, equals(2));
        expect(e.slotIndex, equals(5));
      }
    });

    test('exception message contains value when invalid (non-positive)', () {
      try {
        requirePositiveForTesting(
          -2.0,
          'servingSize',
          userId: 'user-1',
          templateId: 'template-1',
          dayIndex: 1,
          slotIndex: 0,
          mealType: 'breakfast',
        );
        fail('Should have thrown MealPlanApplyException');
      } on MealPlanApplyException catch (e) {
        expect(e.toString(), contains('must be positive'));
        expect(e.toString(), contains('-2.0'));
        expect(e.details, isNotNull);
        expect(e.details!['value'], equals(-2.0));
      }
    });
  });

  group('MealPlanApplyException', () {
    test('toString includes all fields', () {
      final exception = MealPlanApplyException(
        'Test message',
        userId: 'user-1',
        templateId: 'template-1',
        dayIndex: 2,
        slotIndex: 3,
        mealType: 'dinner',
        details: {'key': 'value'},
      );

      final str = exception.toString();
      expect(str, contains('Test message'));
      expect(str, contains('user-1'));
      expect(str, contains('template-1'));
      expect(str, contains('dayIndex=2'));
      expect(str, contains('slotIndex=3'));
      expect(str, contains('mealType=dinner'));
      expect(str, contains('details'));
    });

    test('toString works without details', () {
      final exception = MealPlanApplyException(
        'Test message',
        userId: 'user-1',
        templateId: 'template-1',
        dayIndex: 1,
        slotIndex: 0,
        mealType: 'breakfast',
      );

      final str = exception.toString();
      expect(str, contains('Test message'));
      expect(str, isNot(contains('details:')));
    });
  });
}

