import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for a weight entry (single weight measurement on a specific date)
/// 
/// Weight entries are stored in Firestore as:
/// users/{uid}/weights/{weightEntryId}
/// 
/// Each entry represents a weight measurement for a specific calendar date.
/// Multiple entries can exist per day, but typically we store one per day.
class WeightEntry {
  final String id; // Firestore document ID
  final double weightKg; // Weight in kilograms
  final DateTime date; // Local calendar date of the measurement (normalized to midnight)
  final DateTime createdAt; // When the entry was created
  final DateTime? updatedAt; // When the entry was last updated

  WeightEntry({
    required this.id,
    required this.weightKg,
    required this.date,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create WeightEntry from Firestore document
  factory WeightEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WeightEntry.fromMap(data, doc.id);
  }

  /// Create WeightEntry from Firestore map
  factory WeightEntry.fromMap(Map<String, dynamic> map, String id) {
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

    final dateValue = parseDateTime(map['date']);
    if (dateValue == null) {
      throw Exception('WeightEntry: date field is required');
    }

    // Normalize date to midnight (local time)
    final normalizedDate = DateTime(dateValue.year, dateValue.month, dateValue.day);

    final weightValue = toDouble(map['weightKg']);
    if (weightValue == null) {
      throw Exception('WeightEntry: weightKg field is required');
    }

    return WeightEntry(
      id: id,
      weightKg: weightValue,
      date: normalizedDate,
      createdAt: parseDateTime(map['createdAt']) ?? normalizedDate,
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'weightKg': weightKg,
      'date': Timestamp.fromDate(date), // Store as Timestamp for easy querying
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  /// Create a copy with updated fields
  WeightEntry copyWith({
    String? id,
    double? weightKg,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      weightKg: weightKg ?? this.weightKg,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Normalize a DateTime to midnight (local calendar date)
  static DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get today's date normalized to midnight
  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

