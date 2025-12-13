import 'package:calories_app/features/meal_plans/domain/models/shared/macros_summary.dart';

/// Pure domain model for a day in a user's meal plan
/// 
/// Contains the day index and summary macros for that day.
/// The actual meal items are stored separately and aggregated here.
class UserMealDay {
  final String id;
  final int dayIndex; // 1...durationDays
  final MacrosSummary macros;

  const UserMealDay({
    required this.id,
    required this.dayIndex,
    required this.macros,
  });

  /// Create a copy with modified fields
  UserMealDay copyWith({
    String? id,
    int? dayIndex,
    MacrosSummary? macros,
  }) {
    return UserMealDay(
      id: id ?? this.id,
      dayIndex: dayIndex ?? this.dayIndex,
      macros: macros ?? this.macros,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserMealDay &&
        other.id == id &&
        other.dayIndex == dayIndex &&
        other.macros == macros;
  }

  @override
  int get hashCode {
    return Object.hash(id, dayIndex, macros);
  }
}

