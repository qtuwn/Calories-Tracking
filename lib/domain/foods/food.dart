/// Pure domain entity for Food
/// 
/// No Flutter or Firebase dependencies.
/// This is the core business model for food items in the catalog.
class Food {
  final String id;
  final String name;
  final String nameLower; // For case-insensitive search
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

  /// Convert Food to a JSON map for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameLower': nameLower,
      'category': category,
      'caloriesPer100g': caloriesPer100g,
      'proteinPer100g': proteinPer100g,
      'carbsPer100g': carbsPer100g,
      'fatPer100g': fatPer100g,
      'defaultPortionGram': defaultPortionGram,
      'defaultPortionName': defaultPortionName,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create Food from a JSON map
  factory Food.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (_) {
          return 0.0;
        }
      }
      return 0.0;
    }

    return Food(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameLower: json['nameLower'] as String? ?? '',
      category: json['category'] as String?,
      caloriesPer100g: toDouble(json['caloriesPer100g']),
      proteinPer100g: toDouble(json['proteinPer100g']),
      carbsPer100g: toDouble(json['carbsPer100g']),
      fatPer100g: toDouble(json['fatPer100g']),
      defaultPortionGram: toDouble(json['defaultPortionGram']),
      defaultPortionName: json['defaultPortionName'] as String? ?? 'chén',
      updatedAt: parseDateTime(json['updatedAt']),
    );
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

