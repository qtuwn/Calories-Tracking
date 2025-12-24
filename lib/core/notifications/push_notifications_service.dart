import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:calories_app/core/notifications/local_notifications_service.dart';

/// Top-level function to handle background messages
/// Must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    '[PushNotificationsService] Background message received: ${message.messageId}',
  );
  debugPrint(
    '[PushNotificationsService] Title: ${message.notification?.title}',
  );
  debugPrint(
    '[PushNotificationsService] Body: ${message.notification?.body}',
  );
  // You can add additional background processing here
}

/// Service for managing Firebase Cloud Messaging (push notifications)
///
/// ## Sending Push Notifications
///
/// ### Via Firebase Console (Single Device)
/// 1. Go to Firebase Console > Cloud Messaging
/// 2. Click "Send your first message"
/// 3. Enter notification title and body
/// 4. Click "Send test message"
/// 5. Enter the FCM token (stored in Firestore at `users/{uid}/fcmToken`)
/// 6. Click "Test"
///
/// ### Via Cloud Functions (Future Implementation)
/// A Cloud Function can send weekly summary pushes based on user stats:
/// ```dart
/// // Example Cloud Function (Node.js)
/// const admin = require('firebase-admin');
/// 
/// exports.sendWeeklySummary = functions.pubsub
///   .schedule('0 9 * * 1') // Every Monday at 9 AM
///   .onRun(async (context) => {
///     const usersSnapshot = await admin.firestore()
///       .collection('users')
///       .where('fcmToken', '!=', null)
///       .get();
///     
///     for (const userDoc of usersSnapshot.docs) {
///       const fcmToken = userDoc.data().fcmToken;
///       const weeklyStats = await calculateWeeklyStats(userDoc.id);
///       
///       await admin.messaging().send({
///         token: fcmToken,
///         notification: {
///           title: 'Tóm tắt tuần của bạn',
///           body: `Bạn đã đốt ${weeklyStats.caloriesBurned} calo tuần này!`,
///         },
///       });
///     }
///   });
/// ```
///
/// The FCM token is automatically stored in Firestore at `users/{uid}/fcmToken`
/// when a user logs in, and is updated whenever the token refreshes.
class PushNotificationsService {
  static final PushNotificationsService _instance =
      PushNotificationsService._internal();
  factory PushNotificationsService() => _instance;
  PushNotificationsService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;
  static bool _staticInitialized = false;
  Future<void>? _inFlightTokenUpdate;

  /// Initialize the push notifications service
  Future<void> init() async {
    // PHASE 3: Static guard to prevent double initialization
    if (_staticInitialized) {
      debugPrint('[PushNotificationsService] ⏭️ init skipped (already initialized this session)');
      return;
    }
    _staticInitialized = true;
    
    if (_initialized) {
      debugPrint('[PushNotificationsService] Already initialized');
      return;
    }

    try {
      // Request notification permissions
      await _requestPermissions();

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from a terminated state via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_onTokenRefresh);

      // Get and store initial token if user is logged in
      await _updateTokenIfLoggedIn();

      _initialized = true;
      debugPrint('[PushNotificationsService] ✅ Initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('[PushNotificationsService] 🔥 Error initializing: $e');
      debugPrint('[PushNotificationsService] Stack trace: $stackTrace');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      // Request permission for iOS
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        '[PushNotificationsService] Permission status: ${settings.authorizationStatus}',
      );

      // Request permission for Android 13+
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.request();
        debugPrint(
          '[PushNotificationsService] Android notification permission: $status',
        );
      }
    } catch (e) {
      debugPrint(
        '[PushNotificationsService] 🔥 Error requesting permissions: $e',
      );
    }
  }

  /// Handle foreground messages
  /// Shows a local notification when app is in foreground and logs debug info
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '[PushNotificationsService] 📬 Foreground message received: ${message.messageId}',
    );
    debugPrint(
      '[PushNotificationsService] Title: ${message.notification?.title ?? "N/A"}',
    );
    debugPrint(
      '[PushNotificationsService] Body: ${message.notification?.body ?? "N/A"}',
    );
    debugPrint(
      '[PushNotificationsService] Data: ${message.data}',
    );

    // Show local notification when app is in foreground
    if (message.notification != null) {
      final localNotificationsService = LocalNotificationsService();
      localNotificationsService.showInstantNotification(
        title: message.notification!.title ?? 'Thông báo mới',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Handle notification tap (when app is opened from notification)
  /// This is called when user taps a notification while app is in background
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint(
      '[PushNotificationsService] 🔔 Notification opened app: ${message.messageId}',
    );
    debugPrint(
      '[PushNotificationsService] Title: ${message.notification?.title ?? "N/A"}',
    );
    debugPrint(
      '[PushNotificationsService] Body: ${message.notification?.body ?? "N/A"}',
    );
    debugPrint(
      '[PushNotificationsService] Data: ${message.data}',
    );
    // TODO: Add navigation logic here based on message data
    // Example: Navigate to specific screen based on message.data['screen']
  }

  /// Get FCM token
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('[PushNotificationsService] FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('[PushNotificationsService] 🔥 Error getting token: $e');
      return null;
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String newToken) async {
    debugPrint(
      '[PushNotificationsService] Token refreshed: $newToken',
    );
    await _updateTokenIfLoggedIn();
  }

  /// Update FCM token in Firestore if user is logged in
  /// Only writes if token changed OR last sync > 24h
  Future<void> _updateTokenIfLoggedIn() async {
    // PHASE 3: Prevent concurrent duplicate writes
    if (_inFlightTokenUpdate != null) {
      debugPrint('[PushNotificationsService] ⏭️ Token update already in flight, skipping');
      return;
    }
    
    _inFlightTokenUpdate = _doUpdateTokenIfLoggedIn();
    try {
      await _inFlightTokenUpdate;
    } finally {
      _inFlightTokenUpdate = null;
    }
  }
  
  Future<void> _doUpdateTokenIfLoggedIn() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint(
          '[PushNotificationsService] No user logged in, skipping token update',
        );
        return;
      }

      final token = await getToken();
      if (token == null) {
        debugPrint(
          '[PushNotificationsService] ⚠️ No token available to store',
        );
        return;
      }

      // PHASE 3: Check if token changed or last sync > 24h
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final existingToken = userDoc.data()?['fcmToken'] as String?;
      final lastUpdated = userDoc.data()?['fcmTokenUpdatedAt'] as Timestamp?;
      
      if (existingToken == token && lastUpdated != null) {
        final lastUpdatedDate = lastUpdated.toDate();
        final hoursSinceUpdate = DateTime.now().difference(lastUpdatedDate).inHours;
        if (hoursSinceUpdate < 24) {
          debugPrint(
            '[PushNotificationsService] ⏭️ Token unchanged and recent (${hoursSinceUpdate}h ago), skipping update',
          );
          return;
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      debugPrint(
        '[PushNotificationsService] ✅ FCM token stored for user: ${user.uid}',
      );
    } catch (e) {
      debugPrint(
        '[PushNotificationsService] 🔥 Error updating token in Firestore: $e',
      );
    }
  }

  /// Manually update token (useful when user logs in)
  Future<void> updateTokenForCurrentUser() async {
    await _updateTokenIfLoggedIn();
  }

  /// Delete token from Firestore (useful when user logs out)
  Future<void> deleteTokenForCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': FieldValue.delete(),
      });

      debugPrint(
        '[PushNotificationsService] ✅ FCM token deleted for user: ${user.uid}',
      );
    } catch (e) {
      debugPrint(
        '[PushNotificationsService] 🔥 Error deleting token: $e',
      );
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('[PushNotificationsService] ✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint(
        '[PushNotificationsService] 🔥 Error subscribing to topic: $e',
      );
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('[PushNotificationsService] ✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint(
        '[PushNotificationsService] 🔥 Error unsubscribing from topic: $e',
      );
    }
  }
}

/// Riverpod provider for PushNotificationsService
final pushNotificationsServiceProvider =
    Provider<PushNotificationsService>((ref) {
  return PushNotificationsService();
});

