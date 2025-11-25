import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/features/home/domain/workout_type.dart';
import 'package:calories_app/features/home/domain/diary_entry.dart';
import 'package:calories_app/features/home/presentation/providers/diary_provider.dart';
import 'package:calories_app/shared/state/auth_providers.dart';

/// Provider/Notifier for quick workout logging from the Home screen.
/// 
/// This provider allows users to quickly log manual workout sessions
/// without browsing the full exercise catalog. It creates simplified
/// exercise diary entries using predefined MET values for calorie estimation.
/// 
/// The logged workouts are stored as exercise entries in the diary and
/// contribute to the daily "calories burned" total.
class QuickWorkoutLogNotifier extends Notifier<void> {
  @override
  void build() {
    // No state needed, this is a service-like notifier
  }

  /// Log a quick workout session.
  /// 
  /// Creates a manual exercise diary entry for the selected date using
  /// the workout type's default MET value for calorie estimation (if calories
  /// are not provided).
  /// 
  /// Parameters:
  /// - [workoutType]: The type of workout (running, cycling, etc.)
  /// - [durationMinutes]: Duration of the workout in minutes
  /// - [caloriesBurned]: Optional manual calories (if not provided, will be calculated)
  /// - [note]: Optional note/description for the workout
  /// 
  /// Throws an exception if user is not authenticated or if there's an error
  /// saving to Firestore.
  Future<void> logQuickWorkout({
    required WorkoutType workoutType,
    required double durationMinutes,
    double? caloriesBurned,
    String? note,
  }) async {
    // Get UID from auth state provider (reactive)
    final authState = ref.read(authStateProvider);
    final uid = authState.when(
      data: (user) => user?.uid,
      loading: () => null,
      error: (_, __) => null,
    );
    
    if (uid == null) {
      throw Exception('Bạn cần đăng nhập để ghi nhật ký tập luyện');
    }

    try {
      debugPrint(
        '[QuickWorkoutLogNotifier] 🔵 Logging quick workout: ${workoutType.displayName}, duration=$durationMinutes min',
      );

      // Get user's weight from profile for calorie calculation (if needed)
      final profileAsync = ref.read(currentUserProfileProvider);
      final profile = profileAsync.when(
        data: (data) => data,
        loading: () => null,
        error: (_, __) => null,
      );
      
      // Calculate calories if not provided
      final calories = caloriesBurned ?? _calculateCalories(
        workoutType: workoutType,
        durationMinutes: durationMinutes,
        weightKg: profile?.weightKg,
      );

      debugPrint(
        '[QuickWorkoutLogNotifier] 📊 Calculated calories: $calories kcal (weight=${profile?.weightKg ?? "unknown"} kg)',
      );

      // Get the selected date from diary provider
      final diaryNotifier = ref.read(diaryProvider.notifier);
      final selectedDate = diaryNotifier.selectedDate;

      // Create a manual exercise diary entry
      // We use a synthetic exercise ID based on workout type since this is not from the catalog
      final entry = DiaryEntry.exercise(
        id: '', // Will be set by Firestore
        userId: uid,
        date: _getDateKey(selectedDate),
        exerciseId: 'quick_${workoutType.value}', // Synthetic ID for quick logs
        exerciseName: note ?? workoutType.displayName, // Use note as name if provided
        durationMinutes: durationMinutes,
        caloriesBurned: calories,
        exerciseUnit: 'time', // Manual entries are time-based
        exerciseValue: durationMinutes,
        exerciseLevelName: null, // No level for quick logs
        createdAt: DateTime.now(),
      );

      // Save to Firestore via diary repository
      await ref.read(diaryRepositoryProvider).addDiaryEntry(entry);

      debugPrint(
        '[QuickWorkoutLogNotifier] ✅ Quick workout logged successfully',
      );
    } catch (e, stackTrace) {
      debugPrint('[QuickWorkoutLogNotifier] 🔥 Error logging quick workout: $e');
      debugPrint('[QuickWorkoutLogNotifier] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Calculate calories burned using MET formula and user's weight.
  /// 
  /// Formula: MET * 3.5 * weight (kg) / 200 * minutes
  /// 
  /// Falls back to a 70kg default weight if user's weight is not available.
  /// This ensures the app remains functional even if the profile is incomplete.
  double _calculateCalories({
    required WorkoutType workoutType,
    required double durationMinutes,
    double? weightKg,
  }) {
    // Use user's weight if available, otherwise use a default 70kg
    final weight = weightKg ?? 70.0;
    
    if (weight <= 0 || durationMinutes <= 0) {
      return 0.0;
    }

    return workoutType.calculateCalories(
      weightKg: weight,
      durationMinutes: durationMinutes,
    );
  }

  /// Normalize date to ISO string (yyyy-MM-dd)
  String _getDateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
  }
}

/// Provider for quick workout logging.
/// 
/// Use this to log manual workout sessions from the Home screen without
/// selecting from the exercise catalog.
/// 
/// Example:
/// ```dart
/// await ref.read(quickWorkoutLogProvider.notifier).logQuickWorkout(
///   workoutType: WorkoutType.running,
///   durationMinutes: 30,
///   caloriesBurned: 250, // Optional
///   note: 'Morning run', // Optional
/// );
/// ```
final quickWorkoutLogProvider = NotifierProvider<QuickWorkoutLogNotifier, void>(
  QuickWorkoutLogNotifier.new,
);

