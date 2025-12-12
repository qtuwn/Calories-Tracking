import 'activity.dart';

/// Abstract repository interface for Activity operations
/// 
/// This is a pure domain interface with no dependencies on Flutter or Firebase.
/// Implementations should be in the data layer.
abstract class ActivityRepository {
  /// Watch all active activities (stream)
  /// Returns activities where isActive == true and deletedAt == null
  Stream<List<Activity>> watchAll();

  /// Watch all activities including inactive (for admin)
  Stream<List<Activity>> watchAllIncludingInactive();

  /// Get a single activity by ID
  Future<Activity?> getById(String id);

  /// Search activities by name
  /// [query] - Search query (case-insensitive)
  /// [category] - Optional category filter
  Stream<List<Activity>> search({
    required String query,
    ActivityCategory? category,
  });

  /// Create a new activity
  /// Returns the created activity with generated ID
  Future<Activity> create(Activity activity);

  /// Update an existing activity
  Future<void> update(Activity activity);

  /// Soft delete an activity (sets deletedAt timestamp)
  Future<void> delete(String id);

  /// Hard delete an activity (permanently removes from database)
  /// Use with caution - prefer soft delete
  Future<void> hardDelete(String id);

  /// Restore a soft-deleted activity
  Future<void> restore(String id);
}

