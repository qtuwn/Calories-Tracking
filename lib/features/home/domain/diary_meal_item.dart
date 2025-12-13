/// Model cho một món ăn trong bữa ăn (dành cho Diary/Home feature)
/// 
/// NOTE: This is different from the meal plan MealItem.
/// This model is used specifically for diary entries and home display.
/// For meal plans, use domain/meal_plans/user_meal_plan_repository.dart::MealItem
class DiaryMealItem {
  final String id;
  final String name;
  final double servingSize; // Khẩu phần (ví dụ: 1.5 = 1.5 phần)
  final double caloriesPer100g; // Calories trên 100g
  final double proteinPer100g; // Protein trên 100g
  final double carbsPer100g; // Carbs trên 100g
  final double fatPer100g; // Fat trên 100g
  final double gramsPerServing; // Số gram cho 1 phần ăn chuẩn

  DiaryMealItem({
    required this.id,
    required this.name,
    required this.servingSize,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.gramsPerServing = 100.0,
  });

  // Tính toán giá trị dinh dưỡng theo khẩu phần
  double get totalCalories =>
      (caloriesPer100g * gramsPerServing * servingSize) / 100;
  
  double get totalProtein =>
      (proteinPer100g * gramsPerServing * servingSize) / 100;
  
  double get totalCarbs =>
      (carbsPer100g * gramsPerServing * servingSize) / 100;
  
  double get totalFat =>
      (fatPer100g * gramsPerServing * servingSize) / 100;

  double get totalGrams => gramsPerServing * servingSize;

  DiaryMealItem copyWith({
    String? id,
    String? name,
    double? servingSize,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    double? gramsPerServing,
  }) {
    return DiaryMealItem(
      id: id ?? this.id,
      name: name ?? this.name,
      servingSize: servingSize ?? this.servingSize,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      gramsPerServing: gramsPerServing ?? this.gramsPerServing,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'servingSize': servingSize,
      'caloriesPer100g': caloriesPer100g,
      'proteinPer100g': proteinPer100g,
      'carbsPer100g': carbsPer100g,
      'fatPer100g': fatPer100g,
      'gramsPerServing': gramsPerServing,
    };
  }

  factory DiaryMealItem.fromJson(Map<String, dynamic> json) {
    return DiaryMealItem(
      id: json['id'] as String,
      name: json['name'] as String,
      servingSize: (json['servingSize'] as num).toDouble(),
      caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
      proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
      carbsPer100g: (json['carbsPer100g'] as num).toDouble(),
      fatPer100g: (json['fatPer100g'] as num).toDouble(),
      gramsPerServing: (json['gramsPerServing'] as num).toDouble(),
    );
  }
}

