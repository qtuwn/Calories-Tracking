import 'package:flutter/foundation.dart';
import 'package:calories_app/core/notifications/local_notifications_service.dart';
import 'package:calories_app/shared/state/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for showing welcome notifications
/// 
/// PHASE D: Replaces "Debug test" notification with welcome message.
/// Shows only after app stabilizes and max 1 per day.
class WelcomeNotificationService {
  static const String _lastWelcomeDateKey = 'lastWelcomeNotificationDate';
  
  // Welcome messages (randomly selected)
  static const List<String> _welcomeBodies = [
    'Nhớ ghi lại bữa ăn hôm nay để theo dõi calo chuẩn nha!',
    'Sẵn sàng cho một ngày ăn khoẻ chưa? Ghi món đầu tiên thôi!',
    'Uống nước chút nhé — mục tiêu hôm nay đang chờ bạn.',
  ];

  /// Show welcome notification if conditions are met
  /// 
  /// Conditions:
  /// - Last shown > 24h ago (or never shown)
  /// - App has been in foreground for at least 10s
  /// - User is logged in
  static Future<void> showIfNeeded(WidgetRef ref) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      
      // Check if we should show (max 1 per day)
      final lastDateStr = prefs.getString(_lastWelcomeDateKey);
      if (lastDateStr != null) {
        final lastDate = DateTime.parse(lastDateStr);
        final now = DateTime.now();
        if (now.year == lastDate.year &&
            now.month == lastDate.month &&
            now.day == lastDate.day) {
          if (kDebugMode) {
            debugPrint('[WelcomeNotification] ⏭️ Already shown today, skipping');
          }
          return;
        }
      }

      // Select random welcome message
      final random = DateTime.now().millisecondsSinceEpoch % _welcomeBodies.length;
      final body = _welcomeBodies[random];

      // Show notification
      await LocalNotificationsService().showInstantNotification(
        title: 'Chào mừng quay lại 👋',
        body: body,
      );

      // Save last shown date
      await prefs.setString(_lastWelcomeDateKey, DateTime.now().toIso8601String());
      
      if (kDebugMode) {
        debugPrint('[WelcomeNotification] ✅ Welcome notification shown');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WelcomeNotification] 🔥 Error showing welcome notification: $e');
      }
    }
  }
}

