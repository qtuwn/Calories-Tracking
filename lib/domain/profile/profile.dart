/// Profile domain model
/// 
/// Pure domain entity representing a user's profile.
/// No dependencies on Flutter or Firebase.

/// Profile entity
class Profile {
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
  /// @deprecated Use photoUrl instead. Base64 support will be removed after migration.
  /// TODO: Remove photoBase64 field after migration completes (all profiles migrated to Cloudinary)
  final String? photoBase64;
  final String? photoUrl;

  const Profile({
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

  /// Create a copy with updated fields
  Profile copyWith({
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
    String? photoUrl,
  }) {
    return Profile(
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
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  /// Get human-readable gender label in Vietnamese
  String get genderLabel {
    switch (gender?.toLowerCase()) {
      case 'male':
        return 'Nam';
      case 'female':
        return 'Nữ';
      case 'other':
        return 'Khác';
      default:
        return gender ?? '-';
    }
  }

  /// Get human-readable activity level label in Vietnamese
  String get activityLevelLabel {
    switch (activityLevel?.toLowerCase()) {
      case 'sedentary':
        return 'Không tập luyện/Ít vận động';
      case 'light':
        return 'Vận động nhẹ nhàng';
      case 'moderate':
        return 'Chăm chỉ luyện tập';
      case 'very_active':
        return 'Rất năng động / Cực kỳ năng động';
      default:
        return activityLevel ?? '-';
    }
  }

  /// Get human-readable goal type label in Vietnamese
  String get goalTypeLabel {
    switch (goalType?.toLowerCase()) {
      case 'lose':
        return 'Giảm cân';
      case 'maintain':
        return 'Duy trì';
      case 'gain':
        return 'Tăng cân';
      default:
        return goalType ?? '-';
    }
  }

  /// Get formatted birth date string (dd/MM/yyyy)
  String get birthDateString {
    if (dobIso == null) return '-';
    try {
      final date = DateTime.parse(dobIso!);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    } catch (_) {
      return dobIso ?? '-';
    }
  }

  /// Convert Profile to JSON map
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'isCurrent': isCurrent,
    };

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
    if (createdAt != null) map['createdAt'] = createdAt!.toIso8601String();
    if (photoBase64 != null) map['photoBase64'] = photoBase64;
    if (photoUrl != null) map['photoUrl'] = photoUrl;

    return map;
  }

  /// Create Profile from JSON map
  factory Profile.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
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

    return Profile(
      nickname: json['nickname'] as String?,
      age: toInt(json['age']),
      dobIso: json['dobIso'] as String?,
      gender: json['gender'] as String?,
      height: toDouble(json['height']),
      heightCm: toInt(json['heightCm']),
      weight: toDouble(json['weight']),
      weightKg: toDouble(json['weightKg']),
      bmi: toDouble(json['bmi']),
      goalType: json['goalType'] as String?,
      targetWeight: toDouble(json['targetWeight']),
      weeklyDeltaKg: toDouble(json['weeklyDeltaKg']),
      activityLevel: json['activityLevel'] as String?,
      activityMultiplier: toDouble(json['activityMultiplier']),
      bmr: toDouble(json['bmr']),
      tdee: toDouble(json['tdee']),
      targetKcal: toDouble(json['targetKcal']),
      proteinPercent: toDouble(json['proteinPercent']),
      carbPercent: toDouble(json['carbPercent']),
      fatPercent: toDouble(json['fatPercent']),
      proteinGrams: toDouble(json['proteinGrams']),
      carbGrams: toDouble(json['carbGrams']),
      fatGrams: toDouble(json['fatGrams']),
      goalDate: parseDateTime(json['goalDate']),
      isCurrent: json['isCurrent'] as bool? ?? true,
      createdAt: parseDateTime(json['createdAt']),
      photoBase64: json['photoBase64'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

