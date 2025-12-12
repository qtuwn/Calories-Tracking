import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../domain/diary/diary_entry.dart';
import '../../domain/diary/diary_cache.dart';
import '../../domain/diary/diary_repository.dart';
import '../../domain/diary/diary_service.dart';
import '../../data/diary/firestore_diary_repository.dart';
import '../../data/diary/shared_prefs_diary_cache.dart';
import 'profile_providers.dart'; // For sharedPreferencesProvider

/// Provider for DiaryCache implementation
final diaryCacheProvider = Provider<DiaryCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) {
    debugPrint('[DiaryCacheProvider] ⚠️ SharedPreferences not ready, returning dummy cache');
    return _DummyDiaryCache(); // Fallback
  }
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
/// 
/// Usage:
/// ```dart
/// final entriesAsync = ref.watch(diaryEntriesForDayProvider(selectedDate));
/// entriesAsync.when(
///   data: (entries) => ListView(...),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final diaryEntriesForDayProvider = StreamProvider.autoDispose
    .family<List<DiaryEntry>, ({String uid, DateTime day})>((ref, params) {
  debugPrint('[DiaryEntriesForDayProvider] 🔵 Setting up diary entries stream for uid=${params.uid}, day=${params.day}');
  final service = ref.watch(diaryServiceProvider);
  return service.watchEntriesForDayWithCache(params.uid, params.day);
});

/// Future provider to load diary entries for a day once, prioritizing cache.
/// 
/// Useful for one-time loads where you don't need a stream.
final diaryLoadOnceProvider = FutureProvider.autoDispose
    .family<List<DiaryEntry>, ({String uid, DateTime day})>((ref, params) {
  debugPrint('[DiaryLoadOnceProvider] 🔵 Loading diary entries once for uid=${params.uid}, day=${params.day}');
  final service = ref.watch(diaryServiceProvider);
  return service.loadEntriesForDayOnce(params.uid, params.day);
});

/// Dummy DiaryCache implementation for when SharedPreferences is not ready
class _DummyDiaryCache implements DiaryCache {
  @override
  Future<void> clearAllForUser(String uid) async {
    debugPrint('[DummyDiaryCache] clearAllForUser called (no-op)');
  }

  @override
  Future<void> clearEntriesForDay(String uid, DateTime day) async {
    debugPrint('[DummyDiaryCache] clearEntriesForDay called (no-op)');
  }

  @override
  Future<List<DiaryEntry>> loadEntriesForDay(String uid, DateTime day) async {
    debugPrint('[DummyDiaryCache] loadEntriesForDay called (no-op)');
    return [];
  }

  @override
  Future<void> saveEntriesForDay(String uid, DateTime day, List<DiaryEntry> entries) async {
    debugPrint('[DummyDiaryCache] saveEntriesForDay called (no-op)');
  }
}

