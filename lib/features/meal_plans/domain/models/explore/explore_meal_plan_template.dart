import 'package:calories_app/features/meal_plans/domain/models/shared/goal_type.dart';

/// Pure domain model for an explore meal plan template
/// 
/// This represents a public template that users can discover and apply.
/// Templates are generic and not tied to any specific user.
/// 
/// No Firestore dependencies - mapping to/from Firestore is handled in the data layer.
class ExploreMealPlanTemplate {
  final String id;
  final String name;
  final MealPlanGoalType goalType;
  final String description;
  final int templateKcal; // Generic daily kcal for the template
  final int durationDays;
  final int mealsPerDay;
  final List<String> tags; // e.g. ["Beginner", "Nhẹ bụng"]
  final bool isFeatured;
  final bool isEnabled;
  final DateTime? createdAt;
  
  // Optional metadata fields
  final String? difficulty; // "easy" | "medium" | "hard"
  final String? createdBy; // Admin ID who created it

  const ExploreMealPlanTemplate({
    required this.id,
    required this.name,
    required this.goalType,
    required this.description,
    required this.templateKcal,
    required this.durationDays,
    required this.mealsPerDay,
    required this.tags,
    required this.isFeatured,
    required this.isEnabled,
    this.createdAt,
    this.difficulty,
    this.createdBy,
  });

  /// Create a copy with modified fields
  ExploreMealPlanTemplate copyWith({
    String? id,
    String? name,
    MealPlanGoalType? goalType,
    String? description,
    int? templateKcal,
    int? durationDays,
    int? mealsPerDay,
    List<String>? tags,
    bool? isFeatured,
    bool? isEnabled,
    DateTime? createdAt,
    String? difficulty,
    String? createdBy,
  }) {
    return ExploreMealPlanTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      goalType: goalType ?? this.goalType,
      description: description ?? this.description,
      templateKcal: templateKcal ?? this.templateKcal,
      durationDays: durationDays ?? this.durationDays,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      tags: tags ?? this.tags,
      isFeatured: isFeatured ?? this.isFeatured,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      difficulty: difficulty ?? this.difficulty,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExploreMealPlanTemplate &&
        other.id == id &&
        other.name == name &&
        other.goalType == goalType &&
        other.description == description &&
        other.templateKcal == templateKcal &&
        other.durationDays == durationDays &&
        other.mealsPerDay == mealsPerDay &&
        other.tags == tags &&
        other.isFeatured == isFeatured &&
        other.isEnabled == isEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      goalType,
      description,
      templateKcal,
      durationDays,
      mealsPerDay,
      tags,
      isFeatured,
      isEnabled,
    );
  }
}

