/// Activity entity - represents a physical activity
/// 
/// This is a pure domain model with no dependencies on Flutter or Firebase.
class Activity {
  final String id;
  final String name;
  final ActivityCategory category;
  final double met; // Metabolic Equivalent of Task
  final ActivityIntensity intensity;
  final String? description;
  final String? iconName;
  final String? iconUrl; // Cloudinary URL for icon image
  final String? coverUrl; // Cloudinary URL for cover image
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt; // Soft delete timestamp

  const Activity({
    required this.id,
    required this.name,
    required this.category,
    required this.met,
    required this.intensity,
    this.description,
    this.iconName,
    this.iconUrl,
    this.coverUrl,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  /// Create a copy with updated fields
  Activity copyWith({
    String? id,
    String? name,
    ActivityCategory? category,
    double? met,
    ActivityIntensity? intensity,
    String? description,
    String? iconName,
    String? iconUrl,
    String? coverUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      met: met ?? this.met,
      intensity: intensity ?? this.intensity,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      iconUrl: iconUrl ?? this.iconUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Check if activity is deleted (soft delete)
  bool get isDeleted => deletedAt != null;

  /// Calculate calories burned per minute for a given weight (kg)
  /// Formula: MET × weight (kg) × 0.0175 = kcal/min
  double calculateCaloriesPerMinute(double weightKg) {
    return met * weightKg * 0.0175;
  }

  /// Calculate total calories burned
  /// Formula: MET × weight (kg) × 0.0175 × duration (minutes)
  double calculateTotalCalories(double weightKg, double durationMinutes) {
    return calculateCaloriesPerMinute(weightKg) * durationMinutes;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Activity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Activity(id: $id, name: $name, category: $category, met: $met)';
}

/// Activity category enum
enum ActivityCategory {
  cardio,
  strength,
  flexibility,
  sports,
  daily,
  other;

  String get displayName {
    switch (this) {
      case ActivityCategory.cardio:
        return 'Cardio';
      case ActivityCategory.strength:
        return 'Strength';
      case ActivityCategory.flexibility:
        return 'Flexibility';
      case ActivityCategory.sports:
        return 'Sports';
      case ActivityCategory.daily:
        return 'Daily Activities';
      case ActivityCategory.other:
        return 'Other';
    }
  }

  static ActivityCategory fromString(String? value) {
    return ActivityCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ActivityCategory.other,
    );
  }
}

/// Activity intensity level
enum ActivityIntensity {
  light, // MET < 3
  moderate, // MET 3-6
  vigorous; // MET > 6

  String get displayName {
    switch (this) {
      case ActivityIntensity.light:
        return 'Light';
      case ActivityIntensity.moderate:
        return 'Moderate';
      case ActivityIntensity.vigorous:
        return 'Vigorous';
    }
  }

  static ActivityIntensity fromMet(double met) {
    if (met < 3) return ActivityIntensity.light;
    if (met <= 6) return ActivityIntensity.moderate;
    return ActivityIntensity.vigorous;
  }

  static ActivityIntensity fromString(String? value) {
    return ActivityIntensity.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ActivityIntensity.moderate,
    );
  }
}

