import 'package:flutter/material.dart';

/// Enum representing quick-log workout types available on the Home screen.
/// 
/// Each workout type corresponds to a sport activity chip that users can tap
/// to quickly log a manual workout session without browsing the full exercise catalog.
enum WorkoutType {
  running('running'),
  cycling('cycling'),
  badminton('badminton'),
  yoga('yoga'),
  other('other');

  final String value;
  const WorkoutType(this.value);

  /// Display name in Vietnamese
  String get displayName {
    switch (this) {
      case WorkoutType.running:
        return 'Chạy bộ';
      case WorkoutType.cycling:
        return 'Đạp xe';
      case WorkoutType.badminton:
        return 'Cầu lông';
      case WorkoutType.yoga:
        return 'Yoga';
      case WorkoutType.other:
        return 'Khác';
    }
  }

  /// Icon for the workout type
  IconData get icon {
    switch (this) {
      case WorkoutType.running:
        return Icons.directions_run;
      case WorkoutType.cycling:
        return Icons.directions_bike;
      case WorkoutType.badminton:
        return Icons.sports_tennis;
      case WorkoutType.yoga:
        return Icons.self_improvement;
      case WorkoutType.other:
        return Icons.fitness_center;
    }
  }

  /// Default MET (Metabolic Equivalent of Task) value for calorie estimation.
  /// 
  /// These are moderate-intensity default values used when user doesn't
  /// specify intensity. For more precise tracking, users should use the
  /// full exercise catalog from ExerciseListScreen.
  /// 
  /// Reference: Compendium of Physical Activities
  double get defaultMET {
    switch (this) {
      case WorkoutType.running:
        return 8.0; // Running at ~8 km/h (moderate pace)
      case WorkoutType.cycling:
        return 7.5; // Cycling at ~20 km/h (moderate pace)
      case WorkoutType.badminton:
        return 5.5; // Badminton, social singles/doubles
      case WorkoutType.yoga:
        return 2.5; // Hatha yoga
      case WorkoutType.other:
        return 5.0; // General moderate-intensity exercise
    }
  }

  /// Calculate estimated calories burned based on MET formula.
  /// 
  /// Formula: MET * 3.5 * weight (kg) / 200 * minutes
  /// 
  /// This is a simplified estimation. For more accurate tracking,
  /// use the full exercise catalog which may have distance-based
  /// or level-based calculations.
  double calculateCalories({
    required double weightKg,
    required double durationMinutes,
  }) {
    if (weightKg <= 0 || durationMinutes <= 0) return 0.0;
    return (defaultMET * 3.5 * weightKg / 200) * durationMinutes;
  }

  /// Parse WorkoutType from string value
  static WorkoutType fromString(String? value) {
    return WorkoutType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => WorkoutType.other,
    );
  }
}

