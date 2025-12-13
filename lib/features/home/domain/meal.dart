import 'diary_meal_item.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/meal_type.dart';

/// Model cho một bữa ăn (chứa nhiều món ăn)
class Meal {
  final MealType type;
  final List<DiaryMealItem> items;

  Meal({
    required this.type,
    List<DiaryMealItem>? items,
  }) : items = items ?? [];

  // Tính tổng dinh dưỡng của bữa ăn
  double get totalCalories =>
      items.fold(0, (sum, item) => sum + item.totalCalories);

  double get totalProtein =>
      items.fold(0, (sum, item) => sum + item.totalProtein);

  double get totalCarbs =>
      items.fold(0, (sum, item) => sum + item.totalCarbs);

  double get totalFat =>
      items.fold(0, (sum, item) => sum + item.totalFat);

  int get itemCount => items.length;

  Meal copyWith({
    MealType? type,
    List<DiaryMealItem>? items,
  }) {
    return Meal(
      type: type ?? this.type,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      type: MealType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      items: (json['items'] as List<dynamic>)
          .map((item) => DiaryMealItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

