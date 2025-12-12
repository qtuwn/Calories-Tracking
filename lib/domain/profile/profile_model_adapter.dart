import 'profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Compatibility adapter for ProfileModel
/// 
/// This allows gradual migration from ProfileModel to Profile domain model.
/// ProfileModel wraps Profile and provides the same API as before.
class ProfileModel {
  final Profile _profile;

  ProfileModel._(this._profile);

  // Expose all Profile fields
  String? get nickname => _profile.nickname;
  int? get age => _profile.age;
  String? get dobIso => _profile.dobIso;
  String? get gender => _profile.gender;
  double? get height => _profile.height;
  int? get heightCm => _profile.heightCm;
  double? get weight => _profile.weight;
  double? get weightKg => _profile.weightKg;
  double? get bmi => _profile.bmi;
  String? get goalType => _profile.goalType;
  double? get targetWeight => _profile.targetWeight;
  double? get weeklyDeltaKg => _profile.weeklyDeltaKg;
  String? get activityLevel => _profile.activityLevel;
  double? get activityMultiplier => _profile.activityMultiplier;
  double? get bmr => _profile.bmr;
  double? get tdee => _profile.tdee;
  double? get targetKcal => _profile.targetKcal;
  double? get proteinPercent => _profile.proteinPercent;
  double? get carbPercent => _profile.carbPercent;
  double? get fatPercent => _profile.fatPercent;
  double? get proteinGrams => _profile.proteinGrams;
  double? get carbGrams => _profile.carbGrams;
  double? get fatGrams => _profile.fatGrams;
  DateTime? get goalDate => _profile.goalDate;
  bool get isCurrent => _profile.isCurrent;
  DateTime? get createdAt => _profile.createdAt;
  String? get photoBase64 => _profile.photoBase64;

  // Expose Profile methods
  String get genderLabel => _profile.genderLabel;
  String get activityLevelLabel => _profile.activityLevelLabel;
  String get goalTypeLabel => _profile.goalTypeLabel;
  String get birthDateString => _profile.birthDateString;

  /// Create ProfileModel from Profile
  factory ProfileModel.fromProfile(Profile profile) {
    return ProfileModel._(profile);
  }

  /// Convert to Profile
  Profile toProfile() => _profile;

  /// Create ProfileModel from Firestore map (for backward compatibility)
  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    // Helper functions (same as in old ProfileModel)
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

    final profile = Profile(
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

    return ProfileModel.fromProfile(profile);
  }

  /// Convert to Firestore map (for backward compatibility)
  Map<String, dynamic> toMap() {
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
    if (goalDate != null) map['goalDate'] = goalDate!.toIso8601String();
    if (photoBase64 != null) map['photoBase64'] = photoBase64;

    map['createdAt'] = FieldValue.serverTimestamp();

    return map;
  }

  /// Create a copy with updated fields
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
    return ProfileModel.fromProfile(_profile.copyWith(
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
      goalDate: goalDate,
      isCurrent: isCurrent,
      createdAt: createdAt,
      photoBase64: photoBase64,
    ));
  }

  /// Factory for creating from OnboardingModel and NutritionResult
  /// This is kept for backward compatibility
  factory ProfileModel.fromOnboarding({
    required dynamic onboarding,
    required dynamic result,
  }) {
    // This will be implemented by the caller using the old logic
    // For now, we'll need to keep the old ProfileModel.fromOnboarding in the old location
    // and have it create a Profile, then wrap it
    throw UnimplementedError(
        'Use the old ProfileModel.fromOnboarding from features/onboarding/domain/profile_model.dart for now');
  }
}

