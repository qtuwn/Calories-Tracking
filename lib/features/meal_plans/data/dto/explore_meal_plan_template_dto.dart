import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calories_app/features/meal_plans/domain/models/explore/explore_meal_plan_template.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/goal_type.dart';

/// DTO for explore meal plan template in Firestore
/// 
/// Firestore document structure:
/// Collection: meal_plans/{templateId}
/// 
/// Fields:
/// - name: string
/// - goalType: string ("lose_fat" | "muscle_gain" | "vegan" | "maintain")
/// - description: string
/// - dailyCalories: number
/// - durationDays: number
/// - mealsPerDay: number
/// - tags: array of strings
/// - isFeatured: boolean
/// - isEnabled: boolean
/// - createdAt: timestamp
/// - difficulty: string? (optional)
/// - createdBy: string? (optional, admin ID)
class ExploreMealPlanTemplateDto {
  final String id;
  final String name;
  final String goalType; // String representation
  final String description;
  final int dailyCalories;
  final int durationDays;
  final int mealsPerDay;
  final List<String> tags;
  final bool isFeatured;
  final bool isEnabled;
  final DateTime? createdAt;
  final String? difficulty;
  final String? createdBy;

  const ExploreMealPlanTemplateDto({
    required this.id,
    required this.name,
    required this.goalType,
    required this.description,
    required this.dailyCalories,
    required this.durationDays,
    required this.mealsPerDay,
    required this.tags,
    required this.isFeatured,
    required this.isEnabled,
    this.createdAt,
    this.difficulty,
    this.createdBy,
  });

  /// Create from Firestore DocumentSnapshot
  factory ExploreMealPlanTemplateDto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAtTimestamp = data['createdAt'] as Timestamp?;

    // Support both new and legacy schema
    final goalType = data['goalType'] as String? ?? 'maintain';
    final description = data['description'] as String? ?? 
                       data['shortDescription'] as String? ?? '';
    final durationDays = (data['durationDays'] as num?)?.toInt() ?? 
                        ((data['durationWeeks'] as num?)?.toInt() ?? 0) * 7;
    final tags = (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
                 (data['goalTags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
                 [];

    return ExploreMealPlanTemplateDto(
      id: doc.id,
      name: data['name'] as String? ?? '',
      goalType: goalType,
      description: description,
      dailyCalories: (data['dailyCalories'] as num?)?.toInt() ?? 0,
      durationDays: durationDays,
      mealsPerDay: (data['mealsPerDay'] as num?)?.toInt() ?? 0,
      tags: tags,
      isFeatured: data['isFeatured'] as bool? ?? false,
      isEnabled: data['isEnabled'] as bool? ?? true,
      createdAt: createdAtTimestamp?.toDate(),
      difficulty: MealPlanDifficulty.fromString(data['difficulty'] as String?)?.value,
      createdBy: data['createdBy'] as String?,
    );
  }

  /// Create from Map (for testing or manual construction)
  factory ExploreMealPlanTemplateDto.fromMap(Map<String, dynamic> map, String id) {
    final createdAtTimestamp = map['createdAt'] as Timestamp?;

    // Support both new and legacy schema
    final goalType = map['goalType'] as String? ?? 'maintain';
    final description = map['description'] as String? ?? 
                       map['shortDescription'] as String? ?? '';
    final durationDays = (map['durationDays'] as num?)?.toInt() ?? 
                        ((map['durationWeeks'] as num?)?.toInt() ?? 0) * 7;
    final tags = (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
                 (map['goalTags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
                 [];

    return ExploreMealPlanTemplateDto(
      id: id,
      name: map['name'] as String? ?? '',
      goalType: goalType,
      description: description,
      dailyCalories: (map['dailyCalories'] as num?)?.toInt() ?? 0,
      durationDays: durationDays,
      mealsPerDay: (map['mealsPerDay'] as num?)?.toInt() ?? 0,
      tags: tags,
      isFeatured: map['isFeatured'] as bool? ?? false,
      isEnabled: map['isEnabled'] as bool? ?? true,
      createdAt: createdAtTimestamp?.toDate(),
      difficulty: MealPlanDifficulty.fromString(map['difficulty'] as String?)?.value,
      createdBy: map['createdBy'] as String?,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'goalType': goalType,
      'description': description,
      'dailyCalories': dailyCalories,
      'durationDays': durationDays,
      'mealsPerDay': mealsPerDay,
      'tags': tags,
      'isFeatured': isFeatured,
      'isEnabled': isEnabled,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      if (difficulty != null) 'difficulty': difficulty,
      if (createdBy != null) 'createdBy': createdBy,
    };
  }
}

/// Mapper between ExploreMealPlanTemplateDto (Firestore) and ExploreMealPlanTemplate (domain)
extension ExploreMealPlanTemplateDtoMapper on ExploreMealPlanTemplateDto {
  /// Convert DTO to domain model
  ExploreMealPlanTemplate toDomain() {
    return ExploreMealPlanTemplate(
      id: id,
      name: name,
      goalType: MealPlanGoalType.fromString(goalType),
      description: description,
      templateKcal: dailyCalories,
      durationDays: durationDays,
      mealsPerDay: mealsPerDay,
      tags: tags,
      isFeatured: isFeatured,
      isEnabled: isEnabled,
      createdAt: createdAt,
      difficulty: difficulty,
      createdBy: createdBy,
    );
  }
}

/// Mapper from domain model to DTO
extension ExploreMealPlanTemplateToDto on ExploreMealPlanTemplate {
  /// Convert domain model to DTO
  ExploreMealPlanTemplateDto toDto() {
    return ExploreMealPlanTemplateDto(
      id: id,
      name: name,
      goalType: goalType.value,
      description: description,
      dailyCalories: templateKcal,
      durationDays: durationDays,
      mealsPerDay: mealsPerDay,
      tags: tags,
      isFeatured: isFeatured,
      isEnabled: isEnabled,
      createdAt: createdAt,
      difficulty: difficulty,
      createdBy: createdBy,
    );
  }
}

