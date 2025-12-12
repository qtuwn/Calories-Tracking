import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/foods/food.dart';

/// Data Transfer Object for Food
/// 
/// Handles mapping between Firestore documents and domain Food entities.
class FoodDto {
  final String id;
  final String name;
  final String nameLower;
  final String? category;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double defaultPortionGram;
  final String defaultPortionName;
  final Timestamp? updatedAt;

  FoodDto({
    required this.id,
    required this.name,
    required this.nameLower,
    this.category,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.defaultPortionGram = 100.0,
    this.defaultPortionName = 'chén',
    this.updatedAt,
  });

  /// Converts a Firestore document snapshot to a FoodDto.
  factory FoodDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final updatedAtTimestamp = data['updatedAt'] as Timestamp?;

    return FoodDto(
      id: doc.id,
      name: data['name'] as String? ?? '',
      nameLower: data['nameLower'] as String? ?? '',
      category: data['category'] as String?,
      caloriesPer100g: (data['caloriesPer100g'] as num?)?.toDouble() ?? 0.0,
      proteinPer100g: (data['proteinPer100g'] as num?)?.toDouble() ?? 0.0,
      carbsPer100g: (data['carbsPer100g'] as num?)?.toDouble() ?? 0.0,
      fatPer100g: (data['fatPer100g'] as num?)?.toDouble() ?? 0.0,
      defaultPortionGram: (data['defaultPortionGram'] as num?)?.toDouble() ?? 100.0,
      defaultPortionName: data['defaultPortionName'] as String? ?? 'chén',
      updatedAt: updatedAtTimestamp,
    );
  }

  /// Converts a FoodDto to a map for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'nameLower': nameLower,
      'category': category,
      'caloriesPer100g': caloriesPer100g,
      'proteinPer100g': proteinPer100g,
      'carbsPer100g': carbsPer100g,
      'fatPer100g': fatPer100g,
      'defaultPortionGram': defaultPortionGram,
      'defaultPortionName': defaultPortionName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Converts a Food domain model to a FoodDto.
  factory FoodDto.fromDomain(Food food) {
    return FoodDto(
      id: food.id,
      name: food.name,
      nameLower: food.nameLower,
      category: food.category,
      caloriesPer100g: food.caloriesPer100g,
      proteinPer100g: food.proteinPer100g,
      carbsPer100g: food.carbsPer100g,
      fatPer100g: food.fatPer100g,
      defaultPortionGram: food.defaultPortionGram,
      defaultPortionName: food.defaultPortionName,
      updatedAt: food.updatedAt != null ? Timestamp.fromDate(food.updatedAt!) : null,
    );
  }

  /// Converts a FoodDto to a Food domain model.
  Food toDomain() {
    return Food(
      id: id,
      name: name,
      nameLower: nameLower,
      category: category,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      defaultPortionGram: defaultPortionGram,
      defaultPortionName: defaultPortionName,
      updatedAt: updatedAt?.toDate(),
    );
  }
}

