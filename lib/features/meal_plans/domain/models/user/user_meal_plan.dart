import 'package:calories_app/features/meal_plans/domain/models/user/user_meal_plan_status.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/goal_type.dart';

/// Pure domain model for a user's meal plan
/// 
/// This represents a meal plan owned by a specific user, either:
/// - A custom plan created by the user
/// - A plan copied from an explore template and personalized
/// 
/// No Firestore dependencies - mapping to/from Firestore is handled in the data layer.
class UserMealPlan {
  final String id;
  final String userId;
  final String? planTemplateId; // null for custom plans
  final String name;
  final MealPlanGoalType goalType;
  final UserMealPlanType type;
  final DateTime startDate;
  final int currentDayIndex; // 1...durationDays
  final UserMealPlanStatus status;
  final int dailyCalories;
  final int durationDays;
  final bool isActive; // Only one plan can be active at a time
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserMealPlan({
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

  /// Calculate current day index based on start date
  /// Returns 1 if plan hasn't started, or day number if it has
  int calculateCurrentDayIndex() {
    final now = DateTime.now();
    final daysSinceStart = now.difference(startDate).inDays;
    
    if (daysSinceStart < 0) {
      return 1; // Plan hasn't started yet
    }
    
    final calculatedDay = daysSinceStart + 1;
    
    // Don't exceed duration
    if (calculatedDay > durationDays) {
      return durationDays;
    }
    
    return calculatedDay;
  }

  /// Check if plan is finished
  bool get isFinished {
    if (status == UserMealPlanStatus.finished) return true;
    final calculatedDay = calculateCurrentDayIndex();
    return calculatedDay >= durationDays;
  }

  /// Create a copy with modified fields
  UserMealPlan copyWith({
    String? id,
    String? userId,
    String? planTemplateId,
    String? name,
    MealPlanGoalType? goalType,
    UserMealPlanType? type,
    DateTime? startDate,
    int? currentDayIndex,
    UserMealPlanStatus? status,
    int? dailyCalories,
    int? durationDays,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserMealPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planTemplateId: planTemplateId ?? this.planTemplateId,
      name: name ?? this.name,
      goalType: goalType ?? this.goalType,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      currentDayIndex: currentDayIndex ?? this.currentDayIndex,
      status: status ?? this.status,
      dailyCalories: dailyCalories ?? this.dailyCalories,
      durationDays: durationDays ?? this.durationDays,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserMealPlan &&
        other.id == id &&
        other.userId == userId &&
        other.planTemplateId == planTemplateId &&
        other.name == name &&
        other.goalType == goalType &&
        other.type == type &&
        other.startDate == startDate &&
        other.currentDayIndex == currentDayIndex &&
        other.status == status &&
        other.dailyCalories == dailyCalories &&
        other.durationDays == durationDays &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      planTemplateId,
      name,
      goalType,
      type,
      startDate,
      currentDayIndex,
      status,
      dailyCalories,
      durationDays,
      isActive,
    );
  }
}

