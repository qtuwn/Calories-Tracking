import 'package:calories_app/features/meal_plans/domain/models/shared/macros_summary.dart';

/// Pure domain model for a day in an explore meal plan template
/// 
/// Contains the day index and summary macros for that day in the template.
class ExploreMealDayTemplate {
  final String id;
  final int dayIndex; // 1...durationDays
  final MacrosSummary macros;

  const ExploreMealDayTemplate({
    required this.id,
    required this.dayIndex,
    required this.macros,
  });

  /// Create a copy with modified fields
  ExploreMealDayTemplate copyWith({
    String? id,
    int? dayIndex,
    MacrosSummary? macros,
  }) {
    return ExploreMealDayTemplate(
      id: id ?? this.id,
      dayIndex: dayIndex ?? this.dayIndex,
      macros: macros ?? this.macros,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExploreMealDayTemplate &&
        other.id == id &&
        other.dayIndex == dayIndex &&
        other.macros == macros;
  }

  @override
  int get hashCode {
    return Object.hash(id, dayIndex, macros);
  }
}

