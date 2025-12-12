import '../../../../domain/activities/activity.dart';

/// State for activity list page
class ActivityListState {
  final List<Activity> activities;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final ActivityCategory? selectedCategory;
  final bool showInactive;

  const ActivityListState({
    this.activities = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedCategory,
    this.showInactive = false,
  });

  ActivityListState copyWith({
    List<Activity>? activities,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    ActivityCategory? selectedCategory,
    bool? showInactive,
  }) {
    return ActivityListState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      showInactive: showInactive ?? this.showInactive,
    );
  }
}

/// State for activity form page
class ActivityFormState {
  final Activity? activity;
  final bool isLoading;
  final String? errorMessage;
  final bool isEditing;

  const ActivityFormState({
    this.activity,
    this.isLoading = false,
    this.errorMessage,
    this.isEditing = false,
  });

  ActivityFormState copyWith({
    Activity? activity,
    bool? isLoading,
    String? errorMessage,
    bool? isEditing,
  }) {
    return ActivityFormState(
      activity: activity ?? this.activity,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isEditing: isEditing ?? this.isEditing,
    );
  }
}

