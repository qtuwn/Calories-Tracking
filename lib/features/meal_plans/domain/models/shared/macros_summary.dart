/// Value object representing macro nutrient summary
/// 
/// Used for day totals, plan totals, etc.
class MacrosSummary {
  final double calories;
  final double protein;
  final double carb;
  final double fat;

  const MacrosSummary({
    required this.calories,
    required this.protein,
    required this.carb,
    required this.fat,
  });

  /// Create empty summary (all zeros)
  const MacrosSummary.empty()
      : calories = 0.0,
        protein = 0.0,
        carb = 0.0,
        fat = 0.0;

  /// Add another summary to this one
  MacrosSummary operator +(MacrosSummary other) {
    return MacrosSummary(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carb: carb + other.carb,
      fat: fat + other.fat,
    );
  }

  /// Create a copy with modified fields
  MacrosSummary copyWith({
    double? calories,
    double? protein,
    double? carb,
    double? fat,
  }) {
    return MacrosSummary(
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carb: carb ?? this.carb,
      fat: fat ?? this.fat,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MacrosSummary &&
        other.calories == calories &&
        other.protein == protein &&
        other.carb == carb &&
        other.fat == fat;
  }

  @override
  int get hashCode {
    return Object.hash(calories, protein, carb, fat);
  }
}

