import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;

/// DTO for meal item in Firestore
/// 
/// Firestore document structure:
/// - mealType: string ("breakfast" | "lunch" | "dinner" | "snack")
/// - foodId: string
/// - servingSize: number
/// - calories: number
/// - protein: number
/// - carb: number
/// - fat: number
class MealItemDto {
  final String id;
  final String mealType;
  final String foodId;
  final double servingSize;
  final double calories;
  final double protein;
  final double carb;
  final double fat;

  const MealItemDto({
    required this.id,
    required this.mealType,
    required this.foodId,
    required this.servingSize,
    required this.calories,
    required this.protein,
    required this.carb,
    required this.fat,
  });

  /// Create from Firestore DocumentSnapshot
  factory MealItemDto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MealItemDto(
      id: doc.id,
      mealType: data['mealType'] as String? ?? '',
      foodId: data['foodId'] as String? ?? '',
      servingSize: (data['servingSize'] as num?)?.toDouble() ?? 0.0,
      calories: (data['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (data['protein'] as num?)?.toDouble() ?? 0.0,
      carb: (data['carb'] as num?)?.toDouble() ?? 0.0,
      fat: (data['fat'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Create from Map (for testing or manual construction)
  factory MealItemDto.fromMap(Map<String, dynamic> map, String id) {
    return MealItemDto(
      id: id,
      mealType: map['mealType'] as String? ?? '',
      foodId: map['foodId'] as String? ?? '',
      servingSize: (map['servingSize'] as num?)?.toDouble() ?? 0.0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carb: (map['carb'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'mealType': mealType,
      'foodId': foodId,
      'servingSize': servingSize,
      'calories': calories,
      'protein': protein,
      'carb': carb,
      'fat': fat,
    };
  }
}

/// Mapper between MealItemDto (Firestore) and MealItem (domain)
extension MealItemDtoMapper on MealItemDto {
  /// Convert DTO to domain model
  MealItem toDomain() {
    return MealItem(
      id: id,
      mealType: mealType,
      foodId: foodId,
      servingSize: servingSize,
      calories: calories,
      protein: protein,
      carb: carb,
      fat: fat,
    );
  }
}

/// Mapper from domain model to DTO
extension MealItemToDto on MealItem {
  /// Convert domain model to DTO
  MealItemDto toDto() {
    return MealItemDto(
      id: id,
      mealType: mealType,
      foodId: foodId,
      servingSize: servingSize,
      calories: calories,
      protein: protein,
      carb: carb,
      fat: fat,
    );
  }
}

