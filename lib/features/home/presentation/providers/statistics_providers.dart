import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/domain/diary/diary_entry.dart';
import 'package:calories_app/shared/state/diary_providers.dart' as diary_providers;
import 'package:calories_app/data/firebase/weight_repository.dart';
import 'package:calories_app/core/health/health_providers.dart';
import 'package:calories_app/features/home/domain/statistics_models.dart';
import 'package:calories_app/shared/state/auth_providers.dart';
import 'package:calories_app/data/firebase/date_utils.dart';

// Note: DiaryRepository provider is now in lib/shared/state/diary_providers.dart
// Use diary_providers.diaryRepositoryProvider instead

/// Provider for WeightRepository
final weightRepositoryProvider = Provider<WeightRepository>((ref) {
  return WeightRepository();
});

/// Helper provider to get the current user's UID
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).whenOrNull(
        data: (user) => user?.uid,
      );
});

// ============================================================================
// NUTRITION STATISTICS PROVIDERS
// ============================================================================

/// Get nutrition statistics for today
final todayNutritionStatsProvider = FutureProvider<NutritionStats>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw Exception('User not logged in');
  }

  try {
    final now = DateTime.now();
    final today = DateUtils.normalizeToMidnight(now);
    
    final repository = ref.read(diary_providers.diaryRepositoryProvider);
    final entries = await repository.fetchEntriesForDateRange(
      uid,
      today,
      today, // Use same date for single-day query
    );

    // Filter food entries only
    final foodEntries = entries.where((e) => e.type == DiaryEntryType.food).toList();

    // Aggregate nutrition data
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;

    for (final entry in foodEntries) {
      totalCalories += entry.calories;
      totalProtein += entry.protein ?? 0.0;
      totalCarbs += entry.carbs ?? 0.0;
      totalFat += entry.fat ?? 0.0;
    }

    // Get target calories from profile
    final profileAsync = ref.read(currentUserProfileProvider);
    final targetCalories = profileAsync.maybeWhen(
      data: (profile) => profile?.targetKcal,
      orElse: () => null,
    );

    return NutritionStats(
      totalCalories: totalCalories,
      totalProtein: totalProtein,
      totalCarbs: totalCarbs,
      totalFat: totalFat,
      entryCount: foodEntries.length,
      targetCalories: targetCalories,
    );
  } catch (e) {
    // Re-throw with a more user-friendly message
    throw Exception('Không thể tải dữ liệu dinh dưỡng hôm nay: ${e.toString()}');
  }
});

/// Get nutrition statistics for this week (last 7 days)
final weekNutritionStatsProvider = FutureProvider<NutritionStats>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw Exception('User not logged in');
  }

  final now = DateTime.now();
  final startDate = now.subtract(const Duration(days: 6)); // Last 7 days including today
  final normalizedStart = DateUtils.normalizeToMidnight(startDate);
  
  final repository = ref.read(diary_providers.diaryRepositoryProvider);
  final entries = await repository.fetchEntriesForDateRange(
    uid,
    normalizedStart,
    now,
  );

  // Filter food entries only
  final foodEntries = entries.where((e) => e.type == DiaryEntryType.food).toList();

  // Aggregate nutrition data
  double totalCalories = 0.0;
  double totalProtein = 0.0;
  double totalCarbs = 0.0;
  double totalFat = 0.0;

  for (final entry in foodEntries) {
    totalCalories += entry.calories;
    totalProtein += entry.protein ?? 0.0;
    totalCarbs += entry.carbs ?? 0.0;
    totalFat += entry.fat ?? 0.0;
  }

  // Get target calories from profile (multiply by 7 for weekly target)
  final profileAsync = ref.read(currentUserProfileProvider);
  final dailyTarget = profileAsync.maybeWhen(
    data: (profile) => profile?.targetKcal,
    orElse: () => null,
  );
  final targetCalories = dailyTarget != null ? dailyTarget * 7 : null;

  return NutritionStats(
    totalCalories: totalCalories,
    totalProtein: totalProtein,
    totalCarbs: totalCarbs,
    totalFat: totalFat,
    entryCount: foodEntries.length,
    targetCalories: targetCalories,
  );
});

/// Get nutrition statistics for this month
final monthNutritionStatsProvider = FutureProvider<NutritionStats>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw Exception('User not logged in');
  }

  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month, 1); // First day of month
  final normalizedStart = DateUtils.normalizeToMidnight(startDate);
  
  final repository = ref.read(diary_providers.diaryRepositoryProvider);
  final entries = await repository.fetchEntriesForDateRange(
    uid,
    normalizedStart,
    now,
  );

  // Filter food entries only
  final foodEntries = entries.where((e) => e.type == DiaryEntryType.food).toList();

  // Aggregate nutrition data
  double totalCalories = 0.0;
  double totalProtein = 0.0;
  double totalCarbs = 0.0;
  double totalFat = 0.0;

  for (final entry in foodEntries) {
    totalCalories += entry.calories;
    totalProtein += entry.protein ?? 0.0;
    totalCarbs += entry.carbs ?? 0.0;
    totalFat += entry.fat ?? 0.0;
  }

  // Get target calories from profile (multiply by days in month)
  final profileAsync = ref.read(currentUserProfileProvider);
  final dailyTarget = profileAsync.maybeWhen(
    data: (profile) => profile?.targetKcal,
    orElse: () => null,
  );
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final targetCalories = dailyTarget != null ? dailyTarget * daysInMonth : null;

  return NutritionStats(
    totalCalories: totalCalories,
    totalProtein: totalProtein,
    totalCarbs: totalCarbs,
    totalFat: totalFat,
    entryCount: foodEntries.length,
    targetCalories: targetCalories,
  );
});

// ============================================================================
// WORKOUT STATISTICS PROVIDERS
// ============================================================================

/// Get workout statistics for today
final todayWorkoutStatsProvider = FutureProvider<WorkoutStats>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw Exception('User not logged in');
  }

  try {
    final now = DateTime.now();
    final today = DateUtils.normalizeToMidnight(now);
    
    final repository = ref.read(diary_providers.diaryRepositoryProvider);
    final entries = await repository.fetchEntriesForDateRange(
      uid,
      today,
      today, // Use same date for single-day query
    );

    // Filter exercise entries only
    final exerciseEntries = entries.where((e) => e.type == DiaryEntryType.exercise).toList();

    // Aggregate workout data
    double totalCaloriesBurned = 0.0;
    double totalDurationMinutes = 0.0;
    final exerciseNames = <String>{};

    for (final entry in exerciseEntries) {
      totalCaloriesBurned += entry.calories;
      totalDurationMinutes += entry.durationMinutes ?? 0.0;
      if (entry.exerciseName != null) {
        exerciseNames.add(entry.exerciseName!);
      }
    }

    return WorkoutStats(
      totalCaloriesBurned: totalCaloriesBurned,
      totalDurationMinutes: totalDurationMinutes,
      workoutCount: exerciseEntries.length,
      exerciseNames: exerciseNames.toList()..sort(),
    );
  } catch (e) {
    // Re-throw with a more user-friendly message
    throw Exception('Không thể tải dữ liệu tập luyện hôm nay: ${e.toString()}');
  }
});

/// Get workout statistics for this week (last 7 days)
final weekWorkoutStatsProvider = FutureProvider<WorkoutStats>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw Exception('User not logged in');
  }

  final now = DateTime.now();
  final startDate = now.subtract(const Duration(days: 6));
  final normalizedStart = DateUtils.normalizeToMidnight(startDate);
  
  final repository = ref.read(diary_providers.diaryRepositoryProvider);
  final entries = await repository.fetchEntriesForDateRange(
    uid,
    normalizedStart,
    now,
  );

  // Filter exercise entries only
  final exerciseEntries = entries.where((e) => e.type == DiaryEntryType.exercise).toList();

  // Aggregate workout data
  double totalCaloriesBurned = 0.0;
  double totalDurationMinutes = 0.0;
  final exerciseNames = <String>{};

  for (final entry in exerciseEntries) {
    totalCaloriesBurned += entry.calories;
    totalDurationMinutes += entry.durationMinutes ?? 0.0;
    if (entry.exerciseName != null) {
      exerciseNames.add(entry.exerciseName!);
    }
  }

  return WorkoutStats(
    totalCaloriesBurned: totalCaloriesBurned,
    totalDurationMinutes: totalDurationMinutes,
    workoutCount: exerciseEntries.length,
    exerciseNames: exerciseNames.toList()..sort(),
  );
});

/// Get workout statistics for this month
final monthWorkoutStatsProvider = FutureProvider<WorkoutStats>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw Exception('User not logged in');
  }

  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month, 1);
  final normalizedStart = DateUtils.normalizeToMidnight(startDate);
  
  final repository = ref.read(diary_providers.diaryRepositoryProvider);
  final entries = await repository.fetchEntriesForDateRange(
    uid,
    normalizedStart,
    now,
  );

  // Filter exercise entries only
  final exerciseEntries = entries.where((e) => e.type == DiaryEntryType.exercise).toList();

  // Aggregate workout data
  double totalCaloriesBurned = 0.0;
  double totalDurationMinutes = 0.0;
  final exerciseNames = <String>{};

  for (final entry in exerciseEntries) {
    totalCaloriesBurned += entry.calories;
    totalDurationMinutes += entry.durationMinutes ?? 0.0;
    if (entry.exerciseName != null) {
      exerciseNames.add(entry.exerciseName!);
    }
  }

  return WorkoutStats(
    totalCaloriesBurned: totalCaloriesBurned,
    totalDurationMinutes: totalDurationMinutes,
    workoutCount: exerciseEntries.length,
    exerciseNames: exerciseNames.toList()..sort(),
  );
});

// ============================================================================
// STEPS STATISTICS PROVIDERS
// ============================================================================

/// Get steps statistics for today
final todayStepsStatsProvider = FutureProvider<StepsStats>((ref) async {
  final healthRepo = ref.read(healthRepositoryProvider);
  
  try {
    final steps = await healthRepo.getTodaySteps();
    
    // TODO: Get step goal from profile or settings if available
    const targetSteps = null; // No step goal configured yet
    
    return StepsStats(
      totalSteps: steps,
      targetSteps: targetSteps,
    );
  } catch (e) {
    // Return 0 steps on error
    return StepsStats(totalSteps: 0, targetSteps: null);
  }
});

/// Get steps statistics for this week (last 7 days)
final weekStepsStatsProvider = FutureProvider<StepsStats>((ref) async {
  final healthRepo = ref.read(healthRepositoryProvider);
  
  try {
    final now = DateTime.now();
    final startOfWeek = now.subtract(const Duration(days: 6));
    final normalizedStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    final totalSteps = await healthRepo.getStepsForDateRange(
      startDate: normalizedStart,
      endDate: now,
    );
    
    // TODO: Get step goal from profile or settings if available
    const targetSteps = null;
    
    return StepsStats(
      totalSteps: totalSteps,
      targetSteps: targetSteps,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[WeekStepsStats] Error: $e');
    }
    return StepsStats(totalSteps: 0, targetSteps: null);
  }
});

/// Get steps statistics for this month
final monthStepsStatsProvider = FutureProvider<StepsStats>((ref) async {
  final healthRepo = ref.read(healthRepositoryProvider);
  
  try {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    final totalSteps = await healthRepo.getStepsForDateRange(
      startDate: startOfMonth,
      endDate: now,
    );
    
    // TODO: Get step goal from profile or settings if available
    const targetSteps = null;
    
    return StepsStats(
      totalSteps: totalSteps,
      targetSteps: targetSteps,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[MonthStepsStats] Error: $e');
    }
    return StepsStats(totalSteps: 0, targetSteps: null);
  }
});

/// Get daily steps breakdown for this week (Mon-Sun)
final weekDailyStepsProvider = FutureProvider<Map<DateTime, int>>((ref) async {
  final healthRepo = ref.read(healthRepositoryProvider);
  
  try {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday
    final startOfWeek = now.subtract(Duration(days: weekday - 1));
    final normalizedStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    return await healthRepo.getDailySteps(
      startDate: normalizedStart,
      endDate: now,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[WeekDailySteps] Error: $e');
    }
    return {};
  }
});

/// Get daily steps breakdown for this month
final monthDailyStepsProvider = FutureProvider<Map<DateTime, int>>((ref) async {
  final healthRepo = ref.read(healthRepositoryProvider);
  
  try {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    return await healthRepo.getDailySteps(
      startDate: startOfMonth,
      endDate: now,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[MonthDailySteps] Error: $e');
    }
    return {};
  }
});

// ============================================================================
// WEIGHT STATISTICS PROVIDERS
// ============================================================================

/// Get weight statistics for today
final todayWeightStatsProvider = FutureProvider<WeightStats>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw Exception('User not logged in');
  }

  try {
    final repository = ref.read(weightRepositoryProvider);
    final now = DateTime.now();
    final today = DateUtils.normalizeToMidnight(now);
    final yesterday = today.subtract(const Duration(days: 1));
    
    // Get today's weight entry
    final todayWeights = await repository.getWeightHistory(
      uid: uid,
      startDate: today,
      endDate: today,
    );
    
    // Get yesterday's weight for comparison
    final yesterdayWeights = await repository.getWeightHistory(
      uid: uid,
      startDate: yesterday,
      endDate: yesterday,
    );
    
    // Get recent weights for chart (last 7 days)
    final recentWeightsStream = repository.watchRecentWeights(uid: uid, days: 7);
    final recentWeights = await recentWeightsStream.first;
    
    final todayWeight = todayWeights.isNotEmpty ? todayWeights.last.weightKg : null;
    final yesterdayWeight = yesterdayWeights.isNotEmpty ? yesterdayWeights.last.weightKg : null;
    
    // If no weight today, use latest weight from history
    final latestWeight = todayWeight ?? (recentWeights.isNotEmpty ? recentWeights.last.weightKg : null);
    
    final weightHistory = recentWeights
        .map((entry) => WeightPoint(
              date: entry.date,
              weight: entry.weightKg,
            ))
        .toList();

    // Get target weight from profile
    final profileAsync = ref.read(currentUserProfileProvider);
    final targetWeight = profileAsync.maybeWhen(
      data: (profile) => profile?.targetWeight,
      orElse: () => null,
    );

    return WeightStats(
      latestWeight: latestWeight,
      earliestWeight: recentWeights.isNotEmpty ? recentWeights.first.weightKg : null,
      weightChange: todayWeight != null && yesterdayWeight != null
          ? todayWeight - yesterdayWeight
          : null,
      entryCount: todayWeights.length,
      weightHistory: weightHistory,
      targetWeight: targetWeight,
      previousPeriodWeight: yesterdayWeight,
    );
  } catch (e) {
    throw Exception('Không thể tải dữ liệu cân nặng hôm nay: ${e.toString()}');
  }
});

/// Get weight statistics for this week (from start of week to today)
final weekWeightStatsProvider = FutureProvider<WeightStats>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw Exception('User not logged in');
  }

  try {
    final repository = ref.read(weightRepositoryProvider);
    final now = DateTime.now();
    
    // Calculate start of week (Monday = 1, Sunday = 7)
    final weekday = now.weekday;
    final startOfWeek = DateUtils.normalizeToMidnight(now.subtract(Duration(days: weekday - 1)));
    
    // Get last week's end date for comparison
    final lastWeekEnd = startOfWeek.subtract(const Duration(days: 1));
    final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
    
    // Get weights for this week
    final weekWeights = await repository.getWeightHistory(
      uid: uid,
      startDate: startOfWeek,
      endDate: now,
    );
    
    // Get last week's weights for comparison
    final lastWeekWeights = await repository.getWeightHistory(
      uid: uid,
      startDate: lastWeekStart,
      endDate: lastWeekEnd,
    );
    
    if (weekWeights.isEmpty) {
      return WeightStats(
        entryCount: 0,
        weightHistory: [],
        targetWeight: null,
        previousPeriodWeight: lastWeekWeights.isNotEmpty ? lastWeekWeights.last.weightKg : null,
      );
    }

    final latestWeight = weekWeights.last.weightKg;
    final earliestWeight = weekWeights.first.weightKg;
    final weightChange = latestWeight - earliestWeight;
    final lastWeekEndWeight = lastWeekWeights.isNotEmpty ? lastWeekWeights.last.weightKg : null;

    final weightHistory = weekWeights
        .map((entry) => WeightPoint(
              date: entry.date,
              weight: entry.weightKg,
            ))
        .toList();

    // Get target weight from profile
    final profileAsync = ref.read(currentUserProfileProvider);
    final targetWeight = profileAsync.maybeWhen(
      data: (profile) => profile?.targetWeight,
      orElse: () => null,
    );

    return WeightStats(
      latestWeight: latestWeight,
      earliestWeight: earliestWeight,
      weightChange: weightChange,
      entryCount: weekWeights.length,
      weightHistory: weightHistory,
      targetWeight: targetWeight,
      previousPeriodWeight: lastWeekEndWeight,
    );
  } catch (e) {
    throw Exception('Không thể tải dữ liệu cân nặng tuần này: ${e.toString()}');
  }
});

/// Get weight statistics for this month (from start of month to today)
final monthWeightStatsProvider = FutureProvider<WeightStats>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw Exception('User not logged in');
  }

  try {
    final repository = ref.read(weightRepositoryProvider);
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final normalizedStart = DateUtils.normalizeToMidnight(startOfMonth);
    
    // Get last month's end date for comparison
    final lastMonthEnd = normalizedStart.subtract(const Duration(days: 1));
    final lastMonthStart = DateTime(lastMonthEnd.year, lastMonthEnd.month, 1);
    
    // Get weights for this month
    final monthWeights = await repository.getWeightHistory(
      uid: uid,
      startDate: normalizedStart,
      endDate: now,
    );
    
    // Get last month's weights for comparison
    final lastMonthWeights = await repository.getWeightHistory(
      uid: uid,
      startDate: lastMonthStart,
      endDate: lastMonthEnd,
    );
    
    if (monthWeights.isEmpty) {
      return WeightStats(
        entryCount: 0,
        weightHistory: [],
        targetWeight: null,
        previousPeriodWeight: lastMonthWeights.isNotEmpty ? lastMonthWeights.last.weightKg : null,
      );
    }

    final latestWeight = monthWeights.last.weightKg;
    final earliestWeight = monthWeights.first.weightKg;
    final weightChange = latestWeight - earliestWeight;
    final lastMonthEndWeight = lastMonthWeights.isNotEmpty ? lastMonthWeights.last.weightKg : null;

    final weightHistory = monthWeights
        .map((entry) => WeightPoint(
              date: entry.date,
              weight: entry.weightKg,
            ))
        .toList();

    // Get target weight from profile
    final profileAsync = ref.read(currentUserProfileProvider);
    final targetWeight = profileAsync.maybeWhen(
      data: (profile) => profile?.targetWeight,
      orElse: () => null,
    );

    return WeightStats(
      latestWeight: latestWeight,
      earliestWeight: earliestWeight,
      weightChange: weightChange,
      entryCount: monthWeights.length,
      weightHistory: weightHistory,
      targetWeight: targetWeight,
      previousPeriodWeight: lastMonthEndWeight,
    );
  } catch (e) {
    throw Exception('Không thể tải dữ liệu cân nặng tháng này: ${e.toString()}');
  }
});

