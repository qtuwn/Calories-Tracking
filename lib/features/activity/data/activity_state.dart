/// State for activity tracking (steps, connection status).
class ActivityState {
  final bool connected;
  final int steps;

  const ActivityState({
    required this.connected,
    required this.steps,
  });

  factory ActivityState.initial() => const ActivityState(
        connected: false,
        steps: 0,
      );

  ActivityState copyWith({
    bool? connected,
    int? steps,
  }) {
    return ActivityState(
      connected: connected ?? this.connected,
      steps: steps ?? this.steps,
    );
  }
}

