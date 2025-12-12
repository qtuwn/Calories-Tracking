import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/notifications/push_notifications_service.dart';
import 'package:calories_app/shared/state/auth_providers.dart';

/// Provider that watches auth state and automatically updates FCM token
/// when a user logs in. Uses ref.listen to react to auth state changes.
final fcmTokenManagerProvider = Provider<void>((ref) {
  // Listen to auth state changes (this only fires on changes, not initial value)
  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    next.whenData((user) {
      if (user != null) {
        // User logged in - update FCM token
        debugPrint(
          '[FCMTokenManager] 🔵 User logged in (uid=${user.uid}), updating FCM token',
        );
        final pushService = ref.read(pushNotificationsServiceProvider);
        pushService.updateTokenForCurrentUser().catchError((error) {
          debugPrint(
            '[FCMTokenManager] 🔥 Error updating FCM token: $error',
          );
        });
      } else {
        // User logged out
        debugPrint('[FCMTokenManager] ⚠️ User logged out');
      }
    });
  });

  // Also check initial auth state
  final authStateAsync = ref.watch(authStateProvider);
  authStateAsync.whenData((user) {
    if (user != null) {
      // User is already logged in - update FCM token
      debugPrint(
        '[FCMTokenManager] 🔵 User already logged in (uid=${user.uid}), updating FCM token',
      );
      final pushService = ref.read(pushNotificationsServiceProvider);
      pushService.updateTokenForCurrentUser().catchError((error) {
        debugPrint(
          '[FCMTokenManager] 🔥 Error updating FCM token: $error',
        );
      });
    }
  });

  // The token refresh listener is already set up in PushNotificationsService.init()
  // and will automatically update Firestore when token refreshes
});

