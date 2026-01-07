import 'dart:async';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'diary_entry.dart';
import 'diary_repository.dart';
import 'diary_cache.dart';
import '../../features/diary/domain/services/meal_time_classifier.dart';
import '../../domain/foods/food.dart';
import '../../data/firebase/date_utils.dart';

/// Service for managing diary entries with a hybrid cache-first, then network strategy.
/// 
/// This service orchestrates between the local cache (DiaryCache) and
/// the remote data source (DiaryRepository) to provide instant UI feedback
/// and background synchronization.
class DiaryService {
  final DiaryRepository _repository;
  final DiaryCache _cache;

  DiaryService(this._repository, this._cache);

  /// Watches diary entries for a day, loading from cache first and then syncing with Firestore.
  /// 
  /// Emits the cached entries immediately if available.
  /// Then subscribes to Firestore updates, emitting new entries and saving them to cache.
  Stream<List<DiaryEntry>> watchEntriesForDayWithCache(String uid, DateTime day) {
    debugPrint('[DiaryService] 🔵 Watching diary entries for uid=$uid, day=$day');
    final controller = StreamController<List<DiaryEntry>>();

    // 1. Load from cache first and emit immediately
    _cache.loadEntriesForDay(uid, day).then((cachedEntries) {
      if (cachedEntries.isNotEmpty) {
        debugPrint('[DiaryService] ✅ Emitting ${cachedEntries.length} cached entries');
        controller.add(cachedEntries);
      } else {
        debugPrint('[DiaryService] ℹ️ No cached entries found');
        controller.add([]); // Emit empty list to show UI is ready
      }
    }).catchError((e, st) {
      debugPrint('[DiaryService] 🔥 Error loading from cache: $e');
      debugPrintStack(stackTrace: st);
      controller.add([]); // Emit empty list on cache error
    });

    // 2. Subscribe to Firestore updates
    final subscription = _repository.watchEntriesForDay(uid, day).listen(
      (firestoreEntries) async {
        if (firestoreEntries.isNotEmpty) {
          debugPrint('[DiaryService] ✅ Firestore updated: ${firestoreEntries.length} entries');
          controller.add(firestoreEntries);
          // Save to cache for future instant loads
          await _cache.saveEntriesForDay(uid, day, firestoreEntries);
        } else {
          debugPrint('[DiaryService] ℹ️ Firestore returned empty list');
          controller.add([]);
        }
      },
      onError: (error, stackTrace) {
        debugPrint('[DiaryService] 🔥 Firestore stream error: $error');
        debugPrintStack(stackTrace: stackTrace);
        // Do not add error to controller, keep streaming cached data if available
      },
      onDone: () {
        debugPrint('[DiaryService] ℹ️ Firestore diary entries stream done');
        controller.close();
      },
    );

    // Ensure subscription is cancelled when the stream controller is closed
    controller.onCancel = () {
      debugPrint('[DiaryService] 🗑️ Cancelling Firestore diary entries subscription');
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Loads diary entries for a day once, prioritizing cache over Firestore.
  /// 
  /// Attempts to load from cache first. If not found, fetches from Firestore.
  /// The fetched entries are then saved to cache.
  Future<List<DiaryEntry>> loadEntriesForDayOnce(String uid, DateTime day) async {
    debugPrint('[DiaryService] 🔵 Loading diary entries once (cache-first) for uid=$uid, day=$day');
    try {
      // Try loading from cache
      final cachedEntries = await _cache.loadEntriesForDay(uid, day);
      if (cachedEntries.isNotEmpty) {
        debugPrint('[DiaryService] ✅ Loaded ${cachedEntries.length} entries from cache');
        return cachedEntries;
      }

      // If not in cache, fetch from Firestore
      debugPrint('[DiaryService] ℹ️ No cached entries, fetching from Firestore');
      final firestoreEntries = await _repository.fetchEntriesForDay(uid, day);
      await _cache.saveEntriesForDay(uid, day, firestoreEntries); // Save to cache
      debugPrint('[DiaryService] ✅ Loaded ${firestoreEntries.length} entries from Firestore and cached');
      return firestoreEntries;
    } catch (e, st) {
      debugPrint('[DiaryService] 🔥 Error loading entries once: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  /// Adds a diary entry and updates the cache.
  Future<void> addEntry(DiaryEntry entry) async {
    debugPrint('[DiaryService] 🔵 Adding diary entry: ${entry.id}');
    try {
      await _repository.addEntry(entry);
      // Invalidate cache for this day so it refreshes on next load
      await _cache.clearEntriesForDay(entry.userId, DateTime.parse(entry.date));
      debugPrint('[DiaryService] ✅ Added entry and cleared cache');
    } catch (e, st) {
      debugPrint('[DiaryService] 🔥 Error adding entry: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  /// Updates a diary entry and updates the cache.
  Future<void> updateEntry(DiaryEntry entry) async {
    debugPrint('[DiaryService] 🔵 Updating diary entry: ${entry.id}');
    try {
      await _repository.updateEntry(entry);
      // Invalidate cache for this day so it refreshes on next load
      await _cache.clearEntriesForDay(entry.userId, DateTime.parse(entry.date));
      debugPrint('[DiaryService] ✅ Updated entry and cleared cache');
    } catch (e, st) {
      debugPrint('[DiaryService] 🔥 Error updating entry: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  /// Deletes a diary entry and updates the cache.
  Future<void> deleteEntry(String uid, String entryId, DateTime day) async {
    debugPrint('[DiaryService] 🔵 Deleting diary entry: $entryId');
    try {
      await _repository.deleteEntry(uid, entryId);
      // Invalidate cache for this day so it refreshes on next load
      await _cache.clearEntriesForDay(uid, day);
      debugPrint('[DiaryService] ✅ Deleted entry and cleared cache');
    } catch (e, st) {
      debugPrint('[DiaryService] 🔥 Error deleting entry: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  /// Clears the cached entries for a specific day.
  Future<void> clearCacheForDay(String uid, DateTime day) async {
    debugPrint('[DiaryService] 🔵 Clearing diary cache for uid=$uid, day=$day');
    try {
      await _cache.clearEntriesForDay(uid, day);
      debugPrint('[DiaryService] ✅ Diary cache cleared');
    } catch (e, st) {
      debugPrint('[DiaryService] 🔥 Error clearing cache: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// Add a food entry from voice input
  /// 
  /// Automatically determines the meal type based on the timestamp
  /// and creates a diary entry with the food's default portion.
  Future<void> addFoodEntryFromVoice({
    required String userId,
    required Food food,
    required DateTime timestamp,
  }) async {
    debugPrint('[DiaryService] [Voice] 🔵 Adding food entry from voice: ${food.name}');
    
    try {
      // Classify meal type based on timestamp
      final mealType = MealTimeClassifier.classifyMealType(timestamp);
      debugPrint('[DiaryService] [Voice] 🔵 Meal type for ${food.name} at $timestamp: ${mealType.name}');

      // Use centralized date normalization for consistency
      final dateString = DateUtils.normalizeToIsoString(timestamp);
      
      // Calculate nutrition for default portion
      final servingCount = 1.0;
      final gramsPerServing = food.defaultPortionGram;
      final totalGrams = servingCount * gramsPerServing;
      final calories = (food.caloriesPer100g * totalGrams / 100);
      final protein = (food.proteinPer100g * totalGrams / 100);
      final carbs = (food.carbsPer100g * totalGrams / 100);
      final fat = (food.fatPer100g * totalGrams / 100);
      
      debugPrint('[DiaryService] [Voice] 🔵 Creating diary entry: ${food.name}, ${calories.toStringAsFixed(0)} kcal, ${totalGrams}g, mealType=${mealType.name}');
      
      // Create diary entry
      final entry = DiaryEntry.food(
        id: '', // Will be set by repository
        userId: userId,
        date: dateString,
        mealType: mealType.name,
        foodId: food.id,
        foodName: food.name,
        servingCount: servingCount,
        gramsPerServing: gramsPerServing,
        totalGrams: totalGrams,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        createdAt: timestamp,
      );
      
      // Add entry via repository (reuses existing repository methods)
      await addEntry(entry);
      
      debugPrint('[DiaryService] [Voice] ✅ Added ${food.name} as ${mealType.name} at $timestamp');
    } catch (e, st) {
      debugPrint('[DiaryService] [Voice] ❌ Failed to add entry: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }
}

