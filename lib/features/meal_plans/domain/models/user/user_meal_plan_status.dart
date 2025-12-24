/// Status of a user meal plan (pure domain enum)
enum UserMealPlanStatus {
  active,
  paused,
  finished;

  /// Get string value for storage/API
  String get value {
    switch (this) {
      case UserMealPlanStatus.active:
        return 'active';
      case UserMealPlanStatus.paused:
        return 'paused';
      case UserMealPlanStatus.finished:
        return 'finished';
    }
  }

  /// Parse from string value
  static UserMealPlanStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'active':
        return UserMealPlanStatus.active;
      case 'paused':
        return UserMealPlanStatus.paused;
      case 'finished':
        return UserMealPlanStatus.finished;
      default:
        return UserMealPlanStatus.active;
    }
  }
}

/// Type of user meal plan (pure domain enum)
enum UserMealPlanType {
  template, // Copied from template
  custom; // User-created

  /// Get string value for storage/API
  String get value {
    switch (this) {
      case UserMealPlanType.template:
        return 'template';
      case UserMealPlanType.custom:
        return 'custom';
    }
  }

  /// Parse from string value
  static UserMealPlanType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'template':
        return UserMealPlanType.template;
      case 'custom':
        return UserMealPlanType.custom;
      default:
        return UserMealPlanType.template;
    }
  }
}

