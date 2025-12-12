import 'package:flutter/material.dart';
import 'package:calories_app/features/home/domain/meal_type.dart';

/// Domain service for classifying meal types based on time of day
/// 
/// Pure domain logic with no dependencies on Flutter or external services.
class MealTimeClassifier {
  /// Classify meal type based on the current time
  /// 
  /// Time ranges (using local time):
  /// - 04:00-10:59 → BREAKFAST
  /// - 11:00-12:59 → LUNCH
  /// - 13:00-16:59 → SNACK
  /// - 17:00-03:59 → DINNER (wraps over midnight)
  static MealType classifyMealType(DateTime timestamp) {
    // Convert to local time
    final localTime = timestamp.toLocal();
    final hour = localTime.hour;
    final minute = localTime.minute;
    final totalMinutes = hour * 60 + minute;

    MealType mealType;

    // Breakfast: 04:00 to 10:59 (4*60 to 10*60+59)
    if (totalMinutes >= 4 * 60 && totalMinutes <= 10 * 60 + 59) {
      mealType = MealType.breakfast;
    }
    // Lunch: 11:00 to 12:59 (11*60 to 12*60+59)
    else if (totalMinutes >= 11 * 60 && totalMinutes <= 12 * 60 + 59) {
      mealType = MealType.lunch;
    }
    // Snack: 13:00 to 16:59 (13*60 to 16*60+59)
    else if (totalMinutes >= 13 * 60 && totalMinutes <= 16 * 60 + 59) {
      mealType = MealType.snack;
    }
    // Dinner: 17:00 to 03:59 (everything else, wraps over midnight)
    // This includes: 17:00-23:59 and 00:00-03:59
    else {
      mealType = MealType.dinner;
    }

    // Debug logging
    debugPrint('[MealTimeClassifier] timestamp=$timestamp (local: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}, minutes=$totalMinutes) → $mealType');
    
    return mealType;
  }
}

