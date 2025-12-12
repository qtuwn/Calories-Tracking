import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/domain/diary/diary_entry.dart';
import 'package:calories_app/domain/diary/diary_service.dart';
import 'package:calories_app/shared/state/diary_providers.dart' as diary_providers;
import 'package:calories_app/features/home/domain/meal.dart';
import 'package:calories_app/features/home/domain/meal_item.dart';
import 'package:calories_app/features/home/domain/meal_type.dart';
import 'package:calories_app/domain/foods/food.dart';
import 'package:calories_app/features/exercise/data/exercise_model.dart';
import 'package:calories_app/shared/state/auth_providers.dart';
import 'package:calories_app/data/firebase/date_utils.dart';

/// State class for Diary
class DiaryState {
  final Map<String, List<Meal>> mealsByDate;
  final DateTime selectedDate;
  final List<DiaryEntry> entriesForSelectedDate;
  final double totalCalories; // Net calories (food - exercise)
  final double totalCaloriesConsumed; // Food calories only
  final double totalCaloriesBurned; // Exercise calories only
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final bool isLoading;
  final String? errorMessage;

  const DiaryState({
    required this.mealsByDate,
    required this.selectedDate,
    required this.entriesForSelectedDate,
    this.totalCalories = 0.0,
    this.totalCaloriesConsumed = 0.0,
    this.totalCaloriesBurned = 0.0,
    this.totalProtein = 0.0,
    this.totalCarbs = 0.0,
    this.totalFat = 0.0,
    this.isLoading = false,
    this.errorMessage,
  });

  DiaryState copyWith({
    Map<String, List<Meal>>? mealsByDate,
    DateTime? selectedDate,
    List<DiaryEntry>? entriesForSelectedDate,
    double? totalCalories,
    double? totalCaloriesConsumed,
    double? totalCaloriesBurned,
    double? totalProtein,
    double? totalCarbs,
    double? totalFat,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return DiaryState(
      mealsByDate: mealsByDate ?? this.mealsByDate,
      selectedDate: selectedDate ?? this.selectedDate,
      entriesForSelectedDate: entriesForSelectedDate ?? this.entriesForSelectedDate,
      totalCalories: totalCalories ?? this.totalCalories,
      totalCaloriesConsumed: totalCaloriesConsumed ?? this.totalCaloriesConsumed,
      totalCaloriesBurned: totalCaloriesBurned ?? this.totalCaloriesBurned,
      totalProtein: totalProtein ?? this.totalProtein,
      totalCarbs: totalCarbs ?? this.totalCarbs,
      totalFat: totalFat ?? this.totalFat,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Note: DiaryRepository provider is now in lib/shared/state/diary_providers.dart
// This file uses DiaryService via diary_providers.diaryServiceProvider

/// Provider quản lý state của Diary với Firestore integration
/// Now uses DiaryService (cache-first architecture) instead of direct repository
class DiaryNotifier extends Notifier<DiaryState> {
  DiaryService? _service;
  StreamSubscription<List<DiaryEntry>>? _entriesSubscription;
  String? _currentUid;

  @override
  DiaryState build() {
    final today = _normalizeDate(DateTime.now());
    final dateKey = _getDateKey(today);
    
    // Initialize service (cache-aware)
    _service = ref.read(diary_providers.diaryServiceProvider);
    
    // Initialize state with default meals
    final initialState = DiaryState(
      mealsByDate: {dateKey: _createDefaultMeals()},
      selectedDate: today,
      entriesForSelectedDate: [],
      isLoading: true,
    );
    
    // CRITICAL FIX: Read initial auth state synchronously on cold start
    // ref.listen only fires on CHANGES, not on initial value
    final initialAuthState = ref.read(authStateProvider);
    debugPrint('[DiaryNotifier] 🔵 Initial auth state in build(): ${initialAuthState.hasValue ? "has data" : "loading/error"}');
    
    // Handle initial auth state immediately
    initialAuthState.whenData((user) {
      if (user != null) {
        final uid = user.uid;
        debugPrint('[DiaryNotifier] 🟢 Cold start with existing user (uid=$uid), starting watch immediately');
        _currentUid = uid;
        // Use Future.microtask to avoid modifying state during build
        Future.microtask(() => _watchEntriesForDate(today, uid: uid));
      }
    });
    
    // Watch for future auth state changes
    _watchAuthState();
    
    return initialState;
  }

  /// Watch auth state and start/stop Firestore subscription accordingly
  void _watchAuthState() {
    // Watch auth state provider and react to FUTURE changes
    // NOTE: ref.listen does NOT fire on initial value, only on changes!
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      debugPrint('[DiaryNotifier] 🔔 Auth state changed (via ref.listen)');
      _handleAuthStateChange(next);
    });
  }

  /// Handle auth state change
  void _handleAuthStateChange(AsyncValue<User?> authState) {
    authState.when(
      data: (user) {
        final uid = user?.uid;
        
        // If uid changed, update subscription
        if (uid != _currentUid) {
          _currentUid = uid;
          
          // Cancel previous Firestore subscription
          _entriesSubscription?.cancel();
          
          if (uid == null) {
            // No user signed in
            debugPrint('[DiaryNotifier] ⚠️ No user signed in, clearing diary state');
            state = state.copyWith(
              entriesForSelectedDate: [],
              totalCalories: 0.0,
              totalCaloriesConsumed: 0.0,
              totalCaloriesBurned: 0.0,
              totalProtein: 0.0,
              totalCarbs: 0.0,
              totalFat: 0.0,
              isLoading: false,
              clearErrorMessage: true, // Don't show error for unauthenticated state
            );
          } else {
            // User is signed in, start watching entries
            debugPrint('[DiaryNotifier] ✅ User signed in (uid=$uid), starting diary watch');
            _watchEntriesForDate(state.selectedDate, uid: uid);
          }
        }
      },
      loading: () {
        // Auth is still loading, keep current state but set loading
        debugPrint('[DiaryNotifier] ⏳ Auth state loading...');
        if (_currentUid == null) {
          state = state.copyWith(
            isLoading: true,
            clearErrorMessage: true, // Don't show error while auth is loading
          );
        }
      },
      error: (error, stackTrace) {
        debugPrint('[DiaryNotifier] 🔥 Auth state error: $error');
        // On auth error, clear state
        _currentUid = null;
        _entriesSubscription?.cancel();
        state = state.copyWith(
          entriesForSelectedDate: [],
          totalCalories: 0.0,
          totalCaloriesConsumed: 0.0,
          totalCaloriesBurned: 0.0,
          totalProtein: 0.0,
          totalCarbs: 0.0,
          totalFat: 0.0,
          isLoading: false,
          errorMessage: 'Lỗi xác thực: $error',
        );
      },
    );
  }

  DateTime get selectedDate => state.selectedDate;

  void setSelectedDate(DateTime date) {
    final normalized = _normalizeDate(date);
    final dateKey = _getDateKey(normalized);
    
    // Cancel previous subscription
    _entriesSubscription?.cancel();
    
    // Update selected date
    final hasEntry = state.mealsByDate.containsKey(dateKey);
    final updatedMealsByDate = hasEntry
        ? state.mealsByDate
        : {...state.mealsByDate, dateKey: _createDefaultMeals()};
    
    state = state.copyWith(
      selectedDate: normalized,
      mealsByDate: updatedMealsByDate,
      isLoading: _currentUid != null, // Only show loading if user is authenticated
    );
    
    // Watch entries for new date (only if user is authenticated)
    if (_currentUid != null) {
      _watchEntriesForDate(normalized, uid: _currentUid!);
    } else {
      // No user, clear state
      state = state.copyWith(
        entriesForSelectedDate: [],
        totalCalories: 0.0,
        totalCaloriesConsumed: 0.0,
        totalCaloriesBurned: 0.0,
        totalProtein: 0.0,
        totalCarbs: 0.0,
        totalFat: 0.0,
        isLoading: false,
        clearErrorMessage: true,
      );
    }
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<Meal> _createDefaultMeals() {
    return [
      Meal(type: MealType.breakfast),
      Meal(type: MealType.lunch),
      Meal(type: MealType.dinner),
      Meal(type: MealType.snack),
    ];
  }

  /// Watch Firestore entries for a specific date and update state
  /// Requires a valid uid (should only be called when user is authenticated)
  /// Now uses DiaryService.watchEntriesForDayWithCache for cache-first behavior
  void _watchEntriesForDate(DateTime date, {required String uid}) {
    // Cancel previous subscription
    _entriesSubscription?.cancel();

    // Watch entries stream using cache-first service
    try {
      state = state.copyWith(isLoading: true, clearErrorMessage: true);
      
      _entriesSubscription = _service!
          .watchEntriesForDayWithCache(uid, date)
          .listen(
        (entries) {
          debugPrint('[DiaryNotifier] 📊 Received ${entries.length} entries for date=${_getDateKey(date)}');
          
          // Separate food and exercise entries
          final foodEntries = entries.where((e) => e.isFood).toList();
          final exerciseEntries = entries.where((e) => e.isExercise).toList();

          // Convert food DiaryEntry to MealItem and group by meal type
          final mealsByType = <MealType, List<MealItem>>{};
          for (final mealType in MealType.values) {
            mealsByType[mealType] = [];
          }

          for (final entry in foodEntries) {
            final mealType = MealType.values.firstWhere(
              (e) => e.name == entry.mealType,
              orElse: () => MealType.breakfast,
            );

            // Convert DiaryEntry to MealItem
            try {
              final mealItemJson = entry.toMealItemJson();
              final mealItem = MealItem.fromJson(mealItemJson);
              mealsByType[mealType]?.add(mealItem);
            } catch (e) {
              debugPrint('[DiaryNotifier] ⚠️ Error converting food entry to MealItem: $e');
            }
          }

          // Build meals list
          final meals = mealsByType.entries.map((entry) {
            return Meal(type: entry.key, items: entry.value);
          }).toList();

          // Compute totals for food entries
          final totalCaloriesConsumed = foodEntries.fold(0.0, (sum, e) => sum + e.calories);
          final totalProtein = foodEntries.fold(0.0, (sum, e) => sum + (e.protein ?? 0.0));
          final totalCarbs = foodEntries.fold(0.0, (sum, e) => sum + (e.carbs ?? 0.0));
          final totalFat = foodEntries.fold(0.0, (sum, e) => sum + (e.fat ?? 0.0));

          // Compute totals for exercise entries
          final totalCaloriesBurned = exerciseEntries.fold(0.0, (sum, e) => sum + e.calories);

          // Net calories = consumed - burned
          final totalCalories = totalCaloriesConsumed - totalCaloriesBurned;

          debugPrint(
            '[DiaryNotifier] 📊 Totals: consumed=$totalCaloriesConsumed, burned=$totalCaloriesBurned, net=$totalCalories',
          );

          // Update state
          final dateKey = _getDateKey(date);
          final updatedMealsByDate = Map<String, List<Meal>>.from(state.mealsByDate);
          updatedMealsByDate[dateKey] = meals;

          state = state.copyWith(
            mealsByDate: updatedMealsByDate,
            entriesForSelectedDate: entries,
            totalCalories: totalCalories,
            totalCaloriesConsumed: totalCaloriesConsumed,
            totalCaloriesBurned: totalCaloriesBurned,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat,
            isLoading: false,
            clearErrorMessage: true,
          );
        },
        onError: (error, stackTrace) {
          debugPrint('[DiaryNotifier] 🔥 Error watching entries: $error');
          debugPrint('[DiaryNotifier] Stack trace: $stackTrace');
          
          // Check if this is a permission-denied error
          final isPermissionDenied = error.toString().contains('permission-denied');
          final hasValidUser = _currentUid != null;
          
          if (isPermissionDenied && !hasValidUser) {
            // Permission denied but no user - likely auth still initializing
            // Don't show error, just wait for auth to resolve
            debugPrint('[DiaryNotifier] ⚠️ Permission denied but no user - waiting for auth');
            state = state.copyWith(
              entriesForSelectedDate: [],
              totalCalories: 0.0,
              totalCaloriesConsumed: 0.0,
              totalCaloriesBurned: 0.0,
              totalProtein: 0.0,
              totalCarbs: 0.0,
              totalFat: 0.0,
              isLoading: false,
              clearErrorMessage: true, // Don't show error for transient auth state
            );
          } else {
            // Real error - show it
            state = state.copyWith(
              entriesForSelectedDate: [],
              totalCalories: 0.0,
              totalCaloriesConsumed: 0.0,
              totalCaloriesBurned: 0.0,
              totalProtein: 0.0,
              totalCarbs: 0.0,
              totalFat: 0.0,
              isLoading: false,
              errorMessage: 'Lỗi tải dữ liệu: $error',
            );
          }
        },
        cancelOnError: false, // Keep listening even after errors
      );
    } catch (e, stackTrace) {
      debugPrint('[DiaryNotifier] 🔥 Exception setting up stream: $e');
      debugPrint('[DiaryNotifier] Stack trace: $stackTrace');
      state = state.copyWith(
        entriesForSelectedDate: [],
        totalCalories: 0.0,
        totalCaloriesConsumed: 0.0,
        totalCaloriesBurned: 0.0,
        totalProtein: 0.0,
        totalCarbs: 0.0,
        totalFat: 0.0,
        isLoading: false,
        errorMessage: 'Lỗi khởi tạo kết nối: $e',
      );
    }
  }

  /// Reload diary data (for Retry button)
  void reload() {
    debugPrint('[DiaryNotifier] 🔄 Reloading diary data...');
    
    // Re-evaluate auth state
    final authStateAsync = ref.read(authStateProvider);
    authStateAsync.whenData((user) {
      final uid = user?.uid;
      if (uid != null && uid == _currentUid) {
        // User is authenticated, reload entries
        _watchEntriesForDate(state.selectedDate, uid: uid);
      } else if (uid == null) {
        // No user, clear state
        state = state.copyWith(
          entriesForSelectedDate: [],
          totalCalories: 0.0,
          totalCaloriesConsumed: 0.0,
          totalCaloriesBurned: 0.0,
          totalProtein: 0.0,
          totalCarbs: 0.0,
          totalFat: 0.0,
          isLoading: false,
          clearErrorMessage: true,
        );
      }
    });
  }

  List<Meal> _currentMeals() {
    final dateKey = _getDateKey(state.selectedDate);
    return state.mealsByDate[dateKey] ?? _createDefaultMeals();
  }

  // Lấy meal theo type
  Meal getMealByType(MealType type) {
    return _currentMeals().firstWhere(
      (meal) => meal.type == type,
      orElse: () => Meal(type: type),
    );
  }

  // Tính tổng dinh dưỡng trong ngày (from state)
  double get totalCalories => state.totalCalories;
  double get totalProtein => state.totalProtein;
  double get totalCarbs => state.totalCarbs;
  double get totalFat => state.totalFat;

  /// Add a meal entry from a Food
  Future<void> addEntryFromFood({
    required Food food,
    required double servingCount,
    required double gramsPerServing,
    required MealType mealType,
  }) async {
    // Use cached UID from auth state watcher
    final uid = _currentUid;
    if (uid == null) {
      throw Exception('User must be signed in to add diary entries');
    }

    try {
      // Calculate total grams
      final totalGrams = servingCount * gramsPerServing;

      // Calculate macros based on per-100g values
      final calories = (food.caloriesPer100g * totalGrams) / 100;
      final protein = (food.proteinPer100g * totalGrams) / 100;
      final carbs = (food.carbsPer100g * totalGrams) / 100;
      final fat = (food.fatPer100g * totalGrams) / 100;

      // Create DiaryEntry
      final entry = DiaryEntry(
        id: '', // Will be set by repository
        userId: uid,
        date: _getDateKey(state.selectedDate),
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
        createdAt: DateTime.now(),
      );

      // Save via service (cache-aware, stream will update UI automatically)
      await _service!.addEntry(entry);
      
      debugPrint('[DiaryNotifier] ✅ Added entry: ${food.name}');
    } catch (e, stackTrace) {
      debugPrint('[DiaryNotifier] 🔥 Error adding entry: $e');
      debugPrint('[DiaryNotifier] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Add a meal entry from MealItem (for custom entries without Food)
  Future<void> addMealItem(MealType mealType, MealItem item) async {
    // Use cached UID from auth state watcher
    final uid = _currentUid;
    if (uid == null) {
      throw Exception('User must be signed in to add diary entries');
    }

    try {
      // Calculate total grams
      final totalGrams = item.totalGrams;

      // Create DiaryEntry from MealItem
      final entry = DiaryEntry(
        id: '', // Will be set by repository
        userId: uid,
        date: _getDateKey(state.selectedDate),
        mealType: mealType.name,
        foodId: null, // Custom entry, no foodId
        foodName: item.name,
        servingCount: item.servingSize,
        gramsPerServing: item.gramsPerServing,
        totalGrams: totalGrams,
        calories: item.totalCalories,
        protein: item.totalProtein,
        carbs: item.totalCarbs,
        fat: item.totalFat,
        createdAt: DateTime.now(),
      );

      // Save via service (cache-aware, stream will update UI automatically)
      await _service!.addEntry(entry);
      
      debugPrint('[DiaryNotifier] ✅ Added custom entry: ${item.name}');
    } catch (e, stackTrace) {
      debugPrint('[DiaryNotifier] 🔥 Error adding custom entry: $e');
      debugPrint('[DiaryNotifier] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Update a meal item
  Future<void> updateMealItem(MealType mealType, String itemId, MealItem updatedItem) async {
    // Use cached UID from auth state watcher
    final uid = _currentUid;
    if (uid == null) {
      throw Exception('User must be signed in to update diary entries');
    }

    try {
      // Find the entry
      final entry = state.entriesForSelectedDate.firstWhere(
        (e) => e.id == itemId,
        orElse: () => throw Exception('Entry not found: $itemId'),
      );

      // Calculate total grams
      final totalGrams = updatedItem.totalGrams;

      // Update entry
      final updatedEntry = entry.copyWith(
        foodName: updatedItem.name,
        servingCount: updatedItem.servingSize,
        gramsPerServing: updatedItem.gramsPerServing,
        totalGrams: totalGrams,
        calories: updatedItem.totalCalories,
        protein: updatedItem.totalProtein,
        carbs: updatedItem.totalCarbs,
        fat: updatedItem.totalFat,
        updatedAt: DateTime.now(),
      );

      // Save via service (cache-aware, stream will update UI automatically)
      await _service!.updateEntry(updatedEntry);
      
      debugPrint('[DiaryNotifier] ✅ Updated entry: $itemId');
    } catch (e, stackTrace) {
      debugPrint('[DiaryNotifier] 🔥 Error updating entry: $e');
      debugPrint('[DiaryNotifier] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete a meal item
  Future<void> deleteMealItem(MealType mealType, String itemId) async {
    // Use cached UID from auth state watcher
    final uid = _currentUid;
    if (uid == null) {
      throw Exception('User must be signed in to delete diary entries');
    }

    try {
      // Delete via service (cache-aware, stream will update UI automatically)
      await _service!.deleteEntry(uid, itemId, state.selectedDate);
      
      debugPrint('[DiaryNotifier] ✅ Deleted entry: $itemId');
    } catch (e, stackTrace) {
      debugPrint('[DiaryNotifier] 🔥 Error deleting entry: $e');
      debugPrint('[DiaryNotifier] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Clear all items in a meal (delete all entries for that meal type on selected date)
  Future<void> clearMeal(MealType mealType) async {
    final entriesToDelete = state.entriesForSelectedDate
        .where((e) => e.mealType == mealType.name)
        .toList();

    for (final entry in entriesToDelete) {
      await deleteMealItem(mealType, entry.id);
    }
  }

  /// Add an exercise entry to the diary
  /// 
  /// This adds an exercise log to today's diary.
  /// The calories are tracked as "burned" and subtracted from net calories.
  Future<void> addExerciseEntry({
    required Exercise exercise,
    required double durationMinutes,
    required double caloriesBurned,
    double? exerciseValue,
    String? exerciseLevelName,
  }) async {
    // Use cached UID from auth state watcher
    final uid = _currentUid;
    if (uid == null) {
      throw Exception('User must be signed in to add exercise entries');
    }

    try {
      debugPrint(
        '[DiaryNotifier] 🔵 Adding exercise: ${exercise.name}, duration=$durationMinutes, calories=$caloriesBurned',
      );

      // Create exercise entry and add via service
      final entry = DiaryEntry.exercise(
        id: '', // Will be set by repository
        userId: uid,
        date: DateUtils.normalizeToIsoString(state.selectedDate),
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        durationMinutes: durationMinutes,
        caloriesBurned: caloriesBurned,
        exerciseUnit: exercise.unit.value,
        exerciseValue: exerciseValue,
        exerciseLevelName: exerciseLevelName,
        createdAt: DateTime.now(),
      );
      
      await _service!.addEntry(entry);

      debugPrint('[DiaryNotifier] ✅ Exercise added successfully');
    } catch (e, stackTrace) {
      debugPrint('[DiaryNotifier] 🔥 Error adding exercise: $e');
      debugPrint('[DiaryNotifier] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete an exercise entry
  Future<void> deleteExerciseEntry(String entryId) async {
    final uid = _currentUid;
    if (uid == null) {
      throw Exception('User must be signed in to delete diary entries');
    }
    
    try {
      await _service!.deleteEntry(uid, entryId, state.selectedDate);
      debugPrint('[DiaryNotifier] ✅ Deleted exercise entry: $entryId');
    } catch (e, stackTrace) {
      debugPrint('[DiaryNotifier] 🔥 Error deleting exercise entry: $e');
      debugPrint('[DiaryNotifier] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get exercise entries for the selected date
  List<DiaryEntry> get exerciseEntries {
    return state.entriesForSelectedDate.where((e) => e.isExercise).toList();
  }

  /// Get food entries for the selected date
  List<DiaryEntry> get foodEntries {
    return state.entriesForSelectedDate.where((e) => e.isFood).toList();
  }

}

/// Riverpod provider for Diary
final diaryProvider = NotifierProvider<DiaryNotifier, DiaryState>(() {
  return DiaryNotifier();
});
