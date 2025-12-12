/// Goal type for meal plans (pure domain model)
enum MealPlanGoalType {
  loseFat,
  muscleGain,
  vegan,
  maintain;

  /// Get string value for storage/API
  String get value {
    switch (this) {
      case MealPlanGoalType.loseFat:
        return 'lose_fat';
      case MealPlanGoalType.muscleGain:
        return 'muscle_gain';
      case MealPlanGoalType.vegan:
        return 'vegan';
      case MealPlanGoalType.maintain:
        return 'maintain';
    }
  }

  /// Parse from string value
  static MealPlanGoalType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'lose_fat':
      case 'losefat':
        return MealPlanGoalType.loseFat;
      case 'muscle_gain':
      case 'musclegain':
        return MealPlanGoalType.muscleGain;
      case 'vegan':
        return MealPlanGoalType.vegan;
      case 'maintain':
        return MealPlanGoalType.maintain;
      default:
        return MealPlanGoalType.maintain;
    }
  }

  /// UI-specific display name for the goal type
  String get displayName {
    switch (this) {
      case MealPlanGoalType.loseFat:
        return 'Giảm mỡ';
      case MealPlanGoalType.muscleGain:
        return 'Tăng cơ';
      case MealPlanGoalType.vegan:
        return 'Thuần chay';
      case MealPlanGoalType.maintain:
        return 'Giữ dáng';
    }
  }
}

/// Difficulty levels for meal plans (pure domain model)
enum MealPlanDifficulty {
  easy,
  medium,
  hard;

  /// Get string value for storage/API
  String get value {
    switch (this) {
      case MealPlanDifficulty.easy:
        return 'easy';
      case MealPlanDifficulty.medium:
        return 'medium';
      case MealPlanDifficulty.hard:
        return 'hard';
    }
  }

  /// Parse from string value
  static MealPlanDifficulty? fromString(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'easy':
        return MealPlanDifficulty.easy;
      case 'medium':
        return MealPlanDifficulty.medium;
      case 'hard':
        return MealPlanDifficulty.hard;
      default:
        return null;
    }
  }
}

