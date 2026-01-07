/// Nutrition statistics for a time period
class NutritionStats {
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final int entryCount;
  final double? targetCalories; // Optional target for comparison

  NutritionStats({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.entryCount,
    this.targetCalories,
  });

  /// Progress towards calorie target (0.0 to 1.0, or >1.0 if exceeded)
  double get progress => targetCalories != null && targetCalories! > 0
      ? (totalCalories / targetCalories!).clamp(0, double.infinity)
      : 0.0;

  /// Whether calorie target was met or exceeded
  bool get isTargetMet => targetCalories != null && totalCalories >= targetCalories!;

  /// Calories remaining until target (0 if exceeded)
  double get remaining => targetCalories != null
      ? (targetCalories! - totalCalories).clamp(0, double.infinity)
      : 0.0;

  /// Calories exceeded beyond target (0 if not exceeded)
  double get exceeded => targetCalories != null
      ? (totalCalories - targetCalories!).clamp(0, double.infinity)
      : 0.0;
}

/// Workout statistics for a time period
class WorkoutStats {
  final double totalCaloriesBurned;
  final double totalDurationMinutes;
  final int workoutCount;
  final List<String> exerciseNames; // Unique exercise names

  WorkoutStats({
    required this.totalCaloriesBurned,
    required this.totalDurationMinutes,
    required this.workoutCount,
    required this.exerciseNames,
  });

  /// Total duration in hours
  double get totalDurationHours => totalDurationMinutes / 60.0;

  /// Average calories burned per workout
  double get avgCaloriesPerWorkout =>
      workoutCount > 0 ? totalCaloriesBurned / workoutCount : 0.0;

  /// Average duration per workout in minutes
  double get avgDurationPerWorkout =>
      workoutCount > 0 ? totalDurationMinutes / workoutCount : 0.0;
}

/// Steps statistics for a time period
class StepsStats {
  final int totalSteps;
  final int? targetSteps; // Optional daily step goal

  StepsStats({
    required this.totalSteps,
    this.targetSteps,
  });

  /// Progress towards step target (0.0 to 1.0, or >1.0 if exceeded)
  double get progress => targetSteps != null && targetSteps! > 0
      ? (totalSteps / targetSteps!).clamp(0, double.infinity)
      : 0.0;

  /// Whether step target was met or exceeded
  bool get isTargetMet => targetSteps != null && totalSteps >= targetSteps!;

  /// Steps remaining until target (0 if exceeded)
  int get remaining => targetSteps != null
      ? (targetSteps! - totalSteps).clamp(0, targetSteps!)
      : 0;

  /// Steps exceeded beyond target (0 if not exceeded)
  int get exceeded => targetSteps != null
      ? (totalSteps - targetSteps!).clamp(0, totalSteps)
      : 0;
}

/// Weight statistics for a time period
class WeightStats {
  final double? latestWeight;
  final double? earliestWeight;
  final double? weightChange; // Positive = gain, negative = loss
  final int entryCount;
  final List<WeightPoint> weightHistory; // For charting
  final double? targetWeight; // Goal weight from profile
  final double? previousPeriodWeight; // Weight from previous period (yesterday, last week, last month)

  WeightStats({
    this.latestWeight,
    this.earliestWeight,
    this.weightChange,
    required this.entryCount,
    required this.weightHistory,
    this.targetWeight,
    this.previousPeriodWeight,
  });

  /// Whether weight increased
  bool get isWeightGain => weightChange != null && weightChange! > 0;

  /// Whether weight decreased
  bool get isWeightLoss => weightChange != null && weightChange! < 0;

  /// Whether weight stayed the same (within 0.1 kg tolerance)
  bool get isWeightMaintained => weightChange != null && weightChange!.abs() < 0.1;

  /// Change vs previous period (e.g., vs yesterday)
  double? get changeVsPrevious => latestWeight != null && previousPeriodWeight != null
      ? latestWeight! - previousPeriodWeight!
      : null;

  /// Progress towards goal weight (0.0 to 1.0)
  /// Returns null if targetWeight is not set or if current weight is already at/over goal
  double? get progressToGoal {
    if (latestWeight == null || targetWeight == null) return null;
    
    // For weight loss goal: progress = (startWeight - currentWeight) / (startWeight - targetWeight)
    // For weight gain goal: progress = (currentWeight - startWeight) / (targetWeight - startWeight)
    // For maintain goal: progress = 1.0 if within 0.5 kg of target
    
    // We need start weight to calculate progress, but we can estimate from earliestWeight
    final startWeight = earliestWeight ?? latestWeight;
    if (startWeight == null) return null;
    
    final diff = (targetWeight! - startWeight).abs();
    if (diff < 0.1) return 1.0; // Already at goal
    
    if (targetWeight! < startWeight) {
      // Weight loss goal
      final progress = (startWeight - latestWeight!) / (startWeight - targetWeight!);
      return progress.clamp(0.0, 1.0);
    } else {
      // Weight gain goal
      final progress = (latestWeight! - startWeight) / (targetWeight! - startWeight);
      return progress.clamp(0.0, 1.0);
    }
  }

  /// Trend label in Vietnamese
  String get trendLabel {
    if (weightChange == null) return 'Chưa có dữ liệu';
    if (isWeightMaintained) return 'Duy trì';
    if (isWeightGain) return 'Tăng cân';
    return 'Giảm cân';
  }
}

/// A single weight data point for charting
class WeightPoint {
  final DateTime date;
  final double weight;

  const WeightPoint({
    required this.date,
    required this.weight,
  });

  /// Override == to enable proper equality comparison for shouldRepaint()
  /// This fixes continuous repainting by allowing DeepCollectionEquality to work correctly
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightPoint &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          weight == other.weight;

  /// Override hashCode to maintain contract with ==
  /// Required for proper equality behavior in collections
  @override
  int get hashCode => date.hashCode ^ weight.hashCode;
}

