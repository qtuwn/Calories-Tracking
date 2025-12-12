import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';

/// DTO for user meal plan in Firestore
/// 
/// Firestore document structure:
/// Collection: users/{userId}/user_meal_plans/{planId}
/// 
/// Fields:
/// - userId: string
/// - planTemplateId: string? (null for custom plans)
/// - name: string
/// - goalType: string ("lose_fat" | "muscle_gain" | "vegan" | "maintain")
/// - type: string ("template" | "custom")
/// - startDate: timestamp
/// - currentDayIndex: number
/// - status: string ("active" | "paused" | "finished")
/// - dailyCalories: number
/// - durationDays: number
/// - isActive: boolean
/// - createdAt: timestamp
/// - updatedAt: timestamp
class UserMealPlanDto {
  final String id;
  final String userId;
  final String? planTemplateId;
  final String name;
  final String goalType; // String representation
  final String type; // String representation
  final DateTime startDate;
  final int currentDayIndex;
  final String status; // String representation
  final int dailyCalories;
  final int durationDays;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserMealPlanDto({
    required this.id,
    required this.userId,
    this.planTemplateId,
    required this.name,
    required this.goalType,
    required this.type,
    required this.startDate,
    required this.currentDayIndex,
    required this.status,
    required this.dailyCalories,
    required this.durationDays,
    this.isActive = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from Firestore DocumentSnapshot
  factory UserMealPlanDto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final startDateTimestamp = data['startDate'] as Timestamp?;
    final createdAtTimestamp = data['createdAt'] as Timestamp?;
    final updatedAtTimestamp = data['updatedAt'] as Timestamp?;

    return UserMealPlanDto(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      planTemplateId: data['planTemplateId'] as String?,
      name: data['name'] as String? ?? '',
      goalType: data['goalType'] as String? ?? 'maintain',
      type: data['type'] as String? ?? 'template',
      startDate: startDateTimestamp?.toDate() ?? DateTime.now(),
      currentDayIndex: (data['currentDayIndex'] as num?)?.toInt() ?? 1,
      status: data['status'] as String? ?? 'active',
      dailyCalories: (data['dailyCalories'] as num?)?.toInt() ?? 0,
      durationDays: (data['durationDays'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? false,
      createdAt: createdAtTimestamp?.toDate(),
      updatedAt: updatedAtTimestamp?.toDate(),
    );
  }

  /// Create from Map (for testing or manual construction)
  factory UserMealPlanDto.fromMap(Map<String, dynamic> map, String id) {
    final startDateTimestamp = map['startDate'] as Timestamp?;
    final createdAtTimestamp = map['createdAt'] as Timestamp?;
    final updatedAtTimestamp = map['updatedAt'] as Timestamp?;

    return UserMealPlanDto(
      id: id,
      userId: map['userId'] as String? ?? '',
      planTemplateId: map['planTemplateId'] as String?,
      name: map['name'] as String? ?? '',
      goalType: map['goalType'] as String? ?? 'maintain',
      type: map['type'] as String? ?? 'template',
      startDate: startDateTimestamp?.toDate() ?? DateTime.now(),
      currentDayIndex: (map['currentDayIndex'] as num?)?.toInt() ?? 1,
      status: map['status'] as String? ?? 'active',
      dailyCalories: (map['dailyCalories'] as num?)?.toInt() ?? 0,
      durationDays: (map['durationDays'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? false,
      createdAt: createdAtTimestamp?.toDate(),
      updatedAt: updatedAtTimestamp?.toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      if (planTemplateId != null) 'planTemplateId': planTemplateId,
      'name': name,
      'goalType': goalType,
      'type': type,
      'startDate': Timestamp.fromDate(startDate),
      'currentDayIndex': currentDayIndex,
      'status': status,
      'dailyCalories': dailyCalories,
      'durationDays': durationDays,
      'isActive': isActive,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

/// Mapper between UserMealPlanDto (Firestore) and UserMealPlan (domain)
extension UserMealPlanDtoMapper on UserMealPlanDto {
  /// Convert DTO to domain model
  UserMealPlan toDomain() {
    return UserMealPlan(
      id: id,
      userId: userId,
      planTemplateId: planTemplateId,
      name: name,
      goalType: MealPlanGoalType.fromString(goalType),
      type: UserMealPlanType.fromString(type),
      startDate: startDate,
      currentDayIndex: currentDayIndex,
      status: UserMealPlanStatus.fromString(status),
      dailyCalories: dailyCalories,
      durationDays: durationDays,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Mapper from domain model to DTO
extension UserMealPlanToDto on UserMealPlan {
  /// Convert domain model to DTO
  UserMealPlanDto toDto() {
    return UserMealPlanDto(
      id: id,
      userId: userId,
      planTemplateId: planTemplateId,
      name: name,
      goalType: goalType.value,
      type: type.value,
      startDate: startDate,
      currentDayIndex: currentDayIndex,
      status: status.value,
      dailyCalories: dailyCalories,
      durationDays: durationDays,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

