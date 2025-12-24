/// Shared date utility functions for Firestore repositories.
/// 
/// This utility provides consistent date normalization across all repositories
/// to ensure dates are stored and queried in a standardized format.
class DateUtils {
  DateUtils._(); // Private constructor to prevent instantiation

  /// Normalize a DateTime to midnight (start of day) in local time.
  /// 
  /// This is useful for date comparisons and range queries where you want
  /// to ignore the time component.
  /// 
  /// Example:
  /// ```dart
  /// final date = DateTime(2024, 1, 15, 14, 30, 45);
  /// final normalized = DateUtils.normalizeToMidnight(date);
  /// // Returns: DateTime(2024, 1, 15, 0, 0, 0)
  /// ```
  static DateTime normalizeToMidnight(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Normalize a DateTime to ISO string format (yyyy-MM-dd).
  /// 
  /// This format is used for storing dates as strings in Firestore,
  /// which allows efficient querying by date without timezone issues.
  /// 
  /// Example:
  /// ```dart
  /// final date = DateTime(2024, 1, 15, 14, 30, 45);
  /// final normalized = DateUtils.normalizeToIsoString(date);
  /// // Returns: "2024-01-15"
  /// ```
  static String normalizeToIsoString(DateTime date) {
    final normalized = normalizeToMidnight(date);
    return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
  }
}

