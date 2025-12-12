import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service for managing local notifications
class LocalNotificationsService {
  static final LocalNotificationsService _instance =
      LocalNotificationsService._internal();
  factory LocalNotificationsService() => _instance;
  LocalNotificationsService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Configure local timezone to Vietnam (Asia/Ho_Chi_Minh)
  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      // Vietnam timezone (no daylight saving issues)
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      debugPrint(
        '[LocalNotificationsService] Timezone initialized: Asia/Ho_Chi_Minh',
      );
    } catch (_) {
      // Fallback to UTC to avoid crashes
      tz.setLocalLocation(tz.getLocation('UTC'));
      debugPrint(
        '[LocalNotificationsService] ⚠️ Failed to set Vietnam timezone, using UTC',
      );
    }
  }

  /// Get the next instance of a given time (today or tomorrow)
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Initialize the local notifications service
  Future<void> init() async {
    if (_initialized) {
      debugPrint('[LocalNotificationsService] Already initialized');
      return;
    }

    try {
      // Configure timezone first
      await _configureLocalTimeZone();

      // Android initialization settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Initialization settings
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize the plugin
      final initialized = await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized == true) {
        // Create notification channel for Android
        await _createNotificationChannel();

        // Request runtime notification permission where needed
        await _ensurePermissions();

        _initialized = true;
        debugPrint('[LocalNotificationsService] ✅ Initialized successfully');
      } else {
        debugPrint('[LocalNotificationsService] ⚠️ Initialization failed');
      }
    } catch (e, stackTrace) {
      debugPrint('[LocalNotificationsService] 🔥 Error initializing: $e');
      debugPrint('[LocalNotificationsService] Stack trace: $stackTrace');
    }
  }

  /// Request notification permissions (Android 13+ / iOS)
  Future<void> _ensurePermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        final enabled = await androidImpl?.areNotificationsEnabled() ?? false;
        if (!enabled) {
          final requested =
              await androidImpl?.requestNotificationsPermission() ?? false;
          debugPrint(
            '[LocalNotificationsService] Android notifications permission: $requested',
          );
        } else {
          debugPrint(
            '[LocalNotificationsService] Android notifications already enabled',
          );
        }
      } else if (Platform.isIOS) {
        final iosImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();

        await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint(
          '[LocalNotificationsService] iOS permissions requested',
        );
      }
    } catch (e) {
      debugPrint(
        '[LocalNotificationsService] ⚠️ Error requesting permissions: $e',
      );
    }
  }

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'default_channel',
      'General Notifications',
      description: 'General health & calorie reminders',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    debugPrint('[LocalNotificationsService] ✅ Notification channel created');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
      '[LocalNotificationsService] Notification tapped: ${response.id}',
    );
    // TODO: Navigation logic can be added here if needed
  }

  /// Show an instant notification
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      debugPrint(
        '[LocalNotificationsService] ⚠️ Not initialized, cannot show notification',
      );
      return;
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'default_channel',
        'General Notifications',
        channelDescription: 'General health & calorie reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      debugPrint(
        '[LocalNotificationsService] ✅ Instant notification shown: $title',
      );
    } catch (e) {
      debugPrint(
        '[LocalNotificationsService] 🔥 Error showing notification: $e',
      );
    }
  }

  /// Schedule a daily notification at a specific time
  Future<void> scheduleDailyNotification({
    required int id,
    required TimeOfDay time,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      debugPrint(
        '[LocalNotificationsService] ⚠️ Not initialized, cannot schedule notification',
      );
      return;
    }

    try {
      // Use helper method to get next instance of the time
      final scheduledDate = _nextInstanceOfTime(time);

      const androidDetails = AndroidNotificationDetails(
        'default_channel',
        'General Notifications',
        channelDescription: 'General health & calorie reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        // Use INEXACT scheduling to avoid SCHEDULE_EXACT_ALARM permission
        // on Android 13+ (API 33+). This is enough for daily reminders.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // uiLocalNotificationDateInterpretation removed in flutter_local_notifications 19.5.0+
        // iOS now uses absoluteTime by default
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );

      debugPrint(
        '[LocalNotificationsService] ✅ Daily notification scheduled: '
        '$title at ${time.hour}:${time.minute}',
      );
    } catch (e) {
      debugPrint(
        '[LocalNotificationsService] 🔥 Error scheduling notification: $e',
      );
    }
  }

  /// Cancel a specific notification by ID
  Future<void> cancelNotification(int id) async {
    if (!_initialized) return;

    try {
      await _notificationsPlugin.cancel(id);
      debugPrint('[LocalNotificationsService] ✅ Notification cancelled: $id');
    } catch (e) {
      debugPrint(
        '[LocalNotificationsService] 🔥 Error cancelling notification: $e',
      );
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    if (!_initialized) return;

    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('[LocalNotificationsService] ✅ All notifications cancelled');
    } catch (e) {
      debugPrint(
        '[LocalNotificationsService] 🔥 Error cancelling all notifications: $e',
      );
    }
  }
}

/// Riverpod provider for LocalNotificationsService
final localNotificationsServiceProvider =
    Provider<LocalNotificationsService>((ref) {
  return LocalNotificationsService();
});
