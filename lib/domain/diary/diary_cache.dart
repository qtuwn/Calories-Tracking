import 'diary_entry.dart';

/// Abstract interface for local diary entry caching.
/// 
/// This interface defines the contract for storing and retrieving
/// diary entries from a local cache, organized by user ID and date.
/// No Flutter or Firebase imports are allowed in this domain layer file.
abstract class DiaryCache {
  /// Loads cached diary entries for a specific user and date.
  /// Returns empty list if no entries are found in the cache.
  Future<List<DiaryEntry>> loadEntriesForDay(String uid, DateTime day);

  /// Saves the given diary entries to the local cache for a specific user and date.
  Future<void> saveEntriesForDay(String uid, DateTime day, List<DiaryEntry> entries);

  /// Clears cached entries for a specific user and date.
  Future<void> clearEntriesForDay(String uid, DateTime day);

  /// Clears all cached diary entries for a user.
  Future<void> clearAllForUser(String uid);
}

