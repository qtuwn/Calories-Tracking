import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a single water intake entry.
/// 
/// Each entry records a specific amount of water consumed at a particular time.
/// Water intake has 0 calories and does not affect any calorie-related metrics.
/// 
/// Entries are stored in Firestore at: users/{uid}/waterIntake/{entryId}
class WaterIntakeEntry {
  final String id;
  final String userId;
  final int amountMl; // Amount in milliliters
  final DateTime timestamp; // When this water was consumed
  final String date; // ISO date string: "yyyy-MM-dd" for easy querying by date

  const WaterIntakeEntry({
    required this.id,
    required this.userId,
    required this.amountMl,
    required this.timestamp,
    required this.date,
  });

  /// Create WaterIntakeEntry from Firestore document
  factory WaterIntakeEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Helper to parse DateTime from various formats
    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return WaterIntakeEntry(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      amountMl: data['amountMl'] as int? ?? 0,
      timestamp: parseTimestamp(data['timestamp']),
      date: data['date'] as String? ?? '',
    );
  }

  /// Convert WaterIntakeEntry to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amountMl': amountMl,
      'timestamp': Timestamp.fromDate(timestamp),
      'date': date,
    };
  }

  /// Factory method to create a new entry for today
  factory WaterIntakeEntry.forToday({
    required String userId,
    required int amountMl,
  }) {
    final now = DateTime.now();
    final date = _normalizeDate(now);
    
    return WaterIntakeEntry(
      id: '', // Will be set by Firestore
      userId: userId,
      amountMl: amountMl,
      timestamp: now,
      date: date,
    );
  }

  /// Normalize date to ISO string (yyyy-MM-dd)
  static String _normalizeDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
  }

  WaterIntakeEntry copyWith({
    String? id,
    String? userId,
    int? amountMl,
    DateTime? timestamp,
    String? date,
  }) {
    return WaterIntakeEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amountMl: amountMl ?? this.amountMl,
      timestamp: timestamp ?? this.timestamp,
      date: date ?? this.date,
    );
  }
}

