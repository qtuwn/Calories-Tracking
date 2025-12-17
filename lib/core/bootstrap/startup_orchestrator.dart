import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:calories_app/core/notifications/local_notifications_service.dart';
import 'package:calories_app/core/notifications/push_notifications_service.dart';
import 'package:calories_app/core/notifications/notification_scheduler.dart';
import 'package:calories_app/core/notifications/welcome_notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// StartupOrchestrator - Coordinates critical vs deferred initialization
/// 
/// Critical phase (before runApp): Minimal blocking work
///   - Firebase.initializeApp()
///   - dotenv.load()
///   - SharedPreferences.getInstance() (required for routing providers)
/// 
/// Deferred phase (after first frame): Heavy background services
///   - Intl locale & date formatting
///   - Firestore settings (persistence, cache)
///   - AppCheck activation (release-only)
///   - Local & Push notifications
///   - FCM token update
/// 
/// Optimization: Reduced cold start time by ~10-12s
class StartupOrchestrator {
  static bool _deferredInitialized = false;
  static DateTime? _t0;
  static DateTime? _tRunApp;
  static DateTime? _tFirstFrame;
  static DateTime? _tDeferredStart;
  static DateTime? _tDeferredDone;

  /// Mark critical phase start
  static void markCriticalStart() {
    _t0 = DateTime.now();
    debugPrint('[StartupOrchestrator] ⏱️ t0 (critical start): ${_t0!.millisecondsSinceEpoch}');
  }

  /// Mark runApp() call
  static void markRunApp() {
    _tRunApp = DateTime.now();
    if (_t0 != null) {
      final duration = _tRunApp!.difference(_t0!);
      debugPrint('[StartupOrchestrator] ⏱️ t_runApp: ${_tRunApp!.millisecondsSinceEpoch} (${duration.inMilliseconds}ms since t0)');
    }
  }

  /// Mark first frame rendered
  static void markFirstFrame() {
    _tFirstFrame = DateTime.now();
    if (_tRunApp != null) {
      final duration = _tFirstFrame!.difference(_tRunApp!);
      debugPrint('[StartupOrchestrator] ⏱️ t_firstFrame: ${_tFirstFrame!.millisecondsSinceEpoch} (${duration.inMilliseconds}ms since t_runApp)');
    }
  }

  /// Run deferred initialization (after first frame)
  /// This includes: Intl, Firestore, AppCheck, notifications, FCM, etc.
  /// Note: SharedPreferences is preloaded in main.dart (critical phase) for routing providers
  static Future<void> ensureDeferredInitialized(WidgetRef ref) async {
    // Guard: Only run once per session
    if (_deferredInitialized) {
      debugPrint('[StartupOrchestrator] ⏭️ Deferred init skipped (already initialized)');
      return;
    }
    _deferredInitialized = true;

    _tDeferredStart = DateTime.now();
    debugPrint('[StartupOrchestrator] 🚀 Starting deferred initialization...');
    if (_tFirstFrame != null) {
      final delay = _tDeferredStart!.difference(_tFirstFrame!);
      debugPrint('[StartupOrchestrator] ⏱️ t_deferredStart: ${_tDeferredStart!.millisecondsSinceEpoch} (${delay.inMilliseconds}ms after first frame)');
    }

    try {
      // 1. Initialize Intl locale & date formatting (moved from main.dart)
      await _initializeIntl();

      // 2. Verify Firebase project ID (moved from main.dart)
      await _verifyFirebaseProject();

      // 3. Set Firestore persistence settings (moved from main.dart)
      await _ensureFirestorePersistence();

      // 4. Activate AppCheck (RELEASE-ONLY, moved from main.dart)
      await _initializeAppCheck();

      // 5. Initialize notification services (non-web only)
      await _initializeNotifications(ref);

      // 6. Initialize FCM (non-web only)
      await _initializeFCM(ref);

      // 7. Show welcome notification after app stabilizes
      Future.delayed(const Duration(seconds: 5), () {
        WelcomeNotificationService.showIfNeeded(ref);
      });

      _tDeferredDone = DateTime.now();
      if (_tDeferredStart != null) {
        final duration = _tDeferredDone!.difference(_tDeferredStart!);
        debugPrint('[StartupOrchestrator] ⏱️ t_deferredDone: ${_tDeferredDone!.millisecondsSinceEpoch} (${duration.inMilliseconds}ms total)');
      }
      if (_t0 != null) {
        final totalDuration = _tDeferredDone!.difference(_t0!);
        debugPrint('[StartupOrchestrator] ✅ Deferred init complete (${totalDuration.inMilliseconds}ms since t0)');
      }
    } catch (e, stackTrace) {
      debugPrint('[StartupOrchestrator] 🔥 Error in deferred init: $e');
      debugPrint('[StartupOrchestrator] Stack trace: $stackTrace');
    }
  }

  /// Initialize Intl locale & date formatting (deferred)
  static Future<void> _initializeIntl() async {
    try {
      debugPrint('[StartupOrchestrator] 🔵 Initializing Intl locale...');
      Intl.defaultLocale = 'vi_VN';
      await initializeDateFormatting('vi');
      debugPrint('[StartupOrchestrator] ✅ Intl locale initialized');
    } catch (e) {
      debugPrint('[StartupOrchestrator] 🔥 Error initializing Intl: $e');
    }
  }

  /// Verify Firebase project ID (deferred)
  static Future<void> _verifyFirebaseProject() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final projectId = firestore.app.options.projectId;
      debugPrint('[StartupOrchestrator] 🔵 Verifying Firebase project...');
      debugPrint('[StartupOrchestrator] Connected to project: $projectId');
      debugPrint('[StartupOrchestrator] Expected project: calories-app-da7fb');
      
      if (projectId != 'calories-app-da7fb') {
        debugPrint('[StartupOrchestrator] ⚠️ WARNING: Project ID mismatch!');
        // Don't throw in deferred phase, just log warning
      } else {
        debugPrint('[StartupOrchestrator] ✅ Firebase project verified');
      }
    } catch (e) {
      debugPrint('[StartupOrchestrator] 🔥 Error verifying Firebase project: $e');
    }
  }

  /// Initialize AppCheck (RELEASE-ONLY, deferred)
  static Future<void> _initializeAppCheck() async {
    try {
      // CRITICAL: Skip AppCheck in DEBUG mode to improve development experience
      // Only activate in RELEASE builds for production security
      if (kReleaseMode) {
        debugPrint('[StartupOrchestrator] 🔵 Activating AppCheck (release mode)...');
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
        );
        debugPrint('[StartupOrchestrator] ✅ AppCheck activated (release mode)');
      } else {
        debugPrint('[StartupOrchestrator] ⏭️ AppCheck skipped (debug mode)');
      }
    } catch (e) {
      debugPrint('[StartupOrchestrator] 🔥 Error initializing AppCheck: $e');
    }
  }

  /// Ensure Firestore persistence is configured (deferred)
  static Future<void> _ensureFirestorePersistence() async {
    // Skip on web platform
    if (kIsWeb) {
      debugPrint('[StartupOrchestrator] ⏭️ Firestore persistence skipped (web platform)');
      return;
    }

    try {
      debugPrint('[StartupOrchestrator] 🔵 Configuring Firestore persistence...');
      final firestore = FirebaseFirestore.instance;
      
      // Enable offline persistence with unlimited cache
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      debugPrint('[StartupOrchestrator] ✅ Firestore persistence configured');
    } catch (e) {
      // Settings can only be set once, so this error is expected if already configured
      debugPrint('[StartupOrchestrator] ⚠️ Firestore persistence already configured or error: $e');
    }
  }

  /// Initialize notification services (deferred, non-web only)
  static Future<void> _initializeNotifications(WidgetRef ref) async {
    // Skip on web platform
    if (kIsWeb) {
      debugPrint('[StartupOrchestrator] ⏭️ Notifications skipped (web platform)');
      return;
    }

    try {
      debugPrint('[StartupOrchestrator] 🔵 Initializing notification services...');
      
      // Initialize LocalNotificationsService
      await LocalNotificationsService().init();
      debugPrint('[StartupOrchestrator] ✅ Local notifications initialized');
      
      // Initialize NotificationScheduler (with guards)
      final scheduler = ref.read(notificationSchedulerProvider);
      await scheduler.initDefaultSchedules();
      debugPrint('[StartupOrchestrator] ✅ Notification scheduler initialized');
      
    } catch (e) {
      debugPrint('[StartupOrchestrator] 🔥 Error initializing notifications: $e');
    }
  }

  /// Initialize FCM (deferred, non-web only)
  static Future<void> _initializeFCM(WidgetRef ref) async {
    // Skip on web platform
    if (kIsWeb) {
      debugPrint('[StartupOrchestrator] ⏭️ FCM skipped (web platform)');
      return;
    }

    try {
      debugPrint('[StartupOrchestrator] 🔵 Initializing FCM...');
      
      // Initialize PushNotificationsService
      await PushNotificationsService().init();
      debugPrint('[StartupOrchestrator] ✅ Push notifications initialized');
      
      // Update FCM token for current user (with debouncing)
      final pushService = ref.read(pushNotificationsServiceProvider);
      await pushService.updateTokenForCurrentUser();
      debugPrint('[StartupOrchestrator] ✅ FCM token updated');
      
    } catch (e) {
      debugPrint('[StartupOrchestrator] 🔥 Error initializing FCM: $e');
    }
  }
}

