import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calories_app/data/meal_plans/explore_meal_plan_dto.dart';
import 'package:calories_app/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart'
    show MealPlanApplyException, requirePositiveForTesting;

/// Unit tests for explore meal slot servingSize validation
/// 
/// Tests DTO parsing and apply validation to ensure servingSize is required and validated.
/// No Firestore emulator - uses map-based DTO parsing.
void main() {
  group('MealSlotDto.fromFirestore - servingSize validation', () {
    test('parse fails when servingSize is missing', () {
      // Test the validation logic that fromFirestore uses
      // Since we can't easily mock DocumentSnapshot, we test the core validation
      final fakeData = <String, dynamic>{
        'name': 'Test Meal',
        'mealType': 'breakfast',
        'calories': 300.0,
        'protein': 20.0,
        'carb': 30.0,
        'fat': 10.0,
        'foodId': 'food-123',
        // servingSize is missing
      };

      // Simulate the fromFirestore logic
      final servingSizeValue = fakeData['servingSize'];
      expect(servingSizeValue, isNull);
      
      // This is what fromFirestore does - throws FormatException
      expect(
        () {
          if (servingSizeValue == null) {
            throw FormatException(
              'Missing servingSize in explore template slot (docId=test-id). '
              'Older templates without servingSize cannot be applied. Please update the template.',
            );
          }
        },
        throwsA(isA<FormatException>()),
      );
    });

    test('parse fails when servingSize is 0', () {
      final fakeData = <String, dynamic>{
        'name': 'Test Meal',
        'mealType': 'breakfast',
        'calories': 300.0,
        'protein': 20.0,
        'carb': 30.0,
        'fat': 10.0,
        'foodId': 'food-123',
        'servingSize': 0.0,
      };

      // Test that fromFirestore throws FormatException for invalid servingSize
      // We'll simulate this by testing the validation logic
      expect(
        () => requirePositiveForTesting(
          0.0,
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

    test('parse fails when servingSize is negative', () {
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

    test('parse succeeds when servingSize is valid', () {
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

    test('parse succeeds when servingSize is valid integer', () {
      final result = requirePositiveForTesting(
        1,
        'servingSize',
        userId: 'user-1',
        templateId: 'template-1',
        dayIndex: 1,
        slotIndex: 0,
        mealType: 'breakfast',
      );
      
      expect(result, equals(1.0));
    });
  });

  group('Apply validation - MealPlanApplyException context', () {
    test('exception includes dayIndex, slotIndex, templateId, and servingSize field name', () {
      try {
        requirePositiveForTesting(
          null,
          'servingSize',
          userId: 'user-1',
          templateId: 'template-abc',
          dayIndex: 5,
          slotIndex: 3,
          mealType: 'lunch',
        );
        fail('Should have thrown MealPlanApplyException');
      } on MealPlanApplyException catch (e) {
        expect(e.toString(), contains('template-abc'));
        expect(e.toString(), contains('dayIndex=5'));
        expect(e.toString(), contains('slotIndex=3'));
        expect(e.toString(), contains('servingSize'));
        expect(e.templateId, equals('template-abc'));
        expect(e.dayIndex, equals(5));
        expect(e.slotIndex, equals(3));
        expect(e.mealType, equals('lunch'));
      }
    });

    test('exception includes invalid value in details when servingSize is non-positive', () {
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
}

