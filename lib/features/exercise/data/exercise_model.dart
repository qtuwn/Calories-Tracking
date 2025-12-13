import 'package:cloud_firestore/cloud_firestore.dart';

/// Exercise unit types
enum ExerciseUnit {
  time('time'),
  distance('distance'),
  level('level');

  final String value;
  const ExerciseUnit(this.value);

  static ExerciseUnit fromString(String? value) {
    return ExerciseUnit.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ExerciseUnit.time,
    );
  }
}

/// Exercise level with name and MET value
class ExerciseLevel {
  final String name;
  final double met;

  ExerciseLevel({
    required this.name,
    required this.met,
  });

  factory ExerciseLevel.fromMap(Map<String, dynamic> map) {
    return ExerciseLevel(
      name: map['name'] as String? ?? '',
      met: (map['met'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'met': met,
    };
  }
}

/// Exercise model representing an exercise in the catalog
class Exercise {
  final String id;
  final String name;
  final String nameLower;
  final String imageUrl;
  final ExerciseUnit unit;
  final List<ExerciseLevel> levels;
  final double? metPerHour;
  final double? metPerKm;
  final String? description;
  final bool isEnabled;
  final DateTime? updatedAt;

  Exercise({
    required this.id,
    required this.name,
    required this.nameLower,
    required this.imageUrl,
    required this.unit,
    required this.levels,
    this.metPerHour,
    this.metPerKm,
    this.description,
    this.isEnabled = true,
    this.updatedAt,
  });

  factory Exercise.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final updatedAtTimestamp = data['updatedAt'] as Timestamp?;
    
    // Parse levels
    final levelsData = data['levels'] as List<dynamic>? ?? [];
    final levels = levelsData
        .map((e) => ExerciseLevel.fromMap(e as Map<String, dynamic>))
        .toList();

    return Exercise(
      id: doc.id,
      name: data['name'] as String? ?? '',
      nameLower: data['nameLower'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      unit: ExerciseUnit.fromString(data['unit'] as String?),
      levels: levels,
      metPerHour: (data['metPerHour'] as num?)?.toDouble(),
      metPerKm: (data['metPerKm'] as num?)?.toDouble(),
      description: data['description'] as String?,
      isEnabled: data['isEnabled'] as bool? ?? true,
      updatedAt: updatedAtTimestamp?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nameLower': nameLower,
      'imageUrl': imageUrl,
      'unit': unit.value,
      'levels': levels.map((e) => e.toMap()).toList(),
      'metPerHour': metPerHour,
      'metPerKm': metPerKm,
      'description': description,
      'isEnabled': isEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Exercise copyWith({
    String? id,
    String? name,
    String? nameLower,
    String? imageUrl,
    ExerciseUnit? unit,
    List<ExerciseLevel>? levels,
    double? metPerHour,
    double? metPerKm,
    String? description,
    bool? isEnabled,
    DateTime? updatedAt,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      nameLower: nameLower ?? this.nameLower,
      imageUrl: imageUrl ?? this.imageUrl,
      unit: unit ?? this.unit,
      levels: levels ?? this.levels,
      metPerHour: metPerHour ?? this.metPerHour,
      metPerKm: metPerKm ?? this.metPerKm,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate calories burned for time-based exercises
  /// Formula: MET * 3.5 * weight (kg) / 200 * minutes
  double calculateCaloriesTime(double weight, double minutes) {
    if (metPerHour == null || weight <= 0 || minutes <= 0) return 0.0;
    return (metPerHour! * 3.5 * weight / 200) * minutes;
  }

  /// Calculate calories burned for distance-based exercises
  /// Formula: MET * distance (km) * 3.5 * weight (kg) / 200 * 60
  double calculateCaloriesDistance(double weight, double distanceKm) {
    if (metPerKm == null || weight <= 0 || distanceKm <= 0) return 0.0;
    return metPerKm! * distanceKm * 3.5 * weight / 200 * 60;
  }

  /// Calculate calories burned for level-based exercises
  /// Formula: MET(level) * 3.5 * weight (kg) / 200 * minutes
  double calculateCaloriesLevel(double weight, double minutes, int levelIndex) {
    if (levels.isEmpty || levelIndex < 0 || levelIndex >= levels.length) {
      return 0.0;
    }
    if (weight <= 0 || minutes <= 0) return 0.0;
    
    final level = levels[levelIndex];
    return (level.met * 3.5 * weight / 200) * minutes;
  }
}

