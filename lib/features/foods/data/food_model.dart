import 'package:cloud_firestore/cloud_firestore.dart';

/// Food model representing a food item in the catalog
/// 
/// @Deprecated Use domain/foods/food.dart instead.
/// This legacy model is kept for backward compatibility during migration.
/// Migration guide: Use FoodService and Food domain entity from lib/domain/foods/
@Deprecated('Use domain/foods/food.dart and FoodService instead. Migration in progress.')
class Food {
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
  final DateTime? updatedAt;

  Food({
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

  factory Food.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final updatedAtTimestamp = data['updatedAt'] as Timestamp?;

    return Food(
      id: doc.id,
      name: data['name'] as String? ?? '',
      nameLower: data['nameLower'] as String? ?? '',
      category: data['category'] as String?,
      caloriesPer100g: (data['caloriesPer100g'] as num?)?.toDouble() ?? 0.0,
      proteinPer100g: (data['proteinPer100g'] as num?)?.toDouble() ?? 0.0,
      carbsPer100g: (data['carbsPer100g'] as num?)?.toDouble() ?? 0.0,
      fatPer100g: (data['fatPer100g'] as num?)?.toDouble() ?? 0.0,
      defaultPortionGram:
          (data['defaultPortionGram'] as num?)?.toDouble() ?? 100.0,
      defaultPortionName: data['defaultPortionName'] as String? ?? 'chén',
      updatedAt: updatedAtTimestamp?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
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

  Food copyWith({
    String? id,
    String? name,
    String? nameLower,
    String? category,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    double? defaultPortionGram,
    String? defaultPortionName,
    DateTime? updatedAt,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      nameLower: nameLower ?? this.nameLower,
      category: category ?? this.category,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      defaultPortionGram: defaultPortionGram ?? this.defaultPortionGram,
      defaultPortionName: defaultPortionName ?? this.defaultPortionName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
