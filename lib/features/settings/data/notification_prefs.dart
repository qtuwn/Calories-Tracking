import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data model for notification preferences
class NotificationPrefs {
  final bool enableMealReminders;
  final bool enableExerciseReminder;
  final bool enableWaterReminder;
  final TimeOfDay breakfastTime;
  final TimeOfDay lunchTime;
  final TimeOfDay dinnerTime;
  final TimeOfDay exerciseTime;

  const NotificationPrefs({
    this.enableMealReminders = true,
    this.enableExerciseReminder = true,
    this.enableWaterReminder = false,
    this.breakfastTime = const TimeOfDay(hour: 8, minute: 0),
    this.lunchTime = const TimeOfDay(hour: 12, minute: 15),
    this.dinnerTime = const TimeOfDay(hour: 19, minute: 30),
    this.exerciseTime = const TimeOfDay(hour: 17, minute: 0),
  });

  NotificationPrefs copyWith({
    bool? enableMealReminders,
    bool? enableExerciseReminder,
    bool? enableWaterReminder,
    TimeOfDay? breakfastTime,
    TimeOfDay? lunchTime,
    TimeOfDay? dinnerTime,
    TimeOfDay? exerciseTime,
  }) {
    return NotificationPrefs(
      enableMealReminders: enableMealReminders ?? this.enableMealReminders,
      enableExerciseReminder:
          enableExerciseReminder ?? this.enableExerciseReminder,
      enableWaterReminder: enableWaterReminder ?? this.enableWaterReminder,
      breakfastTime: breakfastTime ?? this.breakfastTime,
      lunchTime: lunchTime ?? this.lunchTime,
      dinnerTime: dinnerTime ?? this.dinnerTime,
      exerciseTime: exerciseTime ?? this.exerciseTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enableMealReminders': enableMealReminders,
      'enableExerciseReminder': enableExerciseReminder,
      'enableWaterReminder': enableWaterReminder,
      'breakfastTimeHour': breakfastTime.hour,
      'breakfastTimeMinute': breakfastTime.minute,
      'lunchTimeHour': lunchTime.hour,
      'lunchTimeMinute': lunchTime.minute,
      'dinnerTimeHour': dinnerTime.hour,
      'dinnerTimeMinute': dinnerTime.minute,
      'exerciseTimeHour': exerciseTime.hour,
      'exerciseTimeMinute': exerciseTime.minute,
    };
  }

  factory NotificationPrefs.fromMap(Map<String, dynamic> map) {
    return NotificationPrefs(
      enableMealReminders: map['enableMealReminders'] as bool? ?? true,
      enableExerciseReminder: map['enableExerciseReminder'] as bool? ?? true,
      enableWaterReminder: map['enableWaterReminder'] as bool? ?? false,
      breakfastTime: TimeOfDay(
        hour: map['breakfastTimeHour'] as int? ?? 8,
        minute: map['breakfastTimeMinute'] as int? ?? 0,
      ),
      lunchTime: TimeOfDay(
        hour: map['lunchTimeHour'] as int? ?? 12,
        minute: map['lunchTimeMinute'] as int? ?? 15,
      ),
      dinnerTime: TimeOfDay(
        hour: map['dinnerTimeHour'] as int? ?? 19,
        minute: map['dinnerTimeMinute'] as int? ?? 30,
      ),
      exerciseTime: TimeOfDay(
        hour: map['exerciseTimeHour'] as int? ?? 17,
        minute: map['exerciseTimeMinute'] as int? ?? 0,
      ),
    );
  }
}

/// Repository for managing notification preferences using SharedPreferences
class NotificationPrefsRepository {
  static const String _keyPrefix = 'notification_prefs_';

  /// Load notification preferences from SharedPreferences
  Future<NotificationPrefs> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{};

      map['enableMealReminders'] =
          prefs.getBool('${_keyPrefix}enableMealReminders') ?? true;
      map['enableExerciseReminder'] =
          prefs.getBool('${_keyPrefix}enableExerciseReminder') ?? true;
      map['enableWaterReminder'] =
          prefs.getBool('${_keyPrefix}enableWaterReminder') ?? false;

      map['breakfastTimeHour'] =
          prefs.getInt('${_keyPrefix}breakfastTimeHour') ?? 8;
      map['breakfastTimeMinute'] =
          prefs.getInt('${_keyPrefix}breakfastTimeMinute') ?? 0;

      map['lunchTimeHour'] = prefs.getInt('${_keyPrefix}lunchTimeHour') ?? 12;
      map['lunchTimeMinute'] =
          prefs.getInt('${_keyPrefix}lunchTimeMinute') ?? 15;

      map['dinnerTimeHour'] = prefs.getInt('${_keyPrefix}dinnerTimeHour') ?? 19;
      map['dinnerTimeMinute'] =
          prefs.getInt('${_keyPrefix}dinnerTimeMinute') ?? 30;

      map['exerciseTimeHour'] =
          prefs.getInt('${_keyPrefix}exerciseTimeHour') ?? 17;
      map['exerciseTimeMinute'] =
          prefs.getInt('${_keyPrefix}exerciseTimeMinute') ?? 0;

      return NotificationPrefs.fromMap(map);
    } catch (e) {
      debugPrint('[NotificationPrefsRepository] Error loading prefs: $e');
      return const NotificationPrefs(); // Return defaults on error
    }
  }

  /// Save notification preferences to SharedPreferences
  Future<void> save(NotificationPrefs prefs) async {
    try {
      final prefsStorage = await SharedPreferences.getInstance();
      final map = prefs.toMap();

      await prefsStorage.setBool(
        '${_keyPrefix}enableMealReminders',
        map['enableMealReminders'] as bool,
      );
      await prefsStorage.setBool(
        '${_keyPrefix}enableExerciseReminder',
        map['enableExerciseReminder'] as bool,
      );
      await prefsStorage.setBool(
        '${_keyPrefix}enableWaterReminder',
        map['enableWaterReminder'] as bool,
      );

      await prefsStorage.setInt(
        '${_keyPrefix}breakfastTimeHour',
        map['breakfastTimeHour'] as int,
      );
      await prefsStorage.setInt(
        '${_keyPrefix}breakfastTimeMinute',
        map['breakfastTimeMinute'] as int,
      );

      await prefsStorage.setInt(
        '${_keyPrefix}lunchTimeHour',
        map['lunchTimeHour'] as int,
      );
      await prefsStorage.setInt(
        '${_keyPrefix}lunchTimeMinute',
        map['lunchTimeMinute'] as int,
      );

      await prefsStorage.setInt(
        '${_keyPrefix}dinnerTimeHour',
        map['dinnerTimeHour'] as int,
      );
      await prefsStorage.setInt(
        '${_keyPrefix}dinnerTimeMinute',
        map['dinnerTimeMinute'] as int,
      );

      await prefsStorage.setInt(
        '${_keyPrefix}exerciseTimeHour',
        map['exerciseTimeHour'] as int,
      );
      await prefsStorage.setInt(
        '${_keyPrefix}exerciseTimeMinute',
        map['exerciseTimeMinute'] as int,
      );

      debugPrint('[NotificationPrefsRepository] ✅ Preferences saved');
    } catch (e) {
      debugPrint('[NotificationPrefsRepository] 🔥 Error saving prefs: $e');
      rethrow;
    }
  }
}

/// Riverpod provider for NotificationPrefsRepository
final notificationPrefsRepositoryProvider =
    Provider<NotificationPrefsRepository>((ref) {
  return NotificationPrefsRepository();
});

/// Riverpod provider for notification preferences (AsyncNotifier for UI editing)
class NotificationPrefsNotifier extends AsyncNotifier<NotificationPrefs> {
  @override
  Future<NotificationPrefs> build() async {
    final repository = ref.read(notificationPrefsRepositoryProvider);
    return await repository.load();
  }

  /// Save preferences
  Future<void> save(NotificationPrefs prefs) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(notificationPrefsRepositoryProvider);
      await repository.save(prefs);
      state = AsyncValue.data(prefs);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }
}

final notificationPrefsProvider =
    AsyncNotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
  NotificationPrefsNotifier.new,
);

