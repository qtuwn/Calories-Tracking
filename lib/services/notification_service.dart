import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// timezone support for zonedSchedule
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_item.dart';
import '../providers/notifications_provider.dart';
import 'firebase_service.dart';

/// NotificationService wraps FCM + local notifications + dynamic links.
/// In MOCK mode (USE_FIREBASE=false) it still provides local scheduling and
/// in-app add notification helper.
class NotificationService {
  final NotificationsProvider notificationsProvider;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  StreamSubscription? _onMessageSub;

  NotificationService({required this.notificationsProvider});

  Future<void> init({String? uid}) async {
    // initialize local notifications
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // initialize timezone database for zoned scheduling
    try {
      tz.initializeTimeZones();
    } catch (_) {}

    // Use Android initialization here; iOS/Darwin initialization can be added
    // when needed (flutter_local_notifications supports platform initialization).
    await _local.initialize(InitializationSettings(android: android));

    // If Firebase is enabled and you add `firebase_messaging` to pubspec,
    // you can register the FCM token and listen for foreground messages.
    // We attempt to wire basic FCM handling if Firebase is available. This
    // code is guarded and will log errors if messaging isn't available.
    if (FirebaseService.shouldUseFirebase()) {
      try {
        final fcm = FirebaseMessaging.instance;
        // Request permission on iOS/macOS if needed (no-op on Android)
        await fcm.requestPermission();

        // Get token and register with backend
        final token = await fcm.getToken();
        if (token != null && uid != null) {
          await FirebaseService.saveFcmToken(uid, token);
        }

        // Foreground messages: show local notification
        FirebaseMessaging.onMessage.listen((message) async {
          final title = message.notification?.title ?? 'Thông báo';
          final body = message.notification?.body ?? '';
          final deepLink = message.data['deepLink'] as String?;
          await showLocalAndStore(
            id: message.messageId ?? DateTime.now().toIso8601String(),
            title: title,
            body: body,
            deepLink: deepLink,
          );
        });
      } catch (e, st) {
        debugPrint('FCM wiring failed: $e');
        debugPrint(st.toString());
      }
    } else {
      // No-op when Firebase isn't used; developer can call registerFcmToken manually.
      debugPrint('Firebase disabled: FCM not wired');
    }
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
  }

  // Helper to show a local notification and store it in provider.
  Future<void> showLocalAndStore({
    required String id,
    required String title,
    required String body,
    String? deepLink,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default',
      'Default',
      channelDescription: 'Default channel',
      importance: Importance.max,
      priority: Priority.high,
    );
    await _local.show(
      id.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
    notificationsProvider.add(
      NotificationItem(id: id, title: title, body: body, deepLink: deepLink),
    );
  }

  Future<void> subscribeTopic(String topic) async {
    // If you add firebase_messaging, implement subscribeToTopic here.
    if (!FirebaseService.shouldUseFirebase()) return;
    debugPrint('subscribeTopic: $topic (no-op without firebase_messaging)');
  }

  Future<void> unsubscribeTopic(String topic) async {
    if (!FirebaseService.shouldUseFirebase()) return;
    debugPrint('unsubscribeTopic: $topic (no-op without firebase_messaging)');
  }

  /// Register an FCM token for the current user. This is a convenience
  /// helper that calls into `FirebaseService.saveFcmToken`. If you add
  /// `firebase_messaging` to the project, call this with the token you
  /// receive from FCM so the server can target notifications to the user.
  Future<void> registerFcmToken(String? uid, String token) async {
    if (uid == null) return;
    if (!FirebaseService.shouldUseFirebase()) return;
    try {
      await FirebaseService.saveFcmToken(uid, token);
    } catch (e) {
      debugPrint('registerFcmToken failed: $e');
    }
  }

  /// Schedule a local reminder (MOCK mode or as an in-app reminder).
  Future<void> scheduleLocalReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduled,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      id,
      'Reminders',
      channelDescription: 'Scheduled reminders',
      importance: Importance.defaultImportance,
    );
    final details = NotificationDetails(android: androidDetails);
    // Use zonedSchedule with timezone-aware TZDateTime. We initialized
    // timezone database in init(). This avoids deprecated schedule() usage
    // and handles DST/timezone correctly.
    try {
      final tzDt = tz.TZDateTime.from(scheduled, tz.local);
      await _local.zonedSchedule(
        id.hashCode,
        title,
        body,
        tzDt,
        details,
        // newer API requires androidScheduleMode; use exactAllowWhileIdle to
        // mirror previous androidAllowWhileIdle behavior.
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // no repeat matching
        matchDateTimeComponents: null,
      );
    } catch (e) {
      // Fallback to a delayed show when timezone scheduling is unavailable.
      final delay = scheduled.difference(DateTime.now());
      if (delay <= Duration.zero) {
        await _local.show(id.hashCode, title, body, details);
      } else {
        Future.delayed(delay, () async {
          await _local.show(id.hashCode, title, body, details);
        });
      }
    }
    notificationsProvider.add(
      NotificationItem(
        id: id,
        title: title,
        body: body,
        timestamp: scheduled.toUtc(),
      ),
    );
  }
}
