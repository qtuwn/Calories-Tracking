import 'diary_entry.dart';

/// Abstract repository interface for DiaryEntry operations
/// 
/// This is a pure domain interface with no dependencies on Flutter or Firebase.
/// Implementations should be in the data layer.
abstract class DiaryRepository {
  /// Watch diary entries for a specific date
  /// Returns a stream that emits a list of DiaryEntry for the given date
  Stream<List<DiaryEntry>> watchEntriesForDay(String uid, DateTime day);

  /// Fetch diary entries for a specific date (one-time load)
  Future<List<DiaryEntry>> fetchEntriesForDay(String uid, DateTime day);

  /// Add a diary entry
  Future<void> addEntry(DiaryEntry entry);

  /// Update a diary entry
  Future<void> updateEntry(DiaryEntry entry);

  /// Delete a diary entry
  Future<void> deleteEntry(String uid, String entryId);

  /// Get diary entries for a date range (for statistics/analytics)
  Future<List<DiaryEntry>> fetchEntriesForDateRange(
    String uid,
    DateTime startDate,
    DateTime endDate,
  );
}

