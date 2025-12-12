import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/activities/activity.dart';
import '../../../../domain/activities/activity_repository.dart';
import '../../../../domain/activities/activity_service.dart';
import '../../../../data/activities/firestore_activity_repository.dart';

/// Provider for ActivityRepository
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return FirestoreActivityRepository();
});

/// Provider for ActivityService
final activityServiceProvider = Provider<ActivityService>((ref) {
  final repository = ref.watch(activityRepositoryProvider);
  return ActivityService(repository);
});

/// Provider for all active activities (stream)
final activitiesProvider = StreamProvider.autoDispose<List<Activity>>((ref) {
  final repository = ref.watch(activityRepositoryProvider);
  return repository.watchAll();
});

/// Provider for all activities including inactive (admin use)
final allActivitiesProvider =
    StreamProvider.autoDispose<List<Activity>>((ref) {
  final repository = ref.watch(activityRepositoryProvider);
  return repository.watchAllIncludingInactive();
});

/// Provider for activity search
final activitySearchProvider = StreamProvider.autoDispose
    .family<List<Activity>, ({String query, ActivityCategory? category})>(
  (ref, args) {
    final repository = ref.watch(activityRepositoryProvider);
    return repository.search(
      query: args.query,
      category: args.category,
    );
  },
);

/// Provider for a single activity by ID
final activityByIdProvider =
    FutureProvider.autoDispose.family<Activity?, String>((ref, id) async {
  final repository = ref.watch(activityRepositoryProvider);
  return await repository.getById(id);
});

