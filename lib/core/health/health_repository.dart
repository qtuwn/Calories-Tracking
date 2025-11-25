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
}

