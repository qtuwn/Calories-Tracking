import 'package:cloud_firestore/cloud_firestore.dart';
import 'onboarding_model.dart';
import 'nutrition_result.dart';

/// Profile model for Firestore
class ProfileModel {
  final String? nickname;
  final int? age;
  final String? dobIso;
  final String? gender;
  final double? height;
  final int? heightCm;
  final double? weight;
  final double? weightKg;
  final double? bmi;
  final String? goalType;
  final double? targetWeight;
  final double? weeklyDeltaKg;
  final String? activityLevel;
  final double? activityMultiplier;
  final double? bmr;
  final double? tdee;
  final double? targetKcal;
  final double? proteinPercent;
  final double? carbPercent;
  final double? fatPercent;
  final double? proteinGrams;
  final double? carbGrams;
  final double? fatGrams;
  final DateTime? goalDate;
  final bool isCurrent;
  final DateTime? createdAt;
  final String? photoBase64;

  const ProfileModel({
    this.nickname,
    this.age,
    this.dobIso,
    this.gender,
    this.height,
    this.heightCm,
    this.weight,
    this.weightKg,
    this.bmi,
    this.goalType,
    this.targetWeight,
    this.weeklyDeltaKg,
    this.activityLevel,
    this.activityMultiplier,
    this.bmr,
    this.tdee,
    this.targetKcal,
    this.proteinPercent,
    this.carbPercent,
    this.fatPercent,
    this.proteinGrams,
    this.carbGrams,
    this.fatGrams,
    this.goalDate,
    this.isCurrent = true,
    this.createdAt,
    this.photoBase64,
  });

  /// Build ProfileModel from OnboardingModel and NutritionResult
  /// Uses computed weight values (from half-kg if available) for Firestore storage
  factory ProfileModel.fromOnboarding({
    required OnboardingModel onboarding,
    required NutritionResult result,
  }) {
    return ProfileModel(
      nickname: onboarding.nickname,
      age: onboarding.age,
      dobIso: onboarding.dobIso,
      gender: onboarding.gender,
      height: onboarding.height,
      heightCm: onboarding.heightCm,
      weight: onboarding.weightKgComputed, // Use computed value
      weightKg: onboarding
          .weightKgComputed, // Use computed value (double for Firestore)
      bmi: onboarding.bmi,
      goalType: onboarding.goalType,
      targetWeight: onboarding.targetWeightComputed, // Use computed value
      weeklyDeltaKg: onboarding.weeklyDeltaKg,
      activityLevel: onboarding.activityLevel,
      activityMultiplier: onboarding.activityMultiplier,
      bmr: result.bmr,
      tdee: result.tdee,
      targetKcal: result.targetKcal,
      proteinPercent: result.proteinPercent,
      carbPercent: result.carbPercent,
      fatPercent: result.fatPercent,
      proteinGrams: result.proteinGrams,
      carbGrams: result.carbGrams,
      fatGrams: result.fatGrams,
      goalDate: result.goalDate,
      isCurrent: true,
      createdAt: DateTime.now(),
      photoBase64: null,
    );
  }

  /// Build ProfileModel from Firestore document data (Map)
  /// Handles null safety and type conversions safely
  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    // Helper to safely parse DateTime from various formats
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
    double? toDouble(dynamic value) {
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

    // Helper to safely convert to int
    int? toInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        try {
          return int.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return ProfileModel(
      nickname: map['nickname'] as String?,
      age: toInt(map['age']),
      dobIso: map['dobIso'] as String?,
      gender: map['gender'] as String?,
      height: toDouble(map['height']),
      heightCm: toInt(map['heightCm']),
      weight: toDouble(map['weight']),
      weightKg: toDouble(map['weightKg']),
      bmi: toDouble(map['bmi']),
      goalType: map['goalType'] as String?,
      targetWeight: toDouble(map['targetWeight']),
      weeklyDeltaKg: toDouble(map['weeklyDeltaKg']),
      activityLevel: map['activityLevel'] as String?,
      activityMultiplier: toDouble(map['activityMultiplier']),
      bmr: toDouble(map['bmr']),
      tdee: toDouble(map['tdee']),
      targetKcal: toDouble(map['targetKcal']),
      proteinPercent: toDouble(map['proteinPercent']),
      carbPercent: toDouble(map['carbPercent']),
      fatPercent: toDouble(map['fatPercent']),
      proteinGrams: toDouble(map['proteinGrams']),
      carbGrams: toDouble(map['carbGrams']),
      fatGrams: toDouble(map['fatGrams']),
      goalDate: parseDateTime(map['goalDate']),
      isCurrent: map['isCurrent'] as bool? ?? true,
      createdAt: parseDateTime(map['createdAt']),
      photoBase64: map['photoBase64'] as String?,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'isCurrent': isCurrent};

    // Add fields only if they are not null
    // Note: Type normalization will be handled by ProfileRepository._normalizeProfileData
    if (nickname != null) {
      map['nickname'] = nickname;
    }
    if (age != null) {
      map['age'] = age;
    }
    if (dobIso != null) {
      map['dobIso'] = dobIso;
    }
    if (gender != null) {
      map['gender'] = gender;
    }
    if (height != null) {
      map['height'] = height;
    }
    if (heightCm != null) {
      map['heightCm'] = heightCm; // Keep as int, will be normalized if needed
    }
    if (weight != null) {
      map['weight'] = weight;
    }
    if (weightKg != null) {
      map['weightKg'] = weightKg;
    }
    if (bmi != null) {
      map['bmi'] = bmi;
    }
    if (goalType != null) {
      map['goalType'] = goalType;
    }
    if (targetWeight != null) {
      map['targetWeight'] = targetWeight;
    }
    if (weeklyDeltaKg != null) {
      map['weeklyDeltaKg'] = weeklyDeltaKg;
    }
    if (activityLevel != null) {
      map['activityLevel'] = activityLevel;
    }
    if (activityMultiplier != null) {
      map['activityMultiplier'] = activityMultiplier;
    }
    if (bmr != null) {
      map['bmr'] = bmr;
    }
    if (tdee != null) {
      map['tdee'] = tdee;
    }
    if (targetKcal != null) {
      map['targetKcal'] = targetKcal;
    }
    if (proteinPercent != null) {
      map['proteinPercent'] = proteinPercent;
    }
    if (carbPercent != null) {
      map['carbPercent'] = carbPercent;
    }
    if (fatPercent != null) {
      map['fatPercent'] = fatPercent;
    }
    if (proteinGrams != null) {
      map['proteinGrams'] = proteinGrams;
    }
    if (carbGrams != null) {
      map['carbGrams'] = carbGrams;
    }
    if (fatGrams != null) {
      map['fatGrams'] = fatGrams;
    }
    if (goalDate != null) {
      map['goalDate'] = goalDate!.toIso8601String();
    }
    if (photoBase64 != null) {
      map['photoBase64'] = photoBase64;
    }

    // Use serverTimestamp for createdAt
    map['createdAt'] = FieldValue.serverTimestamp();

    return map;
  }

  /// Create a copy of this ProfileModel with updated fields
  ProfileModel copyWith({
    String? nickname,
    int? age,
    String? dobIso,
    String? gender,
    double? height,
    int? heightCm,
    double? weight,
    double? weightKg,
    double? bmi,
    String? goalType,
    double? targetWeight,
    double? weeklyDeltaKg,
    String? activityLevel,
    double? activityMultiplier,
    double? bmr,
    double? tdee,
    double? targetKcal,
    double? proteinPercent,
    double? carbPercent,
    double? fatPercent,
    double? proteinGrams,
    double? carbGrams,
    double? fatGrams,
    DateTime? goalDate,
    bool? isCurrent,
    DateTime? createdAt,
    String? photoBase64,
  }) {
    return ProfileModel(
      nickname: nickname ?? this.nickname,
      age: age ?? this.age,
      dobIso: dobIso ?? this.dobIso,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      heightCm: heightCm ?? this.heightCm,
      weight: weight ?? this.weight,
      weightKg: weightKg ?? this.weightKg,
      bmi: bmi ?? this.bmi,
      goalType: goalType ?? this.goalType,
      targetWeight: targetWeight ?? this.targetWeight,
      weeklyDeltaKg: weeklyDeltaKg ?? this.weeklyDeltaKg,
      activityLevel: activityLevel ?? this.activityLevel,
      activityMultiplier: activityMultiplier ?? this.activityMultiplier,
      bmr: bmr ?? this.bmr,
      tdee: tdee ?? this.tdee,
      targetKcal: targetKcal ?? this.targetKcal,
      proteinPercent: proteinPercent ?? this.proteinPercent,
      carbPercent: carbPercent ?? this.carbPercent,
      fatPercent: fatPercent ?? this.fatPercent,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbGrams: carbGrams ?? this.carbGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      goalDate: goalDate ?? this.goalDate,
      isCurrent: isCurrent ?? this.isCurrent,
      createdAt: createdAt ?? this.createdAt,
      photoBase64: photoBase64 ?? this.photoBase64,
    );
  }
}
