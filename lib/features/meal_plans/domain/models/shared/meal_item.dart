/// Pure domain model for a food item in a meal
/// 
/// This is a shared model used by both user meal plans and explore templates.
/// No Firestore dependencies - mapping to/from Firestore is handled in the data layer.
class MealItem {
  final String id;
  final String mealType; // "breakfast" | "lunch" | "dinner" | "snack"
  final String foodId; // Reference to food catalog
  final double servingSize;
  final double calories;
  final double protein;
  final double carb;
  final double fat;

  const MealItem({
    required this.id,
    required this.mealType,
    required this.foodId,
    required this.servingSize,
    required this.calories,
    required this.protein,
    required this.carb,
    required this.fat,
  });

  /// Create a copy with modified fields
  MealItem copyWith({
    String? id,
    String? mealType,
    String? foodId,
    double? servingSize,
    double? calories,
    double? protein,
    double? carb,
    double? fat,
  }) {
    return MealItem(
      id: id ?? this.id,
      mealType: mealType ?? this.mealType,
      foodId: foodId ?? this.foodId,
      servingSize: servingSize ?? this.servingSize,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carb: carb ?? this.carb,
      fat: fat ?? this.fat,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MealItem &&
        other.id == id &&
        other.mealType == mealType &&
        other.foodId == foodId &&
        other.servingSize == servingSize &&
        other.calories == calories &&
        other.protein == protein &&
        other.carb == carb &&
        other.fat == fat;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      mealType,
      foodId,
      servingSize,
      calories,
      protein,
      carb,
      fat,
    );
  }
}

