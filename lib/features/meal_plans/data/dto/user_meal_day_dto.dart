import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calories_app/features/meal_plans/domain/models/user/user_meal_day.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/macros_summary.dart';

/// DTO for user meal day in Firestore
/// 
/// Firestore document structure:
/// Collection: users/{userId}/user_meal_plans/{planId}/days/{dayId}
/// 
/// Fields:
/// - dayIndex: number
/// - totalCalories: number
/// - protein: number
/// - carb: number
/// - fat: number
class UserMealDayDto {
  final String id;
  final int dayIndex;
  final double totalCalories;
  final double protein;
  final double carb;
  final double fat;

  const UserMealDayDto({
    required this.id,
    required this.dayIndex,
    required this.totalCalories,
    required this.protein,
    required this.carb,
    required this.fat,
  });

  /// Create from Firestore DocumentSnapshot
  factory UserMealDayDto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserMealDayDto(
      id: doc.id,
      dayIndex: (data['dayIndex'] as num?)?.toInt() ?? 0,
      totalCalories: (data['totalCalories'] as num?)?.toDouble() ?? 0.0,
      protein: (data['protein'] as num?)?.toDouble() ?? 0.0,
      carb: (data['carb'] as num?)?.toDouble() ?? 0.0,
      fat: (data['fat'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Create from Map (for testing or manual construction)
  factory UserMealDayDto.fromMap(Map<String, dynamic> map, String id) {
    return UserMealDayDto(
      id: id,
      dayIndex: (map['dayIndex'] as num?)?.toInt() ?? 0,
      totalCalories: (map['totalCalories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carb: (map['carb'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'dayIndex': dayIndex,
      'totalCalories': totalCalories,
      'protein': protein,
      'carb': carb,
      'fat': fat,
    };
  }
}

/// Mapper between UserMealDayDto (Firestore) and UserMealDay (domain)
extension UserMealDayDtoMapper on UserMealDayDto {
  /// Convert DTO to domain model
  UserMealDay toDomain() {
    return UserMealDay(
      id: id,
      dayIndex: dayIndex,
      macros: MacrosSummary(
        calories: totalCalories,
        protein: protein,
        carb: carb,
        fat: fat,
      ),
    );
  }
}

/// Mapper from domain model to DTO
extension UserMealDayToDto on UserMealDay {
  /// Convert domain model to DTO
  UserMealDayDto toDto() {
    return UserMealDayDto(
      id: id,
      dayIndex: dayIndex,
      totalCalories: macros.calories,
      protein: macros.protein,
      carb: macros.carb,
      fat: macros.fat,
    );
  }
}

