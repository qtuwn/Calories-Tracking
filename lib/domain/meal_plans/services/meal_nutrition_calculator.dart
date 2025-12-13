import '../user_meal_plan_repository.dart' show MealItem;
import '../explore_meal_plan.dart' show MealSlot;

/// Typed exception for nutrition calculation errors
/// 
/// Includes full context for debugging and error reporting.
class MealNutritionException implements Exception {
  final String message;
  final String? planId;
  final String? userId;
  final String? templateId;
  final int? dayIndex;
  final String? mealId;
  final int? slotIndex;
  final String? mealType;
  final Map<String, dynamic>? details;

  MealNutritionException(
    this.message, {
    this.planId,
    this.userId,
    this.templateId,
    this.dayIndex,
    this.mealId,
    this.slotIndex,
    this.mealType,
    this.details,
  });

  @override
  String toString() {
    final parts = <String>['MealNutritionException: $message'];
    if (planId != null) parts.add('planId=$planId');
    if (userId != null) parts.add('userId=$userId');
    if (templateId != null) parts.add('templateId=$templateId');
    if (dayIndex != null) parts.add('dayIndex=$dayIndex');
    if (mealId != null) parts.add('mealId=$mealId');
    if (slotIndex != null) parts.add('slotIndex=$slotIndex');
    if (mealType != null) parts.add('mealType=$mealType');
    if (details != null && details!.isNotEmpty) {
      parts.add('details=$details');
    }
    return parts.join(', ');
  }
}

/// Value object representing nutrition totals
/// 
/// Immutable, validated at construction.
class MealNutrition {
  final double calories;
  final double protein;
  final double carb;
  final double fat;

  const MealNutrition({
    required this.calories,
    required this.protein,
    required this.carb,
    required this.fat,
  }) : assert(calories >= 0, 'calories must be non-negative, got $calories'),
       assert(protein >= 0, 'protein must be non-negative, got $protein'),
       assert(carb >= 0, 'carb must be non-negative, got $carb'),
       assert(fat >= 0, 'fat must be non-negative, got $fat');

  /// Empty nutrition (all zeros)
  static const MealNutrition empty = MealNutrition(
    calories: 0.0,
    protein: 0.0,
    carb: 0.0,
    fat: 0.0,
  );

  /// Convert to map for serialization
  Map<String, double> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carb': carb,
      'fat': fat,
    };
  }

  /// Add another nutrition value (returns new instance)
  MealNutrition add(MealNutrition other) {
    return MealNutrition(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carb: carb + other.carb,
      fat: fat + other.fat,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealNutrition &&
          runtimeType == other.runtimeType &&
          calories == other.calories &&
          protein == other.protein &&
          carb == other.carb &&
          fat == other.fat;

  @override
  int get hashCode => Object.hash(calories, protein, carb, fat);
}

/// Pure domain service for nutrition calculations
/// 
/// All nutrition math must go through this service.
/// No Flutter, no Firestore dependencies.
/// Static methods only - no instance state.
class MealNutritionCalculator {
  MealNutritionCalculator._(); // Prevent instantiation

  /// Validate that a value is non-negative
  static void requireNonNegative(
    double value, {
    required String field,
    String? planId,
    String? userId,
    String? templateId,
    int? dayIndex,
    String? mealId,
    int? slotIndex,
    String? mealType,
  }) {
    if (value < 0) {
      throw MealNutritionException(
        'Invalid $field: must be non-negative, got $value',
        planId: planId,
        userId: userId,
        templateId: templateId,
        dayIndex: dayIndex,
        mealId: mealId,
        slotIndex: slotIndex,
        mealType: mealType,
        details: {'field': field, 'value': value},
      );
    }
  }

  /// Validate that a value is positive (> 0)
  static void requirePositive(
    double value, {
    required String field,
    String? planId,
    String? userId,
    String? templateId,
    int? dayIndex,
    String? mealId,
    int? slotIndex,
    String? mealType,
  }) {
    if (value <= 0) {
      throw MealNutritionException(
        'Invalid $field: must be positive, got $value',
        planId: planId,
        userId: userId,
        templateId: templateId,
        dayIndex: dayIndex,
        mealId: mealId,
        slotIndex: slotIndex,
        mealType: mealType,
        details: {'field': field, 'value': value},
      );
    }
  }

  /// Compute nutrition from a single MealItem
  /// 
  /// Validates all fields and returns normalized MealNutrition.
  /// Throws MealNutritionException if validation fails.
  static MealNutrition computeFromMealItem(
    MealItem item, {
    String? planId,
    String? userId,
    int? dayIndex,
  }) {
    // Validate servingSize > 0
    requirePositive(
      item.servingSize,
      field: 'servingSize',
      planId: planId,
      userId: userId,
      dayIndex: dayIndex,
      mealId: item.id,
      mealType: item.mealType,
    );

    // Validate macros >= 0
    requireNonNegative(
      item.calories,
      field: 'calories',
      planId: planId,
      userId: userId,
      dayIndex: dayIndex,
      mealId: item.id,
      mealType: item.mealType,
    );

    requireNonNegative(
      item.protein,
      field: 'protein',
      planId: planId,
      userId: userId,
      dayIndex: dayIndex,
      mealId: item.id,
      mealType: item.mealType,
    );

    requireNonNegative(
      item.carb,
      field: 'carb',
      planId: planId,
      userId: userId,
      dayIndex: dayIndex,
      mealId: item.id,
      mealType: item.mealType,
    );

    requireNonNegative(
      item.fat,
      field: 'fat',
      planId: planId,
      userId: userId,
      dayIndex: dayIndex,
      mealId: item.id,
      mealType: item.mealType,
    );

    return MealNutrition(
      calories: item.calories,
      protein: item.protein,
      carb: item.carb,
      fat: item.fat,
    );
  }

  /// Compute nutrition from a single MealSlot
  /// 
  /// Validates all fields and returns normalized MealNutrition.
  /// Throws MealNutritionException if validation fails.
  static MealNutrition computeFromMealSlot(
    MealSlot slot, {
    String? planId,
    String? userId,
    String? templateId,
    int? dayIndex,
    int? slotIndex,
  }) {
    // Validate servingSize > 0
    requirePositive(
      slot.servingSize,
      field: 'servingSize',
      planId: planId,
      userId: userId,
      templateId: templateId,
      dayIndex: dayIndex,
      mealId: slot.id,
      slotIndex: slotIndex,
      mealType: slot.mealType,
    );

    // Validate macros >= 0
    requireNonNegative(
      slot.calories,
      field: 'calories',
      planId: planId,
      userId: userId,
      templateId: templateId,
      dayIndex: dayIndex,
      mealId: slot.id,
      slotIndex: slotIndex,
      mealType: slot.mealType,
    );

    requireNonNegative(
      slot.protein,
      field: 'protein',
      planId: planId,
      userId: userId,
      templateId: templateId,
      dayIndex: dayIndex,
      mealId: slot.id,
      slotIndex: slotIndex,
      mealType: slot.mealType,
    );

    requireNonNegative(
      slot.carb,
      field: 'carb',
      planId: planId,
      userId: userId,
      templateId: templateId,
      dayIndex: dayIndex,
      mealId: slot.id,
      slotIndex: slotIndex,
      mealType: slot.mealType,
    );

    requireNonNegative(
      slot.fat,
      field: 'fat',
      planId: planId,
      userId: userId,
      templateId: templateId,
      dayIndex: dayIndex,
      mealId: slot.id,
      slotIndex: slotIndex,
      mealType: slot.mealType,
    );

    return MealNutrition(
      calories: slot.calories,
      protein: slot.protein,
      carb: slot.carb,
      fat: slot.fat,
    );
  }

  /// Sum nutrition from multiple MealItems
  /// 
  /// Validates each meal and computes totals.
  /// Throws MealNutritionException if any meal is invalid (includes mealId in context).
  static MealNutrition sumMeals(
    Iterable<MealItem> meals, {
    String? planId,
    String? userId,
    int? dayIndex,
  }) {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarb = 0.0;
    double totalFat = 0.0;

    for (final meal in meals) {
      try {
        final nutrition = computeFromMealItem(
          meal,
          planId: planId,
          userId: userId,
          dayIndex: dayIndex,
        );
        totalCalories += nutrition.calories;
        totalProtein += nutrition.protein;
        totalCarb += nutrition.carb;
        totalFat += nutrition.fat;
      } catch (e) {
        // Re-throw with mealId context if not already MealNutritionException
        if (e is MealNutritionException) {
          rethrow;
        }
        throw MealNutritionException(
          'Failed to compute nutrition for meal: $e',
          planId: planId,
          userId: userId,
          dayIndex: dayIndex,
          mealId: meal.id,
          mealType: meal.mealType,
        );
      }
    }

    return MealNutrition(
      calories: totalCalories,
      protein: totalProtein,
      carb: totalCarb,
      fat: totalFat,
    );
  }

  /// Sum nutrition from multiple MealSlots
  /// 
  /// Validates each slot and computes totals.
  /// Throws MealNutritionException if any slot is invalid (includes slotIndex in context).
  static MealNutrition sumMealSlots(
    Iterable<MealSlot> slots, {
    String? planId,
    String? userId,
    String? templateId,
    int? dayIndex,
  }) {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarb = 0.0;
    double totalFat = 0.0;

    int slotIndex = 0;
    for (final slot in slots) {
      try {
        final nutrition = computeFromMealSlot(
          slot,
          planId: planId,
          userId: userId,
          templateId: templateId,
          dayIndex: dayIndex,
          slotIndex: slotIndex,
        );
        totalCalories += nutrition.calories;
        totalProtein += nutrition.protein;
        totalCarb += nutrition.carb;
        totalFat += nutrition.fat;
      } catch (e) {
        // Re-throw with slotIndex context if not already MealNutritionException
        if (e is MealNutritionException) {
          rethrow;
        }
        throw MealNutritionException(
          'Failed to compute nutrition for slot: $e',
          planId: planId,
          userId: userId,
          templateId: templateId,
          dayIndex: dayIndex,
          mealId: slot.id,
          slotIndex: slotIndex,
          mealType: slot.mealType,
        );
      }
      slotIndex++;
    }

    return MealNutrition(
      calories: totalCalories,
      protein: totalProtein,
      carb: totalCarb,
      fat: totalFat,
    );
  }

  /// Assert that expected and actual totals match within epsilon
  /// 
  /// Throws MealNutritionException if mismatch detected.
  static void assertTotalsMatch({
    required MealNutrition expected,
    required MealNutrition actual,
    double epsilon = 0.0001,
    String? planId,
    String? userId,
    String? templateId,
    int? dayIndex,
  }) {
    final caloriesDiff = (expected.calories - actual.calories).abs();
    final proteinDiff = (expected.protein - actual.protein).abs();
    final carbDiff = (expected.carb - actual.carb).abs();
    final fatDiff = (expected.fat - actual.fat).abs();

    if (caloriesDiff > epsilon ||
        proteinDiff > epsilon ||
        carbDiff > epsilon ||
        fatDiff > epsilon) {
      throw MealNutritionException(
        'Totals mismatch: expected=$expected, actual=$actual',
        planId: planId,
        userId: userId,
        templateId: templateId,
        dayIndex: dayIndex,
        details: {
          'expected': expected.toMap(),
          'actual': actual.toMap(),
          'differences': {
            'calories': caloriesDiff,
            'protein': proteinDiff,
            'carb': carbDiff,
            'fat': fatDiff,
          },
        },
      );
    }
  }
}

