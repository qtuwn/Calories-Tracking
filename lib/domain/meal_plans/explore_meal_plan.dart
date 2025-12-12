import 'meal_plan_goal_type.dart';

/// Explore Meal Plan domain model
/// 
/// Represents a public meal plan template that users can discover and apply.
/// This is a pure domain model with no dependencies on Flutter or Firebase.

/// Explore Meal Plan entity
class ExploreMealPlan {
  final String id;
  final String name;
  final MealPlanGoalType goalType;
  final String description;
  final int templateKcal; // Daily kcal target
  final int durationDays;
  final int mealsPerDay;
  final List<String> tags;
  final bool isFeatured;
  final bool isPublished; // Published templates are visible to users
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy; // Admin ID
  final String? difficulty; // "easy" | "medium" | "hard"

  const ExploreMealPlan({
    required this.id,
    required this.name,
    required this.goalType,
    required this.description,
    required this.templateKcal,
    required this.durationDays,
    required this.mealsPerDay,
    required this.tags,
    required this.isFeatured,
    required this.isPublished,
    required this.isEnabled,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.difficulty,
  });

  ExploreMealPlan copyWith({
    String? id,
    String? name,
    MealPlanGoalType? goalType,
    String? description,
    int? templateKcal,
    int? durationDays,
    int? mealsPerDay,
    List<String>? tags,
    bool? isFeatured,
    bool? isPublished,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? difficulty,
  }) {
    return ExploreMealPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      goalType: goalType ?? this.goalType,
      description: description ?? this.description,
      templateKcal: templateKcal ?? this.templateKcal,
      durationDays: durationDays ?? this.durationDays,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      tags: tags ?? this.tags,
      isFeatured: isFeatured ?? this.isFeatured,
      isPublished: isPublished ?? this.isPublished,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExploreMealPlan &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ExploreMealPlan(id: $id, name: $name, goalType: $goalType, kcal: $templateKcal)';

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'goalType': goalType.value,
      'description': description,
      'templateKcal': templateKcal,
      'durationDays': durationDays,
      'mealsPerDay': mealsPerDay,
      'tags': tags,
      'isFeatured': isFeatured,
      'isPublished': isPublished,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'createdBy': createdBy,
      'difficulty': difficulty,
    };
  }

  /// Create from JSON (for caching)
  factory ExploreMealPlan.fromJson(Map<String, dynamic> json) {
    return ExploreMealPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      goalType: MealPlanGoalType.fromString(json['goalType'] as String? ?? 'other'),
      description: json['description'] as String? ?? '',
      templateKcal: (json['templateKcal'] as num?)?.toInt() ?? 2000,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 7,
      mealsPerDay: (json['mealsPerDay'] as num?)?.toInt() ?? 3,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isFeatured: json['isFeatured'] as bool? ?? false,
      isPublished: json['isPublished'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
      createdBy: json['createdBy'] as String?,
      difficulty: json['difficulty'] as String?,
    );
  }
}

/// Meal Plan Day - represents a single day in a meal plan
class MealPlanDay {
  final String id;
  final int dayIndex; // 1-based index
  final double totalCalories;
  final double protein;
  final double carb;
  final double fat;

  const MealPlanDay({
    required this.id,
    required this.dayIndex,
    required this.totalCalories,
    required this.protein,
    required this.carb,
    required this.fat,
  });

  MealPlanDay copyWith({
    String? id,
    int? dayIndex,
    double? totalCalories,
    double? protein,
    double? carb,
    double? fat,
  }) {
    return MealPlanDay(
      id: id ?? this.id,
      dayIndex: dayIndex ?? this.dayIndex,
      totalCalories: totalCalories ?? this.totalCalories,
      protein: protein ?? this.protein,
      carb: carb ?? this.carb,
      fat: fat ?? this.fat,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealPlanDay &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Meal Slot - represents a single meal in a day
class MealSlot {
  final String id;
  final String name;
  final String mealType; // "breakfast", "lunch", "dinner", "snack"
  final double calories;
  final double protein;
  final double carb;
  final double fat;
  final String? foodId; // Reference to food catalog
  final String? description;

  const MealSlot({
    required this.id,
    required this.name,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carb,
    required this.fat,
    this.foodId,
    this.description,
  });

  MealSlot copyWith({
    String? id,
    String? name,
    String? mealType,
    double? calories,
    double? protein,
    double? carb,
    double? fat,
    String? foodId,
    String? description,
  }) {
    return MealSlot(
      id: id ?? this.id,
      name: name ?? this.name,
      mealType: mealType ?? this.mealType,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carb: carb ?? this.carb,
      fat: fat ?? this.fat,
      foodId: foodId ?? this.foodId,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealSlot &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

