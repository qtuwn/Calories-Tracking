/// Abstract repository for health data access.
/// 
/// This abstraction allows us to swap implementations (e.g., from health plugin
/// to native MethodChannel) without changing UI or business logic.
abstract class HealthRepository {
  /// Request Health Connect / health permissions from the user.
  /// Returns true if permissions were granted, false otherwise.
  Future<bool> requestPermission();

  /// Get total steps for today (from midnight to now).
  /// Returns 0 if no data is available or if there's an error.
  Future<int> getTodaySteps();

  /// Get total active energy burned (kcal) for today.
  /// Returns 0.0 if no data is available or if there's an error.
  Future<double> getTodayActiveCalories();

  /// Get total steps for a date range (from startDate to endDate, inclusive).
  /// Returns 0 if no data is available or if there's an error.
  Future<int> getStepsForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Get steps for each day in a date range.
  /// Returns a map of normalized date (midnight) to step count for that day.
  /// Useful for displaying daily breakdowns in charts.
  Future<Map<DateTime, int>> getDailySteps({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Check if steps permission is currently granted.
  /// Returns true if both ACTIVITY_RECOGNITION and Health Connect permissions are granted.
  Future<bool> hasStepsPermission();
}

