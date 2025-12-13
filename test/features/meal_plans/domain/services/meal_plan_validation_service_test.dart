import 'package:flutter_test/flutter_test.dart';
import 'package:calories_app/features/meal_plans/domain/services/meal_plan_validation_service.dart';
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';
import 'package:calories_app/domain/profile/profile.dart';

void main() {
  group('MealPlanValidationService', () {
    group('validateKcalDeviation', () {
      test('returns valid result when deviation is within threshold', () {
        final result = MealPlanValidationService.validateKcalDeviation(
          actualKcal: 1800,
          targetKcal: 2000,
          threshold: 0.15,
        );

        expect(result.isValid, isTrue);
        expect(result.isWarning, isFalse);
        expect(result.deviation, -200);
        expect(result.percentage, closeTo(-10.0, 0.1));
        expect(result.ratio, closeTo(0.1, 0.01));
      });

      test('returns warning when deviation exceeds threshold', () {
        final result = MealPlanValidationService.validateKcalDeviation(
          actualKcal: 1500,
          targetKcal: 2000,
          threshold: 0.15,
        );

        expect(result.isValid, isFalse);
        expect(result.isWarning, isTrue);
        expect(result.deviation, -500);
        expect(result.percentage, closeTo(-25.0, 0.1));
        expect(result.ratio, closeTo(0.25, 0.01));
      });

      test('returns warning for positive deviation exceeding threshold', () {
        final result = MealPlanValidationService.validateKcalDeviation(
          actualKcal: 2500,
          targetKcal: 2000,
          threshold: 0.15,
        );

        expect(result.isValid, isFalse);
        expect(result.isWarning, isTrue);
        expect(result.deviation, 500);
        expect(result.percentage, closeTo(25.0, 0.1));
        expect(result.ratio, closeTo(0.25, 0.01));
      });

      test('uses custom threshold when provided', () {
        final result = MealPlanValidationService.validateKcalDeviation(
          actualKcal: 1800,
          targetKcal: 2000,
          threshold: 0.05, // Stricter threshold
        );

        expect(result.isValid, isFalse);
        expect(result.isWarning, isTrue);
        expect(result.ratio, closeTo(0.1, 0.01));
      });

      test('handles exact match correctly', () {
        final result = MealPlanValidationService.validateKcalDeviation(
          actualKcal: 2000,
          targetKcal: 2000,
        );

        expect(result.isValid, isTrue);
        expect(result.isWarning, isFalse);
        expect(result.deviation, 0);
        expect(result.percentage, 0.0);
        expect(result.ratio, 0.0);
      });
    });

    group('validateMealCount', () {
      test('returns true for valid meal counts', () {
        expect(MealPlanValidationService.validateMealCount(3), isTrue);
        expect(MealPlanValidationService.validateMealCount(4), isTrue);
        expect(MealPlanValidationService.validateMealCount(5), isTrue);
        expect(MealPlanValidationService.validateMealCount(6), isTrue);
      });

      test('returns false for meal counts below minimum', () {
        expect(MealPlanValidationService.validateMealCount(0), isFalse);
        expect(MealPlanValidationService.validateMealCount(1), isFalse);
        expect(MealPlanValidationService.validateMealCount(2), isFalse);
      });

      test('returns false for meal counts above maximum', () {
        expect(MealPlanValidationService.validateMealCount(7), isFalse);
        expect(MealPlanValidationService.validateMealCount(10), isFalse);
      });
    });

    group('validateMacros', () {
      test('returns true for valid macros', () {
        expect(
          MealPlanValidationService.validateMacros(
            protein: 100.0,
            carb: 200.0,
            fat: 50.0,
          ),
          isTrue,
        );
      });

      test('returns true for zero values', () {
        expect(
          MealPlanValidationService.validateMacros(
            protein: 0.0,
            carb: 0.0,
            fat: 0.0,
          ),
          isTrue,
        );
      });

      test('returns false for negative protein', () {
        expect(
          MealPlanValidationService.validateMacros(
            protein: -10.0,
            carb: 200.0,
            fat: 50.0,
          ),
          isFalse,
        );
      });

      test('returns false for negative carb', () {
        expect(
          MealPlanValidationService.validateMacros(
            protein: 100.0,
            carb: -20.0,
            fat: 50.0,
          ),
          isFalse,
        );
      });

      test('returns false for negative fat', () {
        expect(
          MealPlanValidationService.validateMacros(
            protein: 100.0,
            carb: 200.0,
            fat: -5.0,
          ),
          isFalse,
        );
      });
    });

    group('validateUserPlanKcal', () {
      /// Helper to build test profiles with specific TDEE and targetKcal values
      Profile _buildProfile({
        double? tdee,
        double? targetKcal,
      }) {
        return Profile(
          nickname: 'Test User',
          tdee: tdee,
          targetKcal: targetKcal,
        );
      }

      final profileWithTarget = _buildProfile(
        tdee: 2000.0,
        targetKcal: 1800.0,
      );

      test('returns valid result when plan kcal is within threshold', () {
        final result = MealPlanValidationService.validateUserPlanKcal(
          planKcal: 1900,
          profile: profileWithTarget,
          goalType: MealPlanGoalType.maintain,
        );

        expect(result.isValid, isTrue);
        expect(result.isWarning, isFalse);
      });

      test('returns warning when plan kcal exceeds threshold', () {
        final result = MealPlanValidationService.validateUserPlanKcal(
          planKcal: 1500,
          profile: profileWithTarget,
          goalType: MealPlanGoalType.maintain,
        );

        expect(result.isValid, isFalse);
        expect(result.isWarning, isTrue);
      });

      test('returns valid result when profile is null', () {
        final result = MealPlanValidationService.validateUserPlanKcal(
          planKcal: 2000,
          profile: null,
          goalType: MealPlanGoalType.maintain,
        );

        expect(result.isValid, isTrue);
        expect(result.isWarning, isFalse);
        expect(result.deviation, 0);
        expect(result.percentage, 0.0);
        expect(result.ratio, 0.0);
      });

      test('returns valid result when targetKcal is null', () {
        final profileWithoutTarget = _buildProfile(tdee: 2000.0, targetKcal: null);
        final result = MealPlanValidationService.validateUserPlanKcal(
          planKcal: 2000,
          profile: profileWithoutTarget,
          goalType: MealPlanGoalType.maintain,
        );

        expect(result.isValid, isTrue);
        expect(result.isWarning, isFalse);
      });

      test('returns valid result when targetKcal is zero or negative', () {
        final invalidProfile = _buildProfile(tdee: 2000.0, targetKcal: 0.0);
        final result = MealPlanValidationService.validateUserPlanKcal(
          planKcal: 2000,
          profile: invalidProfile,
          goalType: MealPlanGoalType.maintain,
        );

        expect(result.isValid, isTrue);
        expect(result.isWarning, isFalse);
      });

      test('uses custom threshold when provided', () {
        final result = MealPlanValidationService.validateUserPlanKcal(
          planKcal: 1900,
          profile: profileWithTarget,
          goalType: MealPlanGoalType.maintain,
          threshold: 0.05, // Stricter threshold
        );

        expect(result.isValid, isFalse);
        expect(result.isWarning, isTrue);
      });
    });
  });
}

