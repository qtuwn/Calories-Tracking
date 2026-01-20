import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../domain/diary/diary_entry.dart';
import '../../domain/diary/diary_cache.dart';
import '../../domain/diary/diary_repository.dart';
import '../../domain/diary/diary_service.dart';
import '../../data/diary/firestore_diary_repository.dart';
import '../../data/diary/shared_prefs_diary_cache.dart';
import '../../data/firebase/date_utils.dart';
import 'profile_providers.dart'; // For sharedPreferencesProvider

/// Helper class for creating consistent provider keys for diary data.
/// Ensures that identical dates always produce the same provider key,
/// preventing unnecessary Firestore stream recreation.
class DiaryProviderKey {
  const DiaryProviderKey._();

  /// Creates a provider key for diary entries for a specific user and date.
  /// The date is automatically normalized to ensure consistency.
  static String forDate({required String uid, required DateTime date}) {
    final normalizedDate = DateUtils.normalizeToMidnight(date);
    final dateString = DateUtils.normalizeToIsoString(normalizedDate);
    return '${uid}_$dateString';
  }

  /// Parses a provider key back into its components.
  /// Returns a record with uid and normalized DateTime.
  static ({String uid, DateTime day}) parse(String key) {
    final parts = key.split('_');
    if (parts.length != 2) {
      throw FormatException('Invalid diary provider key format: $key');
    }

    final uid = parts[0];
    final dateString = parts[1];

    // Parse the ISO date string back to DateTime
    final dateParts = dateString.split('-');
    if (dateParts.length != 3) {
      throw FormatException('Invalid date format in key: $dateString');
    }

    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);

    return (uid: uid, day: DateTime(year, month, day));
  }
}

/// Provider for DiaryCache implementation
///
/// SharedPreferences is guaranteed to be available since it's preloaded in main.dart
/// and provided via ProviderScope.overrides. No Dummy cache needed.
final diaryCacheProvider = Provider<DiaryCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPrefsDiaryCache(prefs);
});

/// Provider for DiaryRepository implementation
final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return FirestoreDiaryRepository();
});

/// Provider for DiaryService
final diaryServiceProvider = Provider<DiaryService>((ref) {
  final repository = ref.read(diaryRepositoryProvider);
  final cache = ref.read(diaryCacheProvider);
  return DiaryService(repository, cache);
});

/// Stream provider for diary entries for a specific day, with cache-first logic.
///
/// This is the primary provider for UI to consume diary entries for a date.
/// Uses normalized date string as family key to prevent unnecessary stream recreation.
///
/// Usage:
/// ```dart
/// // Create a normalized key for the date
/// final dateKey = DiaryProviderKey.forDate(uid: userId, date: selectedDate);
/// final entriesAsync = ref.watch(diaryEntriesForDayProvider(dateKey));
/// entriesAsync.when(
///   data: (entries) => ListView(...),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final diaryEntriesForDayProvider = StreamProvider.autoDispose
    .family<List<DiaryEntry>, String>((ref, key) {
      final params = DiaryProviderKey.parse(key);
      debugPrint(
        '[DiaryEntriesForDayProvider] 🔵 Setting up diary entries stream for uid=${params.uid}, day=${params.day}',
      );
      final service = ref.watch(diaryServiceProvider);
      return service.watchEntriesForDayWithCache(params.uid, params.day);
    });

/// Future provider to load diary entries for a day once, prioritizing cache.
///
/// Useful for one-time loads where you don't need a stream.
final diaryLoadOnceProvider = FutureProvider.autoDispose
    .family<List<DiaryEntry>, ({String uid, DateTime day})>((ref, params) {
      debugPrint(
        '[DiaryLoadOnceProvider] 🔵 Loading diary entries once for uid=${params.uid}, day=${params.day}',
      );
      final service = ref.watch(diaryServiceProvider);
      return service.loadEntriesForDayOnce(params.uid, params.day);
    });
