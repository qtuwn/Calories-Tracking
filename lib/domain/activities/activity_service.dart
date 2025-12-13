import 'activity.dart';
import 'activity_repository.dart';

/// Business logic service for Activity operations
/// 
/// This service handles validation, business rules, and coordinates
/// between the repository and domain logic.
class ActivityService {
  final ActivityRepository _repository;

  ActivityService(this._repository);

  /// Validate activity before creation
  /// Throws [Exception] if validation fails
  void validateForCreate(Activity activity) {
    if (activity.name.trim().isEmpty) {
      throw Exception('Activity name cannot be empty');
    }

    if (activity.met <= 0) {
      throw Exception('MET value must be greater than 0');
    }

    if (activity.met > 20) {
      throw Exception('MET value cannot exceed 20 (unrealistic activity)');
    }
  }

  /// Validate activity before update
  /// Throws [Exception] if validation fails
  void validateForUpdate(Activity activity) {
    validateForCreate(activity);

    if (activity.id.isEmpty) {
      throw Exception('Activity ID cannot be empty for update');
    }
  }

  /// Create a new activity with validation
  Future<Activity> createActivity(Activity activity) async {
    validateForCreate(activity);

    // Ensure intensity matches MET value
    final intensity = ActivityIntensity.fromMet(activity.met);
    final activityWithIntensity = activity.copyWith(intensity: intensity);

    return await _repository.create(activityWithIntensity);
  }

  /// Update an existing activity with validation
  Future<void> updateActivity(Activity activity) async {
    validateForUpdate(activity);

    // Check if activity exists
    final existing = await _repository.getById(activity.id);
    if (existing == null) {
      throw Exception('Activity not found: ${activity.id}');
    }

    // Ensure intensity matches MET value
    final intensity = ActivityIntensity.fromMet(activity.met);
    final activityWithIntensity = activity.copyWith(
      intensity: intensity,
      updatedAt: DateTime.now(),
    );

    await _repository.update(activityWithIntensity);
  }

  /// Soft delete an activity
  /// Sets deletedAt timestamp instead of permanently removing
  Future<void> deleteActivity(String id) async {
    final activity = await _repository.getById(id);
    if (activity == null) {
      throw Exception('Activity not found: $id');
    }

    if (activity.isDeleted) {
      throw Exception('Activity is already deleted');
    }

    await _repository.delete(id);
  }

  /// Restore a soft-deleted activity
  Future<void> restoreActivity(String id) async {
    final activity = await _repository.getById(id);
    if (activity == null) {
      throw Exception('Activity not found: $id');
    }

    if (!activity.isDeleted) {
      throw Exception('Activity is not deleted');
    }

    await _repository.restore(id);
  }

  /// Toggle activity active status
  Future<void> toggleActiveStatus(String id) async {
    final activity = await _repository.getById(id);
    if (activity == null) {
      throw Exception('Activity not found: $id');
    }

    await _repository.update(
      activity.copyWith(
        isActive: !activity.isActive,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Calculate calories burned for an activity
  /// [activityId] - Activity ID
  /// [weightKg] - User weight in kg
  /// [durationMinutes] - Duration in minutes
  Future<double> calculateCaloriesBurned({
    required String activityId,
    required double weightKg,
    required double durationMinutes,
  }) async {
    final activity = await _repository.getById(activityId);
    if (activity == null) {
      throw Exception('Activity not found: $activityId');
    }

    return activity.calculateTotalCalories(weightKg, durationMinutes);
  }
}

