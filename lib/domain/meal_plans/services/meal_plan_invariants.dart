import '../user_meal_plan_repository.dart' show MealItem;
import '../explore_meal_plan.dart' show MealSlot;

/// Typed exception for meal plan invariant violations
/// 
/// Includes full context for debugging and error reporting.
class MealPlanInvariantException implements Exception {
  final String message;
  final String? userId;
  final String? planId;
  final String? templateId;
  final int? dayIndex;
  final int? slotIndex;
  final String? docPath;
  final Map<String, dynamic>? details;

  MealPlanInvariantException(
    this.message, {
    this.userId,
    this.planId,
    this.templateId,
    this.dayIndex,
    this.slotIndex,
    this.docPath,
    this.details,
  });

  @override
  String toString() {
    final parts = <String>['MealPlanInvariantException: $message'];
    if (userId != null) parts.add('userId=$userId');
    if (planId != null) parts.add('planId=$planId');
    if (templateId != null) parts.add('templateId=$templateId');
    if (dayIndex != null) parts.add('dayIndex=$dayIndex');
    if (slotIndex != null) parts.add('slotIndex=$slotIndex');
    if (docPath != null) parts.add('docPath=$docPath');
    if (details != null && details!.isNotEmpty) {
      parts.add('details=$details');
    }
    return parts.join(', ');
  }
}

/// Pure domain validator for meal plan invariants
/// 
/// No Flutter, no Firestore dependencies.
/// Static methods only - no instance state.
class MealPlanInvariants {
  MealPlanInvariants._(); // Prevent instantiation

  /// Validate that a macro value is non-negative and finite
  static void validateMacroNonNegative({
    required double calories,
    required double protein,
    required double carb,
    required double fat,
    String? userId,
    String? planId,
    String? templateId,
    int? dayIndex,
    int? slotIndex,
    String? docPath,
    String? mealId,
    String? mealType,
  }) {
    // Check finiteness first
    if (!calories.isFinite) {
      throw MealPlanInvariantException(
        'calories must be finite, got $calories',
        userId: userId,
        planId: planId,
        templateId: templateId,
        dayIndex: dayIndex,
        slotIndex: slotIndex,
        docPath: docPath,
        details: {'value': calories, 'field': 'calories'},
      );
    }

    if (!protein.isFinite) {
      throw MealPlanInvariantException(
        'protein must be finite, got $protein',
        userId: userId,
        planId: planId,
        templateId: templateId,
        dayIndex: dayIndex,
        slotIndex: slotIndex,
        docPath: docPath,
        details: {'value': protein, 'field': 'protein'},
      );
    }

    if (!carb.isFinite) {
      throw MealPlanInvariantException(
        'carb must be finite, got $carb',
        userId: userId,
        planId: planId,
        templateId: templateId,
        dayIndex: dayIndex,
        slotIndex: slotIndex,
        docPath: docPath,
        details: {'value': carb, 'field': 'carb'},
      );
    }

    if (!fat.isFinite) {
      throw MealPlanInvariantException(
        'fat must be finite, got $fat',
        userId: userId,
        planId: planId,
        templateId: templateId,
        dayIndex: dayIndex,
        slotIndex: slotIndex,
        docPath: docPath,
        details: {'value': fat, 'field': 'fat'},
      );
    }

    // Check non-negativity
    if (calories < 0) {
      throw MealPlanInvariantException(
        'calories must be non-negative, got $calories',
        userId: userId,
        planId: planId,
        templateId: templateId,
        dayIndex: dayIndex,
        slotIndex: slotIndex,
        docPath: docPath,
        details: {'value': calories, 'field': 'calories'},
      );
    }

    if (protein < 0) {
      throw MealPlanInvariantException(
        'protein must be non-negative, got $protein',
        userId: userId,
        planId: planId,
        templateId: templateId,
        dayIndex: dayIndex,
        slotIndex: slotIndex,
        docPath: docPath,
        details: {'value': protein, 'field': 'protein'},
      );
    }

    if (carb < 0) {
      throw MealPlanInvariantException(
        'carb must be non-negative, got $carb',
        userId: userId,
        planId: planId,
        templateId: templateId,
        dayIndex: dayIndex,
        slotIndex: slotIndex,
        docPath: docPath,
        details: {'value': carb, 'field': 'carb'},
      );
    }

    if (fat < 0) {
      throw MealPlanInvariantException(
        'fat must be non-negative, got $fat',
        userId: userId,
        planId: planId,
        templateId: templateId,
        dayIndex: dayIndex,
        slotIndex: slotIndex,
        docPath: docPath,
        details: {'value': fat, 'field': 'fat'},
      );
    }
  }

  /// Validate a MealItem against all invariants
  /// 
  /// Throws MealPlanInvariantException if any invariant is violated.
  static void validateMealItem(
    MealItem item, {
    String? userId,
    String? planId,
    int? dayIndex,
    String? docPath,
  }) {
    // Runtime validation (throws for release too)
    if (item.foodId.trim().isEmpty) {
      throw MealPlanInvariantException(
        'foodId must be non-empty',
        userId: userId,
        planId: planId,
        dayIndex: dayIndex,
        docPath: docPath,
        details: {
          'mealId': item.id,
          'mealType': item.mealType,
          'foodId': item.foodId,
        },
      );
    }

    if (item.servingSize <= 0) {
      throw MealPlanInvariantException(
        'servingSize must be positive, got ${item.servingSize}',
        userId: userId,
        planId: planId,
        dayIndex: dayIndex,
        docPath: docPath,
        details: {
          'mealId': item.id,
          'mealType': item.mealType,
          'servingSize': item.servingSize,
        },
      );
    }

    // Check calories for NaN/Infinity and negative values
    if (!item.calories.isFinite) {
      throw MealPlanInvariantException(
        'calories must be finite, got ${item.calories}',
        userId: userId,
        planId: planId,
        dayIndex: dayIndex,
        docPath: docPath,
        details: {
          'mealId': item.id,
          'mealType': item.mealType,
          'calories': item.calories,
        },
      );
    }

    if (item.calories < 0) {
      throw MealPlanInvariantException(
        'calories must be non-negative, got ${item.calories}',
        userId: userId,
        planId: planId,
        dayIndex: dayIndex,
        docPath: docPath,
        details: {
          'mealId': item.id,
          'mealType': item.mealType,
          'calories': item.calories,
        },
      );
    }

    validateMacroNonNegative(
      calories: item.calories,
      protein: item.protein,
      carb: item.carb,
      fat: item.fat,
      userId: userId,
      planId: planId,
      dayIndex: dayIndex,
      docPath: docPath,
      mealId: item.id,
      mealType: item.mealType,
    );
  }

  /// Validate a MealSlot against all invariants
  /// 
  /// Throws MealPlanInvariantException if any invariant is violated.
  static void validateMealSlot(
    MealSlot slot, {
    String? templateId,
    int? dayIndex,
    int? slotIndex,
    String? docPath,
  }) {
    // Runtime validation (throws for release too)
    // Note: MealSlot.foodId is nullable, but if provided, must be non-empty
    if (slot.foodId != null && slot.foodId!.trim().isEmpty) {
      throw MealPlanInvariantException(
        'foodId must be null or non-empty, got empty string',
        templateId: templateId,
        dayIndex: dayIndex,
        slotIndex: slotIndex,
        docPath: docPath,
        details: {
          'slotId': slot.id,
          'mealType': slot.mealType,
          'foodId': slot.foodId,
        },
      );
    }

    if (slot.servingSize <= 0) {
      throw MealPlanInvariantException(
        'servingSize must be positive, got ${slot.servingSize}',
        templateId: templateId,
        dayIndex: dayIndex,
        slotIndex: slotIndex,
        docPath: docPath,
        details: {
          'slotId': slot.id,
          'mealType': slot.mealType,
          'servingSize': slot.servingSize,
        },
      );
    }

    validateMacroNonNegative(
      calories: slot.calories,
      protein: slot.protein,
      carb: slot.carb,
      fat: slot.fat,
      templateId: templateId,
      dayIndex: dayIndex,
      slotIndex: slotIndex,
      docPath: docPath,
      mealId: slot.id,
      mealType: slot.mealType,
    );
  }
}
