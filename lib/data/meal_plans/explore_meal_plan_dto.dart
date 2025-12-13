import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/meal_plans/explore_meal_plan.dart';
import '../../domain/meal_plans/meal_plan_goal_type.dart';

/// Data Transfer Object for Explore Meal Plan
/// 
/// Handles conversion between Firestore documents and domain ExploreMealPlan entities.
class ExploreMealPlanDto {
  final String id;
  final String name;
  final String goalType;
  final String description;
  final int templateKcal;
  final int durationDays;
  final int mealsPerDay;
  final List<String> tags;
  final bool isFeatured;
  final bool isPublished;
  final bool isEnabled;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final String? createdBy;
  final String? difficulty;

  ExploreMealPlanDto({
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

  /// Create DTO from Firestore document
  factory ExploreMealPlanDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExploreMealPlanDto(
      id: doc.id,
      name: data['name'] as String? ?? '',
      goalType: data['goalType'] as String? ?? 'other',
      description: data['description'] as String? ?? '',
      templateKcal: (data['templateKcal'] as num?)?.toInt() ??
          (data['dailyCalories'] as num?)?.toInt() ?? 0,
      durationDays: (data['durationDays'] as num?)?.toInt() ?? 7,
      mealsPerDay: (data['mealsPerDay'] as num?)?.toInt() ?? 3,
      tags: List<String>.from(data['tags'] as List? ?? []),
      isFeatured: data['isFeatured'] as bool? ?? false,
      isPublished: data['isPublished'] as bool? ?? false,
      isEnabled: data['isEnabled'] as bool? ?? true,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
      createdBy: data['createdBy'] as String?,
      difficulty: data['difficulty'] as String?,
    );
  }

  /// Convert DTO to Firestore map
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'name': name,
      'goalType': goalType,
      'description': description,
      'dailyCalories': templateKcal, // Use dailyCalories for Firestore compatibility
      'templateKcal': templateKcal, // Also store as templateKcal for consistency
      'durationDays': durationDays,
      'mealsPerDay': mealsPerDay,
      'tags': tags,
      'isFeatured': isFeatured,
      'isPublished': isPublished,
      'isEnabled': isEnabled,
      'createdAt': createdAt,
    };

    if (updatedAt != null) map['updatedAt'] = updatedAt;
    if (createdBy != null) map['createdBy'] = createdBy;
    if (difficulty != null) map['difficulty'] = difficulty;

    return map;
  }

  /// Convert DTO to domain entity
  ExploreMealPlan toDomain() {
    return ExploreMealPlan(
      id: id,
      name: name,
      goalType: MealPlanGoalType.fromString(goalType),
      description: description,
      templateKcal: templateKcal,
      durationDays: durationDays,
      mealsPerDay: mealsPerDay,
      tags: tags,
      isFeatured: isFeatured,
      isPublished: isPublished,
      isEnabled: isEnabled,
      createdAt: createdAt.toDate(),
      updatedAt: updatedAt?.toDate(),
      createdBy: createdBy,
      difficulty: difficulty,
    );
  }

  /// Create DTO from domain entity
  factory ExploreMealPlanDto.fromDomain(ExploreMealPlan plan) {
    return ExploreMealPlanDto(
      id: plan.id,
      name: plan.name,
      goalType: plan.goalType.value,
      description: plan.description,
      templateKcal: plan.templateKcal,
      durationDays: plan.durationDays,
      mealsPerDay: plan.mealsPerDay,
      tags: plan.tags,
      isFeatured: plan.isFeatured,
      isPublished: plan.isPublished,
      isEnabled: plan.isEnabled,
      createdAt: Timestamp.fromDate(plan.createdAt),
      updatedAt: plan.updatedAt != null
          ? Timestamp.fromDate(plan.updatedAt!)
          : null,
      createdBy: plan.createdBy,
      difficulty: plan.difficulty,
    );
  }
}

/// Data Transfer Object for Meal Plan Day
class MealPlanDayDto {
  final String id;
  final int dayIndex;
  final double totalCalories;
  final double protein;
  final double carb;
  final double fat;

  MealPlanDayDto({
    required this.id,
    required this.dayIndex,
    required this.totalCalories,
    required this.protein,
    required this.carb,
    required this.fat,
  });

  factory MealPlanDayDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealPlanDayDto(
      id: doc.id,
      dayIndex: (data['dayIndex'] as num?)?.toInt() ?? 1,
      totalCalories: (data['totalCalories'] as num?)?.toDouble() ?? 0.0,
      protein: (data['protein'] as num?)?.toDouble() ?? 0.0,
      carb: (data['carb'] as num?)?.toDouble() ?? 0.0,
      fat: (data['fat'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'dayIndex': dayIndex,
      'totalCalories': totalCalories,
      'protein': protein,
      'carb': carb,
      'fat': fat,
    };
  }

  MealPlanDay toDomain() {
    return MealPlanDay(
      id: id,
      dayIndex: dayIndex,
      totalCalories: totalCalories,
      protein: protein,
      carb: carb,
      fat: fat,
    );
  }

  factory MealPlanDayDto.fromDomain(MealPlanDay day) {
    return MealPlanDayDto(
      id: day.id,
      dayIndex: day.dayIndex,
      totalCalories: day.totalCalories,
      protein: day.protein,
      carb: day.carb,
      fat: day.fat,
    );
  }
}

/// Data Transfer Object for Meal Slot
class MealSlotDto {
  final String id;
  final String name;
  final String mealType;
  final double calories;
  final double protein;
  final double carb;
  final double fat;
  final String? foodId;
  final String? description;
  final double servingSize; // Required: must be > 0

  MealSlotDto({
    required this.id,
    required this.name,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carb,
    required this.fat,
    this.foodId,
    this.description,
    required this.servingSize,
  });

  factory MealSlotDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse servingSize with strict validation
    final servingSizeValue = data['servingSize'];
    if (servingSizeValue == null) {
      throw FormatException(
        'Missing servingSize in explore template slot (docId=${doc.id}). '
        'Older templates without servingSize cannot be applied. Please update the template.',
      );
    }
    
    final servingSizeDouble = (servingSizeValue as num?)?.toDouble();
    if (servingSizeDouble == null || servingSizeDouble <= 0) {
      throw FormatException(
        'Invalid servingSize in explore template slot (docId=${doc.id}): $servingSizeValue. '
        'servingSize must be a positive number.',
      );
    }
    
    return MealSlotDto(
      id: doc.id,
      name: data['name'] as String? ?? '',
      mealType: data['mealType'] as String? ?? 'breakfast',
      calories: (data['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (data['protein'] as num?)?.toDouble() ?? 0.0,
      carb: (data['carb'] as num?)?.toDouble() ?? 0.0,
      fat: (data['fat'] as num?)?.toDouble() ?? 0.0,
      foodId: data['foodId'] as String?,
      description: data['description'] as String?,
      servingSize: servingSizeDouble,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'name': name,
      'mealType': mealType,
      'calories': calories,
      'protein': protein,
      'carb': carb,
      'fat': fat,
      'servingSize': servingSize, // Required: always write servingSize
    };

    if (foodId != null) map['foodId'] = foodId;
    if (description != null) map['description'] = description;

    return map;
  }

  MealSlot toDomain() {
    return MealSlot(
      id: id,
      name: name,
      mealType: mealType,
      calories: calories,
      protein: protein,
      carb: carb,
      fat: fat,
      foodId: foodId,
      description: description,
      servingSize: servingSize,
    );
  }

  factory MealSlotDto.fromDomain(MealSlot meal) {
    return MealSlotDto(
      id: meal.id,
      name: meal.name,
      mealType: meal.mealType,
      calories: meal.calories,
      protein: meal.protein,
      carb: meal.carb,
      fat: meal.fat,
      foodId: meal.foodId,
      description: meal.description,
      servingSize: meal.servingSize,
    );
  }
}

