import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calories_app/core/notifications/local_notifications_service.dart';
import 'package:calories_app/core/notifications/notification_messages.dart';
import 'package:calories_app/features/settings/data/notification_prefs.dart';
import 'package:calories_app/shared/state/profile_providers.dart';

/// Service for scheduling local notifications based on user preferences
class NotificationScheduler {
  final LocalNotificationsService _localNotificationsService;
  final SharedPreferences? _prefs;
  static bool _initOnce = false;
  static const String _lastRescheduleDateKey = 'notificationScheduler_lastRescheduleDate';

  NotificationScheduler(this._localNotificationsService, [this._prefs]);

  /// Reschedule all notifications based on preferences
  /// 
  /// Only cancels existing notifications if preferences changed or last reschedule was > 24h ago.
  Future<void> rescheduleAll(NotificationPrefs prefs, {bool force = false}) async {
    // PHASE 2: Check if we need to reschedule (avoid cancelAll on every boot)
    if (!force && _prefs != null) {
      final lastRescheduleStr = _prefs!.getString(_lastRescheduleDateKey);
      if (lastRescheduleStr != null) {
        final lastReschedule = DateTime.parse(lastRescheduleStr);
        final now = DateTime.now();
        final hoursSinceLastReschedule = now.difference(lastReschedule).inHours;
        
        // Only reschedule if > 24h ago (avoid cancelAll on every boot)
        if (hoursSinceLastReschedule < 24) {
          debugPrint('[NotificationScheduler] ⏭️ Skipping reschedule (last: ${hoursSinceLastReschedule}h ago, < 24h)');
          return;
        }
      }
    }
    
    try {
      // Cancel all existing notifications first (only when actually rescheduling)
      await _localNotificationsService.cancelAll();
      debugPrint('[NotificationScheduler] ✅ Cancelled all existing notifications');

      // Schedule meal reminders if enabled
      if (prefs.enableMealReminders) {
        // Breakfast reminder - ID 100
        await _localNotificationsService.scheduleDailyNotification(
          id: 100,
          time: prefs.breakfastTime,
          title: 'Nhắc bữa sáng',
          body: randomNotificationMessage(NotificationCategory.breakfast),
        );
        debugPrint(
          '[NotificationScheduler] ✅ Scheduled breakfast reminder at ${prefs.breakfastTime.hour}:${prefs.breakfastTime.minute}',
        );

        // Lunch reminder - ID 101
        await _localNotificationsService.scheduleDailyNotification(
          id: 101,
          time: prefs.lunchTime,
          title: 'Nhắc bữa trưa',
          body: randomNotificationMessage(NotificationCategory.lunch),
        );
        debugPrint(
          '[NotificationScheduler] ✅ Scheduled lunch reminder at ${prefs.lunchTime.hour}:${prefs.lunchTime.minute}',
        );

        // Dinner reminder - ID 102
        await _localNotificationsService.scheduleDailyNotification(
          id: 102,
          time: prefs.dinnerTime,
          title: 'Nhắc bữa tối',
          body: randomNotificationMessage(NotificationCategory.dinner),
        );
        debugPrint(
          '[NotificationScheduler] ✅ Scheduled dinner reminder at ${prefs.dinnerTime.hour}:${prefs.dinnerTime.minute}',
        );
      } else {
        debugPrint('[NotificationScheduler] ℹ️ Meal reminders disabled');
      }

      // Schedule exercise reminder if enabled
      if (prefs.enableExerciseReminder) {
        await _localNotificationsService.scheduleDailyNotification(
          id: 200,
          time: prefs.exerciseTime,
          title: 'Nhắc vận động',
          body: randomNotificationMessage(NotificationCategory.exercise),
        );
        debugPrint(
          '[NotificationScheduler] ✅ Scheduled exercise reminder at ${prefs.exerciseTime.hour}:${prefs.exerciseTime.minute}',
        );
      } else {
        debugPrint('[NotificationScheduler] ℹ️ Exercise reminder disabled');
      }

      // Schedule water reminder if enabled
      if (prefs.enableWaterReminder) {
        await _localNotificationsService.scheduleDailyNotification(
          id: 300,
          time: const TimeOfDay(hour: 10, minute: 0), // Default 10:00 AM
          title: 'Nhắc uống nước',
          body: randomNotificationMessage(NotificationCategory.water),
        );
        debugPrint(
          '[NotificationScheduler] ✅ Scheduled water reminder at 10:00',
        );
      } else {
        debugPrint('[NotificationScheduler] ℹ️ Water reminder disabled');
      }

      // Save last reschedule date
      if (_prefs != null) {
        await _prefs!.setString(_lastRescheduleDateKey, DateTime.now().toIso8601String());
      }
      
      debugPrint('[NotificationScheduler] ✅ All notifications rescheduled');
    } catch (e, stackTrace) {
      debugPrint('[NotificationScheduler] 🔥 Error rescheduling notifications: $e');
      debugPrint('[NotificationScheduler] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Initialize default schedules by loading preferences and rescheduling
  Future<void> initDefaultSchedules() async {
    // PHASE 1: Guard to prevent double initialization
    if (_initOnce) {
      debugPrint('[NotificationScheduler] ⏭️ init skipped (already initialized this session)');
      return;
    }
    _initOnce = true;
    
    try {
      debugPrint('[NotificationScheduler] 🔵 Initializing default schedules...');
      final repository = NotificationPrefsRepository();
      final prefs = await repository.load();
      await rescheduleAll(prefs);
      debugPrint('[NotificationScheduler] ✅ Default schedules initialized');
    } catch (e, stackTrace) {
      debugPrint(
        '[NotificationScheduler] 🔥 Error initializing default schedules: $e',
      );
      debugPrint('[NotificationScheduler] Stack trace: $stackTrace');
    }
  }
}

/// Riverpod provider for NotificationScheduler
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  final localNotificationsService = ref.read(localNotificationsServiceProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  return NotificationScheduler(localNotificationsService, prefs);
});

