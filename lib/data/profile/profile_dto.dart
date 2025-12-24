import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/profile/profile.dart';

/// Data Transfer Object for Profile
/// 
/// Handles conversion between Firestore documents and domain Profile entities.
class ProfileDto {
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
  final Timestamp? goalDate;
  final bool isCurrent;
  final Timestamp? createdAt;
  /// @deprecated Use photoUrl instead. Base64 support will be removed after migration.
  /// TODO: Remove photoBase64 field after migration completes (all profiles migrated to Cloudinary)
  final String? photoBase64;
  final String? photoUrl;

  ProfileDto({
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
    this.photoUrl,
  });

  /// Create DTO from Firestore document
  factory ProfileDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

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

    final goalDateValue = data['goalDate'];
    final createdAtValue = data['createdAt'];

    return ProfileDto(
      nickname: data['nickname'] as String?,
      age: toInt(data['age']),
      dobIso: data['dobIso'] as String?,
      gender: data['gender'] as String?,
      height: toDouble(data['height']),
      heightCm: toInt(data['heightCm']),
      weight: toDouble(data['weight']),
      weightKg: toDouble(data['weightKg']),
      bmi: toDouble(data['bmi']),
      goalType: data['goalType'] as String?,
      targetWeight: toDouble(data['targetWeight']),
      weeklyDeltaKg: toDouble(data['weeklyDeltaKg']),
      activityLevel: data['activityLevel'] as String?,
      activityMultiplier: toDouble(data['activityMultiplier']),
      bmr: toDouble(data['bmr']),
      tdee: toDouble(data['tdee']),
      targetKcal: toDouble(data['targetKcal']),
      proteinPercent: toDouble(data['proteinPercent']),
      carbPercent: toDouble(data['carbPercent']),
      fatPercent: toDouble(data['fatPercent']),
      proteinGrams: toDouble(data['proteinGrams']),
      carbGrams: toDouble(data['carbGrams']),
      fatGrams: toDouble(data['fatGrams']),
      goalDate: goalDateValue is Timestamp
          ? goalDateValue
          : (goalDateValue != null
              ? Timestamp.fromDate(parseDateTime(goalDateValue)!)
              : null),
      isCurrent: data['isCurrent'] as bool? ?? true,
      createdAt: createdAtValue is Timestamp
          ? createdAtValue
          : (createdAtValue != null
              ? Timestamp.fromDate(parseDateTime(createdAtValue)!)
              : null),
      photoBase64: data['photoBase64'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  /// Convert DTO to Firestore map
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{'isCurrent': isCurrent};

    if (nickname != null) map['nickname'] = nickname;
    if (age != null) map['age'] = age;
    if (dobIso != null) map['dobIso'] = dobIso;
    if (gender != null) map['gender'] = gender;
    if (height != null) map['height'] = height;
    if (heightCm != null) map['heightCm'] = heightCm;
    if (weight != null) map['weight'] = weight;
    if (weightKg != null) map['weightKg'] = weightKg;
    if (bmi != null) map['bmi'] = bmi;
    if (goalType != null) map['goalType'] = goalType;
    if (targetWeight != null) map['targetWeight'] = targetWeight;
    if (weeklyDeltaKg != null) map['weeklyDeltaKg'] = weeklyDeltaKg;
    if (activityLevel != null) map['activityLevel'] = activityLevel;
    if (activityMultiplier != null) map['activityMultiplier'] = activityMultiplier;
    if (bmr != null) map['bmr'] = bmr;
    if (tdee != null) map['tdee'] = tdee;
    if (targetKcal != null) map['targetKcal'] = targetKcal;
    if (proteinPercent != null) map['proteinPercent'] = proteinPercent;
    if (carbPercent != null) map['carbPercent'] = carbPercent;
    if (fatPercent != null) map['fatPercent'] = fatPercent;
    if (proteinGrams != null) map['proteinGrams'] = proteinGrams;
    if (carbGrams != null) map['carbGrams'] = carbGrams;
    if (fatGrams != null) map['fatGrams'] = fatGrams;
    if (goalDate != null) {
      map['goalDate'] = goalDate!.toDate().toIso8601String();
    }
    if (photoBase64 != null) map['photoBase64'] = photoBase64;
    if (photoUrl != null) map['photoUrl'] = photoUrl;

    // Use serverTimestamp for createdAt
    map['createdAt'] = FieldValue.serverTimestamp();

    return map;
  }

  /// Convert DTO to domain entity
  Profile toDomain() {
    return Profile(
      nickname: nickname,
      age: age,
      dobIso: dobIso,
      gender: gender,
      height: height,
      heightCm: heightCm,
      weight: weight,
      weightKg: weightKg,
      bmi: bmi,
      goalType: goalType,
      targetWeight: targetWeight,
      weeklyDeltaKg: weeklyDeltaKg,
      activityLevel: activityLevel,
      activityMultiplier: activityMultiplier,
      bmr: bmr,
      tdee: tdee,
      targetKcal: targetKcal,
      proteinPercent: proteinPercent,
      carbPercent: carbPercent,
      fatPercent: fatPercent,
      proteinGrams: proteinGrams,
      carbGrams: carbGrams,
      fatGrams: fatGrams,
      goalDate: goalDate?.toDate(),
      isCurrent: isCurrent,
      createdAt: createdAt?.toDate(),
      photoBase64: photoBase64,
      photoUrl: photoUrl,
    );
  }

  /// Create DTO from domain entity
  factory ProfileDto.fromDomain(Profile profile) {
    return ProfileDto(
      nickname: profile.nickname,
      age: profile.age,
      dobIso: profile.dobIso,
      gender: profile.gender,
      height: profile.height,
      heightCm: profile.heightCm,
      weight: profile.weight,
      weightKg: profile.weightKg,
      bmi: profile.bmi,
      goalType: profile.goalType,
      targetWeight: profile.targetWeight,
      weeklyDeltaKg: profile.weeklyDeltaKg,
      activityLevel: profile.activityLevel,
      activityMultiplier: profile.activityMultiplier,
      bmr: profile.bmr,
      tdee: profile.tdee,
      targetKcal: profile.targetKcal,
      proteinPercent: profile.proteinPercent,
      carbPercent: profile.carbPercent,
      fatPercent: profile.fatPercent,
      proteinGrams: profile.proteinGrams,
      carbGrams: profile.carbGrams,
      fatGrams: profile.fatGrams,
      goalDate: profile.goalDate != null
          ? Timestamp.fromDate(profile.goalDate!)
          : null,
      isCurrent: profile.isCurrent,
      createdAt: profile.createdAt != null
          ? Timestamp.fromDate(profile.createdAt!)
          : null,
      photoBase64: profile.photoBase64,
      photoUrl: profile.photoUrl,
    );
  }
}

