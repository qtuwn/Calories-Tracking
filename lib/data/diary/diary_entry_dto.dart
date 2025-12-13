import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/diary/diary_entry.dart';

/// Data Transfer Object for DiaryEntry
/// 
/// Handles mapping between Firestore documents and domain DiaryEntry entities.
class DiaryEntryDto {
  final String id;
  final String userId;
  final String date; // ISO date string: "yyyy-MM-dd"
  final String type; // "food" or "exercise"
  
  // Food-related fields
  final String? mealType;
  final String? foodId;
  final String? foodName;
  final double? servingCount;
  final double? gramsPerServing;
  final double? totalGrams;
  final double? protein;
  final double? carbs;
  final double? fat;
  
  // Exercise-related fields
  final String? exerciseId;
  final String? exerciseName;
  final double? durationMinutes;
  final String? exerciseUnit;
  final double? exerciseValue;
  final String? exerciseLevelName;
  
  // Common fields
  final double calories;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  DiaryEntryDto({
    required this.id,
    required this.userId,
    required this.date,
    required this.type,
    this.mealType,
    this.foodId,
    this.foodName,
    this.servingCount,
    this.gramsPerServing,
    this.totalGrams,
    this.protein,
    this.carbs,
    this.fat,
    this.exerciseId,
    this.exerciseName,
    this.durationMinutes,
    this.exerciseUnit,
    this.exerciseValue,
    this.exerciseLevelName,
    required this.calories,
    required this.createdAt,
    this.updatedAt,
  });

  /// Converts a Firestore document snapshot to a DiaryEntryDto.
  factory DiaryEntryDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Helper to parse DateTime from various formats
    Timestamp? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value;
      if (value is DateTime) return Timestamp.fromDate(value);
      if (value is String) {
        try {
          return Timestamp.fromDate(DateTime.parse(value));
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    // Helper to safely convert to double (nullable)
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

    // Helper to safely convert to double (non-null)
    double toDouble(dynamic value) {
      return toDoubleNullable(value) ?? 0.0;
    }

    final createdAtTimestamp = parseTimestamp(data['createdAt']) ?? Timestamp.now();
    final updatedAtTimestamp = parseTimestamp(data['updatedAt']);

    return DiaryEntryDto(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      date: data['date'] as String? ?? '',
      type: data['type'] as String? ?? 'food',
      mealType: data['mealType'] as String?,
      foodId: data['foodId'] as String?,
      foodName: data['foodName'] as String?,
      servingCount: toDoubleNullable(data['servingCount']),
      gramsPerServing: toDoubleNullable(data['gramsPerServing']),
      totalGrams: toDoubleNullable(data['totalGrams']),
      protein: toDoubleNullable(data['protein']),
      carbs: toDoubleNullable(data['carbs']),
      fat: toDoubleNullable(data['fat']),
      exerciseId: data['exerciseId'] as String?,
      exerciseName: data['exerciseName'] as String?,
      durationMinutes: toDoubleNullable(data['durationMinutes']),
      exerciseUnit: data['exerciseUnit'] as String?,
      exerciseValue: toDoubleNullable(data['exerciseValue']),
      exerciseLevelName: data['exerciseLevelName'] as String?,
      calories: toDouble(data['calories']),
      createdAt: createdAtTimestamp,
      updatedAt: updatedAtTimestamp,
    );
  }

  /// Converts a DiaryEntryDto to a map for Firestore.
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'userId': userId,
      'date': date,
      'type': type,
      'calories': calories,
      'createdAt': createdAt,
    };

    // Add food-specific fields if this is a food entry
    if (type == 'food') {
      if (mealType != null) map['mealType'] = mealType;
      if (foodId != null) map['foodId'] = foodId;
      if (foodName != null) map['foodName'] = foodName;
      if (servingCount != null) map['servingCount'] = servingCount;
      if (gramsPerServing != null) map['gramsPerServing'] = gramsPerServing;
      if (totalGrams != null) map['totalGrams'] = totalGrams;
      if (protein != null) map['protein'] = protein;
      if (carbs != null) map['carbs'] = carbs;
      if (fat != null) map['fat'] = fat;
    }

    // Add exercise-specific fields if this is an exercise entry
    if (type == 'exercise') {
      if (exerciseId != null) map['exerciseId'] = exerciseId;
      if (exerciseName != null) map['exerciseName'] = exerciseName;
      if (durationMinutes != null) map['durationMinutes'] = durationMinutes;
      if (exerciseUnit != null) map['exerciseUnit'] = exerciseUnit;
      if (exerciseValue != null) map['exerciseValue'] = exerciseValue;
      if (exerciseLevelName != null) map['exerciseLevelName'] = exerciseLevelName;
    }

    if (updatedAt != null) {
      map['updatedAt'] = updatedAt;
    }

    return map;
  }

  /// Converts a DiaryEntry domain model to a DiaryEntryDto.
  factory DiaryEntryDto.fromDomain(DiaryEntry entry) {
    return DiaryEntryDto(
      id: entry.id,
      userId: entry.userId,
      date: entry.date,
      type: entry.type.name,
      mealType: entry.mealType,
      foodId: entry.foodId,
      foodName: entry.foodName,
      servingCount: entry.servingCount,
      gramsPerServing: entry.gramsPerServing,
      totalGrams: entry.totalGrams,
      protein: entry.protein,
      carbs: entry.carbs,
      fat: entry.fat,
      exerciseId: entry.exerciseId,
      exerciseName: entry.exerciseName,
      durationMinutes: entry.durationMinutes,
      exerciseUnit: entry.exerciseUnit,
      exerciseValue: entry.exerciseValue,
      exerciseLevelName: entry.exerciseLevelName,
      calories: entry.calories,
      createdAt: Timestamp.fromDate(entry.createdAt),
      updatedAt: entry.updatedAt != null ? Timestamp.fromDate(entry.updatedAt!) : null,
    );
  }

  /// Converts a DiaryEntryDto to a DiaryEntry domain model.
  DiaryEntry toDomain() {
    return DiaryEntry(
      id: id,
      userId: userId,
      date: date,
      type: DiaryEntryType.fromString(type),
      mealType: mealType,
      foodId: foodId,
      foodName: foodName,
      servingCount: servingCount,
      gramsPerServing: gramsPerServing,
      totalGrams: totalGrams,
      protein: protein,
      carbs: carbs,
      fat: fat,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      durationMinutes: durationMinutes,
      exerciseUnit: exerciseUnit,
      exerciseValue: exerciseValue,
      exerciseLevelName: exerciseLevelName,
      calories: calories,
      createdAt: createdAt.toDate(),
      updatedAt: updatedAt?.toDate(),
    );
  }
}

