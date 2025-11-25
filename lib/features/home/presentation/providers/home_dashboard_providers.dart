import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:calories_app/features/home/domain/diary_entry.dart';
import 'package:calories_app/features/home/domain/meal_type.dart';
import 'package:calories_app/features/home/domain/workout_type.dart';
import 'package:calories_app/features/home/presentation/providers/diary_provider.dart';
import 'package:calories_app/shared/state/auth_providers.dart';

class HomeSelectedDateNotifier extends Notifier<DateTime> {
  static DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  DateTime build() => _normalizeDate(DateTime.now());

  void select(DateTime date) {
    state = _normalizeDate(date);
  }
}

/// Selected date for the home dashboard (defaults to today).
final homeSelectedDateProvider =
    NotifierProvider<HomeSelectedDateNotifier, DateTime>(
  HomeSelectedDateNotifier.new,
);

/// Model representing the user's daily calorie summary.
/// 
/// All calorie calculations are encapsulated here to keep business logic
/// out of widgets and improve testability.
class DailySummary {
  DailySummary({
    required this.goal,
    required this.consumed,
    required this.burned,
  });

  final double goal;
  final double consumed;
  final double burned;

  /// Net calories consumed (food - exercise burned)
  double get netIntake => max(consumed - burned, 0);

  /// Remaining calories until goal is reached
  double get remaining => max(goal - netIntake, 0);

  /// Calories exceeded beyond goal (0 if not exceeded)
  double get exceeded => max(netIntake - goal, 0);

  /// Whether the user has exceeded their calorie goal
  bool get isOverGoal => exceeded > 0;

  /// Progress towards goal (0.0 to 1.0, clamped)
  double get progress => goal > 0 ? (netIntake / goal).clamp(0, 1) : 0.0;
}

/// Provider for the daily summary combining diary data with profile targets.
/// Uses the same selected date as the Diary tab.
/// Automatically updates when auth state changes (user switches accounts).
final homeDailySummaryProvider = Provider<DailySummary>((ref) {
  // Get diary state (uses selected date from diaryProvider)
  final diaryState = ref.watch(diaryProvider);
  
  // Get profile data for targets (this provider automatically watches auth state)
  final profileAsync = ref.watch(currentUserProfileProvider);
  
  // Extract calorie goal from profile
  final calorieGoal = profileAsync.maybeWhen(
    data: (profile) => profile?.targetKcal ?? 0.0,
    orElse: () => 0.0,
  );
  
  // Get consumed and burned calories from diary state
  // totalCaloriesConsumed = food entries only
  // totalCaloriesBurned = exercise entries only
  final consumed = diaryState.totalCaloriesConsumed;
  final burned = diaryState.totalCaloriesBurned;
  
  return DailySummary(
    goal: calorieGoal,
    consumed: consumed,
    burned: burned,
  );
});

class MacroProgress {
  const MacroProgress({
    required this.label,
    required this.icon,
    required this.unit,
    required this.consumed,
    required this.target,
    required this.color,
  });

  final String label;
  final IconData icon;
  final String unit;
  final double consumed;
  final double target;
  final Color color;

  double get progress => (consumed / target).clamp(0, 1);
}

/// Provider for macro summary combining diary totals with profile targets.
/// Automatically updates when auth state changes (user switches accounts).
final homeMacroSummaryProvider = Provider<List<MacroProgress>>((ref) {
  // Get diary state (uses selected date from diaryProvider)
  final diaryState = ref.watch(diaryProvider);
  
  // Get profile data for targets (this provider automatically watches auth state)
  final profileAsync = ref.watch(currentUserProfileProvider);
  
  // Extract macro targets from profile
  final proteinTarget = profileAsync.maybeWhen(
    data: (profile) => profile?.proteinGrams ?? 0.0,
    orElse: () => 0.0,
  );
  
  final carbsTarget = profileAsync.maybeWhen(
    data: (profile) => profile?.carbGrams ?? 0.0,
    orElse: () => 0.0,
  );
  
  final fatTarget = profileAsync.maybeWhen(
    data: (profile) => profile?.fatGrams ?? 0.0,
    orElse: () => 0.0,
  );
  
  // Get consumed macros from diary state
  final proteinConsumed = diaryState.totalProtein;
  final carbsConsumed = diaryState.totalCarbs;
  final fatConsumed = diaryState.totalFat;
  
  return [
    MacroProgress(
      label: 'Chất đạm',
      icon: Icons.egg_alt_outlined,
      unit: 'g',
      consumed: proteinConsumed,
      target: proteinTarget > 0 ? proteinTarget : 1.0, // Avoid division by zero
      color: const Color(0xFF81C784),
    ),
    MacroProgress(
      label: 'Đường bột',
      icon: Icons.rice_bowl_outlined,
      unit: 'g',
      consumed: carbsConsumed,
      target: carbsTarget > 0 ? carbsTarget : 1.0, // Avoid division by zero
      color: const Color(0xFF64B5F6),
    ),
    MacroProgress(
      label: 'Chất béo',
      icon: Icons.bubble_chart_outlined,
      unit: 'g',
      consumed: fatConsumed,
      target: fatTarget > 0 ? fatTarget : 1.0, // Avoid division by zero
      color: const Color(0xFFF48FB1),
    ),
  ];
});

class RecentDiaryEntry {
  const RecentDiaryEntry({
    required this.title,
    required this.subtitle,
    required this.calories,
    required this.timeLabel,
    required this.icon,
    this.isExercise = false,
  });

  final String title;
  final String subtitle;
  final int calories;
  final String timeLabel;
  final IconData icon;
  final bool isExercise; // true for exercise entries, false for food entries
}

/// Provider for recent diary entries from Firestore.
/// Shows the most recent 3 entries for the selected date (same as Diary tab).
/// Includes both food (meals) and exercise entries.
final homeRecentDiaryEntriesProvider =
    Provider<List<RecentDiaryEntry>>((ref) {
  // Get diary state (uses selected date from diaryProvider)
  final diaryState = ref.watch(diaryProvider);
  
  // Get entries for the selected date
  final entries = diaryState.entriesForSelectedDate;
  
  if (entries.isEmpty) {
    return [];
  }
  
  // Sort by creation time (most recent first)
  final sortedEntries = List<DiaryEntry>.from(entries)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  
  // Take the most recent 3 entries
  final recentEntries = sortedEntries.take(3).toList();
  
  // Convert DiaryEntry to RecentDiaryEntry
  return recentEntries.map((entry) {
    // Format time from createdAt
    final timeFormat = DateFormat('HH:mm');
    final timeLabel = timeFormat.format(entry.createdAt);
    
    // Branch based on entry type
    if (entry.type == DiaryEntryType.exercise) {
      // Exercise entry
      final duration = entry.durationMinutes?.toStringAsFixed(0) ?? '0';
      return RecentDiaryEntry(
        title: 'Hoạt động',
        subtitle: '${entry.exerciseName ?? 'Bài tập'} • $duration phút',
        calories: entry.calories.round(),
        timeLabel: timeLabel,
        icon: Icons.fitness_center,
        isExercise: true,
      );
    } else {
      // Food entry
      MealType mealType;
      try {
        mealType = MealType.values.firstWhere(
          (e) => e.name == entry.mealType,
          orElse: () => MealType.breakfast,
        );
      } catch (_) {
        mealType = MealType.breakfast;
      }
      
      return RecentDiaryEntry(
        title: mealType.displayName,
        subtitle: entry.foodName ?? 'Không xác định',
        calories: entry.calories.round(),
        timeLabel: timeLabel,
        icon: mealType.icon,
        isExercise: false,
      );
    }
  }).toList();
});

class ActivityCategory {
  const ActivityCategory({
    required this.workoutType,
  });

  final WorkoutType workoutType;
  
  String get label => workoutType.displayName;
  IconData get icon => workoutType.icon;
}

final homeActivityCategoriesProvider = Provider<List<ActivityCategory>>((ref) {
  return const [
    ActivityCategory(workoutType: WorkoutType.running),
    ActivityCategory(workoutType: WorkoutType.cycling),
    ActivityCategory(workoutType: WorkoutType.badminton),
    ActivityCategory(workoutType: WorkoutType.yoga),
    ActivityCategory(workoutType: WorkoutType.other),
  ];
});

class ActivitySummary {
  const ActivitySummary({
    required this.stepsMessage,
    required this.workoutCalories,
  });

  final String stepsMessage;
  final int workoutCalories;
}

final homeActivitySummaryProvider = Provider<ActivitySummary>((ref) {
  //Replace with actual integration to steps/workout tracking.
  return const ActivitySummary(
    stepsMessage: 'Kết nối Health Connect để tự động cập nhật',
    workoutCalories: 320,
  );
});

class WaterIntake {
  const WaterIntake({
    required this.totalMl,
    required this.goalMl,
  });

  final int totalMl;
  final int goalMl;

  double get progress => (totalMl / goalMl).clamp(0, 1);
}

final homeWaterIntakeProvider = Provider<WaterIntake>((ref) {
  //Hook up with water tracking repository (user-defined goal).
  return const WaterIntake(
    totalMl: 1400,
    goalMl: 2200,
  );
});

class WeightPoint {
  const WeightPoint({
    required this.date,
    required this.weight,
  });

  final DateTime date;
  final double weight;
}

class WeightHistory {
  const WeightHistory({
    required this.lastWeight,
    required this.lastUpdated,
    required this.points,
  });

  final double lastWeight;
  final DateTime lastUpdated;
  final List<WeightPoint> points;
}

final homeWeightHistoryProvider = Provider<WeightHistory>((ref) {
  final now = DateTime.now();
  //Replace with actual weight history fetched from user profile.
  final points = List.generate(7, (index) {
    final date = now.subtract(Duration(days: 6 - index));
    final base = 64.5 + sin(index / 2) * 0.8;
    return WeightPoint(date: date, weight: double.parse(base.toStringAsFixed(1)));
  });
  return WeightHistory(
    lastWeight: 64.9,
    lastUpdated: now.subtract(const Duration(days: 1)),
    points: points,
  );
});
