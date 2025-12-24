import 'package:flutter/material.dart';

/// Pure domain enum for meal types
/// 
/// Includes UI properties for convenience in presentation layer
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  /// Get string representation for storage/API
  String get value {
    switch (this) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snack';
    }
  }

  /// Parse from string value
  static MealType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
        return MealType.snack;
      default:
        return MealType.breakfast;
    }
  }

  /// UI-specific icon for the meal type
  IconData get icon {
    switch (this) {
      case MealType.breakfast:
        return Icons.free_breakfast_outlined;
      case MealType.lunch:
        return Icons.lunch_dining_outlined;
      case MealType.dinner:
        return Icons.dinner_dining_outlined;
      case MealType.snack:
        return Icons.cookie_outlined;
    }
  }

  /// UI-specific color for the meal type
  Color get color {
    switch (this) {
      case MealType.breakfast:
        return Colors.orange.shade700;
      case MealType.lunch:
        return Colors.blue.shade700;
      case MealType.dinner:
        return Colors.purple.shade700;
      case MealType.snack:
        return Colors.green.shade700;
    }
  }

  /// UI-specific display name for the meal type
  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Bữa sáng';
      case MealType.lunch:
        return 'Bữa trưa';
      case MealType.dinner:
        return 'Bữa tối';
      case MealType.snack:
        return 'Bữa phụ';
    }
  }
}

