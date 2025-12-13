/// Type of diary entry
enum DiaryEntryType {
  food,
  exercise;

  static DiaryEntryType fromString(String? value) {
    return DiaryEntryType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DiaryEntryType.food,
    );
  }
}

/// Pure domain entity for DiaryEntry
/// 
/// No Flutter or Firebase dependencies.
/// This is the core business model for diary entries (food or exercise).
class DiaryEntry {
  final String id;
  final String userId;
  final String date; // ISO date string: "yyyy-MM-dd"
  final DiaryEntryType type; // Type: food or exercise
  
  // Food-related fields
  final String? mealType; // MealType.name (breakfast, lunch, dinner, snack) - only for food
  final String? foodId; // Reference to food catalog (nullable for custom entries)
  final String? foodName; // Denormalized food name for easy display
  final double? servingCount; // Number of servings
  final double? gramsPerServing; // Grams per serving
  final double? totalGrams; // Total grams (servingCount * gramsPerServing)
  final double? protein;
  final double? carbs;
  final double? fat;
  
  // Exercise-related fields
  final String? exerciseId; // Reference to exercise catalog
  final String? exerciseName; // Denormalized exercise name
  final double? durationMinutes; // Exercise duration in minutes
  final String? exerciseUnit; // Unit type (time, distance, level)
  final double? exerciseValue; // Input value (minutes, km, etc.)
  final String? exerciseLevelName; // For level-based exercises
  
  // Common fields
  final double calories; // Calories consumed (food) or burned (exercise)
  final DateTime createdAt;
  final DateTime? updatedAt;

  DiaryEntry({
    required this.id,
    required this.userId,
    required this.date,
    this.type = DiaryEntryType.food,
    // Food fields
    this.mealType,
    this.foodId,
    this.foodName,
    this.servingCount,
    this.gramsPerServing,
    this.totalGrams,
    this.protein,
    this.carbs,
    this.fat,
    // Exercise fields
    this.exerciseId,
    this.exerciseName,
    this.durationMinutes,
    this.exerciseUnit,
    this.exerciseValue,
    this.exerciseLevelName,
    // Common fields
    required this.calories,
    required this.createdAt,
    this.updatedAt,
  });

  /// Factory method to create a food diary entry
  factory DiaryEntry.food({
    required String id,
    required String userId,
    required String date,
    required String mealType,
    String? foodId,
    required String foodName,
    required double servingCount,
    required double gramsPerServing,
    required double totalGrams,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) {
    return DiaryEntry(
      id: id,
      userId: userId,
      date: date,
      type: DiaryEntryType.food,
      mealType: mealType,
      foodId: foodId,
      foodName: foodName,
      servingCount: servingCount,
      gramsPerServing: gramsPerServing,
      totalGrams: totalGrams,
      protein: protein,
      carbs: carbs,
      fat: fat,
      calories: calories,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Factory method to create an exercise diary entry
  factory DiaryEntry.exercise({
    required String id,
    required String userId,
    required String date,
    required String exerciseId,
    required String exerciseName,
    required double durationMinutes,
    required double caloriesBurned,
    String? exerciseUnit,
    double? exerciseValue,
    String? exerciseLevelName,
    required DateTime createdAt,
  }) {
    return DiaryEntry(
      id: id,
      userId: userId,
      date: date,
      type: DiaryEntryType.exercise,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      durationMinutes: durationMinutes,
      exerciseUnit: exerciseUnit,
      exerciseValue: exerciseValue,
      exerciseLevelName: exerciseLevelName,
      calories: caloriesBurned,
      createdAt: createdAt,
    );
  }

  /// Check if this is a food entry
  bool get isFood => type == DiaryEntryType.food;

  /// Check if this is an exercise entry
  bool get isExercise => type == DiaryEntryType.exercise;

  /// Convert DiaryEntry to a JSON map for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date,
      'type': type.name,
      'mealType': mealType,
      'foodId': foodId,
      'foodName': foodName,
      'servingCount': servingCount,
      'gramsPerServing': gramsPerServing,
      'totalGrams': totalGrams,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'durationMinutes': durationMinutes,
      'exerciseUnit': exerciseUnit,
      'exerciseValue': exerciseValue,
      'exerciseLevelName': exerciseLevelName,
      'calories': calories,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create DiaryEntry from a JSON map
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
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

    double? toDoubleNullable(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    double toDouble(dynamic value) {
      return toDoubleNullable(value) ?? 0.0;
    }

    final type = DiaryEntryType.fromString(json['type'] as String?);

    return DiaryEntry(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      type: type,
      mealType: json['mealType'] as String?,
      foodId: json['foodId'] as String?,
      foodName: json['foodName'] as String?,
      servingCount: toDoubleNullable(json['servingCount']),
      gramsPerServing: toDoubleNullable(json['gramsPerServing']),
      totalGrams: toDoubleNullable(json['totalGrams']),
      protein: toDoubleNullable(json['protein']),
      carbs: toDoubleNullable(json['carbs']),
      fat: toDoubleNullable(json['fat']),
      exerciseId: json['exerciseId'] as String?,
      exerciseName: json['exerciseName'] as String?,
      durationMinutes: toDoubleNullable(json['durationMinutes']),
      exerciseUnit: json['exerciseUnit'] as String?,
      exerciseValue: toDoubleNullable(json['exerciseValue']),
      exerciseLevelName: json['exerciseLevelName'] as String?,
      calories: toDouble(json['calories']),
      createdAt: parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  /// Convert DiaryEntry to MealItem JSON (for backward compatibility with existing UI)
  /// This allows the existing Meal/MealItem structure to work with DiaryEntry
  /// Only works for food entries
  Map<String, dynamic> toMealItemJson() {
    if (!isFood || totalGrams == null) {
      throw StateError('toMealItemJson can only be called on food entries');
    }

    // Calculate per-100g values from total macros
    final per100gCalories = totalGrams! > 0 ? (calories * 100) / totalGrams! : 0.0;
    final per100gProtein = totalGrams! > 0 ? ((protein ?? 0) * 100) / totalGrams! : 0.0;
    final per100gCarbs = totalGrams! > 0 ? ((carbs ?? 0) * 100) / totalGrams! : 0.0;
    final per100gFat = totalGrams! > 0 ? ((fat ?? 0) * 100) / totalGrams! : 0.0;

    return {
      'id': id,
      'name': foodName ?? '',
      'servingSize': servingCount ?? 0,
      'caloriesPer100g': per100gCalories,
      'proteinPer100g': per100gProtein,
      'carbsPer100g': per100gCarbs,
      'fatPer100g': per100gFat,
      'gramsPerServing': gramsPerServing ?? 0,
    };
  }

  DiaryEntry copyWith({
    String? id,
    String? userId,
    String? date,
    DiaryEntryType? type,
    String? mealType,
    String? foodId,
    String? foodName,
    double? servingCount,
    double? gramsPerServing,
    double? totalGrams,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? exerciseId,
    String? exerciseName,
    double? durationMinutes,
    String? exerciseUnit,
    double? exerciseValue,
    String? exerciseLevelName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      type: type ?? this.type,
      mealType: mealType ?? this.mealType,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      servingCount: servingCount ?? this.servingCount,
      gramsPerServing: gramsPerServing ?? this.gramsPerServing,
      totalGrams: totalGrams ?? this.totalGrams,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      exerciseUnit: exerciseUnit ?? this.exerciseUnit,
      exerciseValue: exerciseValue ?? this.exerciseValue,
      exerciseLevelName: exerciseLevelName ?? this.exerciseLevelName,
      calories: calories ?? this.calories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

