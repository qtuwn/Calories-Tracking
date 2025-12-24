/// Goal type for meal plans (unified domain enum)
/// 
/// This enum is used by both User Meal Plans and Explore Meal Plans.
/// It supports all goal types used in the system.
enum MealPlanGoalType {
  loseFat,      // Giảm mỡ (used by User Meal Plans)
  loseWeight,   // Giảm cân (used by Explore Meal Plans)
  maintainWeight, // Duy trì cân nặng (used by Explore Meal Plans)
  maintain,     // Giữ dáng (used by User Meal Plans)
  gainWeight,   // Tăng cân (used by Explore Meal Plans)
  muscleGain,   // Tăng cơ (used by both)
  vegan,        // Thuần chay (used by both)
  other;        // Khác (used by Explore Meal Plans)

  /// Get string value for storage/API
  String get value {
    switch (this) {
      case MealPlanGoalType.loseFat:
        return 'lose_fat';
      case MealPlanGoalType.loseWeight:
        return 'lose_weight';
      case MealPlanGoalType.maintainWeight:
        return 'maintain_weight';
      case MealPlanGoalType.maintain:
        return 'maintain';
      case MealPlanGoalType.gainWeight:
        return 'gain_weight';
      case MealPlanGoalType.muscleGain:
        return 'muscle_gain';
      case MealPlanGoalType.vegan:
        return 'vegan';
      case MealPlanGoalType.other:
        return 'other';
    }
  }

  /// Parse from string value (supports both old and new formats)
  static MealPlanGoalType fromString(String? value) {
    if (value == null) return MealPlanGoalType.maintain;
    
    switch (value.toLowerCase()) {
      case 'lose_fat':
      case 'losefat':
        return MealPlanGoalType.loseFat;
      case 'lose_weight':
      case 'loseweight':
        return MealPlanGoalType.loseWeight;
      case 'maintain_weight':
      case 'maintainweight':
        return MealPlanGoalType.maintainWeight;
      case 'maintain':
        return MealPlanGoalType.maintain;
      case 'gain_weight':
      case 'gainweight':
        return MealPlanGoalType.gainWeight;
      case 'muscle_gain':
      case 'musclegain':
        return MealPlanGoalType.muscleGain;
      case 'vegan':
        return MealPlanGoalType.vegan;
      case 'other':
        return MealPlanGoalType.other;
      default:
        return MealPlanGoalType.maintain;
    }
  }

  /// UI-specific display name for the goal type
  String get displayName {
    switch (this) {
      case MealPlanGoalType.loseFat:
        return 'Giảm mỡ';
      case MealPlanGoalType.loseWeight:
        return 'Giảm cân';
      case MealPlanGoalType.maintainWeight:
        return 'Duy trì cân nặng';
      case MealPlanGoalType.maintain:
        return 'Giữ dáng';
      case MealPlanGoalType.gainWeight:
        return 'Tăng cân';
      case MealPlanGoalType.muscleGain:
        return 'Tăng cơ';
      case MealPlanGoalType.vegan:
        return 'Thuần chay';
      case MealPlanGoalType.other:
        return 'Khác';
    }
  }
}

