import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for an exercise log entry
/// 
/// Exercise logs are stored as a subcollection of the diary entry document:
/// users/{uid}/diaryEntries/{date}/exerciseLogs/{logId}
/// 
/// Or as an embedded array within the diary entry document (current implementation).
class ExerciseLog {
  final String id;
  final String exerciseId; // Reference to exercises collection
  final String exerciseName; // Denormalized for easy display
  final String? imageUrl; // Denormalized image URL
  final double durationMinutes; // Duration in minutes
  final double caloriesBurned; // Calculated calories burned
  final String? unit; // Unit type (time, distance, level)
  final double? value; // Input value (minutes, km, etc.)
  final String? levelName; // For level-based exercises
  final DateTime createdAt;

  ExerciseLog({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    this.imageUrl,
    required this.durationMinutes,
    required this.caloriesBurned,
    this.unit,
    this.value,
    this.levelName,
    required this.createdAt,
  });

  /// Create ExerciseLog from Firestore map
  factory ExerciseLog.fromMap(Map<String, dynamic> map) {
    // Helper to parse DateTime
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    // Helper to safely convert to double
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

    return ExerciseLog(
      id: map['id'] as String? ?? '',
      exerciseId: map['exerciseId'] as String? ?? '',
      exerciseName: map['exerciseName'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      durationMinutes: toDouble(map['durationMinutes']),
      caloriesBurned: toDouble(map['caloriesBurned']),
      unit: map['unit'] as String?,
      value: map['value'] != null ? toDouble(map['value']) : null,
      levelName: map['levelName'] as String?,
      createdAt: parseDateTime(map['createdAt']) ?? DateTime.now(),
    );
  }

  /// Convert ExerciseLog to Firestore map
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'createdAt': Timestamp.fromDate(createdAt),
    };

    if (imageUrl != null) {
      map['imageUrl'] = imageUrl;
    }

    if (unit != null) {
      map['unit'] = unit;
    }

    if (value != null) {
      map['value'] = value;
    }

    if (levelName != null) {
      map['levelName'] = levelName;
    }

    return map;
  }

  ExerciseLog copyWith({
    String? id,
    String? exerciseId,
    String? exerciseName,
    String? imageUrl,
    double? durationMinutes,
    double? caloriesBurned,
    String? unit,
    double? value,
    String? levelName,
    DateTime? createdAt,
  }) {
    return ExerciseLog(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      imageUrl: imageUrl ?? this.imageUrl,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      unit: unit ?? this.unit,
      value: value ?? this.value,
      levelName: levelName ?? this.levelName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

