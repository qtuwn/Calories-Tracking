import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/health/health_providers.dart';
import '../../../core/health/health_repository.dart';
import 'activity_state.dart';

/// Provider for ActivityController.
final activityControllerProvider =
    NotifierProvider<ActivityController, ActivityState>(() {
  return ActivityController();
});

/// Controller for managing activity data from Health Connect / health services.
class ActivityController extends Notifier<ActivityState> {
  HealthRepository? _repo;

  @override
  ActivityState build() {
    _repo = ref.read(healthRepositoryProvider);
    return ActivityState.initial();
  }

  /// Connect to Health Connect and sync today's data.
  Future<void> connectAndSync() async {
    if (_repo == null) return;

    try {
      final granted = await _repo!.requestPermission();
      if (!granted) {
        // Permission denied - keep disconnected state
        return;
      }

      final steps = await _repo!.getTodaySteps();
      state = state.copyWith(
        connected: true,
        steps: steps,
      );
    } catch (e) {
      // On error, reset to disconnected state
      state = const ActivityState(connected: false, steps: 0);
    }
  }

  /// Refresh today's data (only works if already connected).
  Future<void> refreshToday() async {
    if (!state.connected) return;

    await connectAndSync();
  }
}

