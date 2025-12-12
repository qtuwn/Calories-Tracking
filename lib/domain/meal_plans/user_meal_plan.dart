import 'meal_plan_goal_type.dart';

/// User Meal Plan domain entity
/// 
/// Represents a meal plan owned by a specific user, either:
/// - A custom plan created by the user
/// - A plan copied from an explore template and personalized
/// 
/// This is a pure domain model with no dependencies on Flutter or Firebase.
/// Mapping to/from Firestore is handled in the data layer.

/// Status of a user meal plan
enum UserMealPlanStatus {
  active,
  paused,
  finished;

  String get value {
    switch (this) {
      case UserMealPlanStatus.active:
        return 'active';
      case UserMealPlanStatus.paused:
        return 'paused';
      case UserMealPlanStatus.finished:
        return 'finished';
    }
  }

  static UserMealPlanStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'active':
        return UserMealPlanStatus.active;
      case 'paused':
        return UserMealPlanStatus.paused;
      case 'finished':
        return UserMealPlanStatus.finished;
      default:
        return UserMealPlanStatus.active;
    }
  }
}

/// Type of user meal plan
enum UserMealPlanType {
  template, // Copied from template
  custom; // User-created

  String get value {
    switch (this) {
      case UserMealPlanType.template:
        return 'template';
      case UserMealPlanType.custom:
        return 'custom';
    }
  }

  static UserMealPlanType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'template':
        return UserMealPlanType.template;
      case 'custom':
        return UserMealPlanType.custom;
      default:
        return UserMealPlanType.template;
    }
  }
}

/// User Meal Plan entity
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

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'planTemplateId': planTemplateId,
      'name': name,
      'goalType': goalType.value,
      'type': type.value,
      'startDate': startDate.toIso8601String(),
      'currentDayIndex': currentDayIndex,
      'status': status.value,
      'dailyCalories': dailyCalories,
      'durationDays': durationDays,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create from JSON (for caching)
  factory UserMealPlan.fromJson(Map<String, dynamic> json) {
    return UserMealPlan(
      id: json['id'] as String,
      userId: json['userId'] as String,
      planTemplateId: json['planTemplateId'] as String?,
      name: json['name'] as String,
      goalType: MealPlanGoalType.fromString(json['goalType'] as String?),
      type: UserMealPlanType.fromString(json['type'] as String?),
      startDate: DateTime.parse(json['startDate'] as String),
      currentDayIndex: json['currentDayIndex'] as int,
      status: UserMealPlanStatus.fromString(json['status'] as String?),
      dailyCalories: json['dailyCalories'] as int,
      durationDays: json['durationDays'] as int,
      isActive: json['isActive'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
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

