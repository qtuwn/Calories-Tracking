import 'package:flutter_test/flutter_test.dart';
import 'package:calories_app/features/meal_plans/domain/services/kcal_calculator.dart';
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';
import 'package:calories_app/domain/profile/profile.dart';

void main() {
  group('KcalCalculator', () {
    group('calculateDeviation', () {
      test('returns positive deviation when actual > target', () {
        expect(KcalCalculator.calculateDeviation(2000, 1800), 200);
      });

      test('returns negative deviation when actual < target', () {
        expect(KcalCalculator.calculateDeviation(1500, 1800), -300);
      });

      test('returns zero when actual equals target', () {
        expect(KcalCalculator.calculateDeviation(1800, 1800), 0);
      });
    });

    group('calculatePercentage', () {
      test('returns positive percentage when actual > target', () {
        final result = KcalCalculator.calculatePercentage(2000, 1800);
        expect(result, closeTo(11.11, 0.01));
      });

      test('returns negative percentage when actual < target', () {
        final result = KcalCalculator.calculatePercentage(1500, 1800);
        expect(result, closeTo(-16.67, 0.01));
      });

      test('returns zero when actual equals target', () {
        expect(KcalCalculator.calculatePercentage(1800, 1800), 0.0);
      });

      test('returns zero when target is zero', () {
        expect(KcalCalculator.calculatePercentage(2000, 0), 0.0);
      });
    });

    group('calculateRatio', () {
      test('returns correct ratio for positive deviation', () {
        final result = KcalCalculator.calculateRatio(2000, 1800);
        expect(result, closeTo(0.111, 0.001));
      });

      test('returns correct ratio for negative deviation', () {
        final result = KcalCalculator.calculateRatio(1500, 1800);
        expect(result, closeTo(0.167, 0.001));
      });

      test('returns zero when actual equals target', () {
        expect(KcalCalculator.calculateRatio(1800, 1800), 0.0);
      });

      test('returns zero when target is zero', () {
        expect(KcalCalculator.calculateRatio(2000, 0), 0.0);
      });
    });

    group('getDailyCalorieRangeForGoal', () {
      final profileWithTDEE = Profile(
        tdee: 2000.0,
        targetKcal: 1800.0,
      );

      test('returns correct range for loseWeight goal', () {
        final range = KcalCalculator.getDailyCalorieRangeForGoal(
          profileWithTDEE,
          MealPlanGoalType.loseWeight,
        );

        expect(range, isNotNull);
        expect(range!['min'], 1500.0); // 2000 - 500, clamped to 1200
        expect(range['max'], 1800.0); // 2000 - 200
      });

      test('returns correct range for loseFat goal', () {
        final range = KcalCalculator.getDailyCalorieRangeForGoal(
          profileWithTDEE,
          MealPlanGoalType.loseFat,
        );

        expect(range, isNotNull);
        expect(range!['min'], 1500.0);
        expect(range['max'], 1800.0);
      });

      test('returns correct range for muscleGain goal', () {
        final range = KcalCalculator.getDailyCalorieRangeForGoal(
          profileWithTDEE,
          MealPlanGoalType.muscleGain,
        );

        expect(range, isNotNull);
        expect(range!['min'], 2200.0); // 2000 + 200
        expect(range['max'], 2500.0); // 2000 + 500
      });

      test('returns correct range for gainWeight goal', () {
        final range = KcalCalculator.getDailyCalorieRangeForGoal(
          profileWithTDEE,
          MealPlanGoalType.gainWeight,
        );

        expect(range, isNotNull);
        expect(range!['min'], 2200.0);
        expect(range['max'], 2500.0);
      });

      test('returns correct range for maintain goal', () {
        final range = KcalCalculator.getDailyCalorieRangeForGoal(
          profileWithTDEE,
          MealPlanGoalType.maintain,
        );

        expect(range, isNotNull);
        expect(range!['min'], 1900.0); // 2000 - 100
        expect(range['max'], 2100.0); // 2000 + 100
      });

      test('returns correct range for maintainWeight goal', () {
        final range = KcalCalculator.getDailyCalorieRangeForGoal(
          profileWithTDEE,
          MealPlanGoalType.maintainWeight,
        );

        expect(range, isNotNull);
        expect(range!['min'], 1900.0);
        expect(range['max'], 2100.0);
      });

      test('returns correct range for vegan goal', () {
        final range = KcalCalculator.getDailyCalorieRangeForGoal(
          profileWithTDEE,
          MealPlanGoalType.vegan,
        );

        expect(range, isNotNull);
        expect(range!['min'], 1900.0); // 2000 - 100
        expect(range['max'], 2100.0); // 2000 + 100
      });

      test('returns correct range for other goal', () {
        final range = KcalCalculator.getDailyCalorieRangeForGoal(
          profileWithTDEE,
          MealPlanGoalType.other,
        );

        expect(range, isNotNull);
        expect(range!['min'], 1900.0);
        expect(range['max'], 2100.0);
      });

      test('clamps minimum to 1200 for loseWeight when TDEE is low', () {
        final lowTDEEProfile = Profile(tdee: 1300.0);
        final range = KcalCalculator.getDailyCalorieRangeForGoal(
          lowTDEEProfile,
          MealPlanGoalType.loseWeight,
        );

        expect(range, isNotNull);
        expect(range!['min'], 1200.0); // Clamped to minimum
        expect(range['max'], 1100.0); // 1300 - 200
      });

      test('returns null when profile is null', () {
        final range = KcalCalculator.getDailyCalorieRangeForGoal(
          null,
          MealPlanGoalType.maintain,
        );
        expect(range, isNull);
      });

      test('returns null when TDEE is null', () {
        final profileWithoutTDEE = Profile(tdee: null);
        final range = KcalCalculator.getDailyCalorieRangeForGoal(
          profileWithoutTDEE,
          MealPlanGoalType.maintain,
        );
        expect(range, isNull);
      });

      test('returns null when TDEE is zero or negative', () {
        final invalidProfile = Profile(tdee: 0.0);
        final range = KcalCalculator.getDailyCalorieRangeForGoal(
          invalidProfile,
          MealPlanGoalType.maintain,
        );
        expect(range, isNull);
      });
    });

    group('getDailyCalorieLimitForGoal', () {
      final profileWithTDEE = Profile(tdee: 2000.0);

      test('returns max value from range for loseWeight', () {
        final limit = KcalCalculator.getDailyCalorieLimitForGoal(
          profileWithTDEE,
          MealPlanGoalType.loseWeight,
        );
        expect(limit, 1800.0);
      });

      test('returns max value from range for muscleGain', () {
        final limit = KcalCalculator.getDailyCalorieLimitForGoal(
          profileWithTDEE,
          MealPlanGoalType.muscleGain,
        );
        expect(limit, 2500.0);
      });

      test('returns null when profile is invalid', () {
        final limit = KcalCalculator.getDailyCalorieLimitForGoal(
          null,
          MealPlanGoalType.maintain,
        );
        expect(limit, isNull);
      });
    });

    group('getDailyCalorieMinimumForGoal', () {
      final profileWithTDEE = Profile(tdee: 2000.0);

      test('returns min value from range for loseWeight', () {
        final minimum = KcalCalculator.getDailyCalorieMinimumForGoal(
          profileWithTDEE,
          MealPlanGoalType.loseWeight,
        );
        expect(minimum, 1500.0);
      });

      test('returns min value from range for muscleGain', () {
        final minimum = KcalCalculator.getDailyCalorieMinimumForGoal(
          profileWithTDEE,
          MealPlanGoalType.muscleGain,
        );
        expect(minimum, 2200.0);
      });
    });

    group('isValidCalorieForGoal', () {
      final profileWithTDEE = Profile(tdee: 2000.0);

      test('returns true for calories within range', () {
        final isValid = KcalCalculator.isValidCalorieForGoal(
          profileWithTDEE,
          MealPlanGoalType.maintain,
          2050, // Within 1900-2100 range
        );
        expect(isValid, isTrue);
      });

      test('returns false for calories below minimum', () {
        final isValid = KcalCalculator.isValidCalorieForGoal(
          profileWithTDEE,
          MealPlanGoalType.maintain,
          1800, // Below 1900 minimum
        );
        expect(isValid, isFalse);
      });

      test('returns false for calories above maximum', () {
        final isValid = KcalCalculator.isValidCalorieForGoal(
          profileWithTDEE,
          MealPlanGoalType.maintain,
          2200, // Above 2100 maximum
        );
        expect(isValid, isFalse);
      });

      test('returns true for reasonable values when profile is null', () {
        final isValid = KcalCalculator.isValidCalorieForGoal(
          null,
          MealPlanGoalType.maintain,
          2000, // Within 1200-4000 default range
        );
        expect(isValid, isTrue);
      });

      test('returns false for values outside default range when profile is null', () {
        final isValid = KcalCalculator.isValidCalorieForGoal(
          null,
          MealPlanGoalType.maintain,
          1000, // Below 1200 default minimum
        );
        expect(isValid, isFalse);
      });
    });

    group('getCalorieValidationError', () {
      final profileWithTDEE = Profile(tdee: 2000.0, targetKcal: 1800.0);

      test('returns null for valid calories', () {
        final error = KcalCalculator.getCalorieValidationError(
          profileWithTDEE,
          MealPlanGoalType.maintain,
          2050, // Within range
        );
        expect(error, isNull);
      });

      test('returns error message for calories below minimum', () {
        final error = KcalCalculator.getCalorieValidationError(
          profileWithTDEE,
          MealPlanGoalType.maintain,
          1800, // Below minimum
        );
        expect(error, isNotNull);
        expect(error, contains('quá thấp'));
      });

      test('returns error message for calories above maximum', () {
        final error = KcalCalculator.getCalorieValidationError(
          profileWithTDEE,
          MealPlanGoalType.maintain,
          2200, // Above maximum
        );
        expect(error, isNotNull);
        expect(error, contains('quá cao'));
      });

      test('returns error when profile is null', () {
        final error = KcalCalculator.getCalorieValidationError(
          null,
          MealPlanGoalType.maintain,
          2000,
        );
        expect(error, isNotNull);
        expect(error, contains('hoàn thành hồ sơ'));
      });

      test('returns error when TDEE is null', () {
        final profileWithoutTDEE = Profile(tdee: null);
        final error = KcalCalculator.getCalorieValidationError(
          profileWithoutTDEE,
          MealPlanGoalType.maintain,
          2000,
        );
        expect(error, isNotNull);
        expect(error, contains('hoàn thành hồ sơ'));
      });
    });
  });
}

