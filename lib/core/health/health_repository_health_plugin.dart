import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'health_repository.dart';

class HealthRepositoryHealthPlugin implements HealthRepository {
  final Health _health = Health();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static const _types = <HealthDataType>[HealthDataType.STEPS];

  /// Get Android SDK version for platform-specific behavior
  Future<int> _getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;

    try {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    } catch (e) {
      debugPrint('[HealthRepo] Error getting Android SDK version: $e');
      return 0;
    }
  }

  /// Check if Health Connect is available on the device
  /// Returns: true if available, false otherwise
  Future<bool> _isHealthConnectAvailable() async {
    try {
      // Use health plugin's built-in check for Health Connect availability
      final status = await _health.getHealthConnectSdkStatus();
      debugPrint('[HealthRepo] Health Connect SDK status: $status');

      // SDK_AVAILABLE (3) means Health Connect is ready to use
      // SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED (2) means update needed
      // SDK_UNAVAILABLE (1) means not available
      if (status == HealthConnectSdkStatus.sdkAvailable) {
        debugPrint('[HealthRepo] ✅ Health Connect SDK is available');
        return true;
      } else if (status ==
          HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        debugPrint('[HealthRepo] ⚠️ Health Connect available but needs update');
        // Still return true as we can prompt user to update
        return true;
      } else {
        debugPrint('[HealthRepo] ❌ Health Connect SDK is not available');
        return false;
      }
    } catch (e) {
      debugPrint('[HealthRepo] Error checking Health Connect availability: $e');
      // On Android 14+, Health Connect is built into the system
      // so we assume it's available even if the check fails
      final sdkVersion = await _getAndroidSdkVersion();
      return sdkVersion >= 34;
    }
  }

  @override
  Future<bool> requestPermission() async {
    // IMPORTANT: Health Connect Clean Install Requirement
    // When updating the health plugin or app version for Health Connect compatibility:
    // 1. The app MUST be completely uninstalled from the device before reinstalling
    // 2. Hot restart, flutter run, or reinstall-over-existing APK is INSUFFICIENT
    // 3. Use: adb uninstall com.tuquoctuan.calories_app
    // 4. Then run: flutter clean && flutter pub get && flutter run
    // This is required because Health Connect caches app metadata including versionCode.

    debugPrint('[HealthRepo] ▶ requestPermission() called');
    debugPrint('[HealthRepo] Requesting permission for types: $_types');

    try {
      // Step 0: Get Android SDK version for platform-specific behavior
      final sdkVersion = await _getAndroidSdkVersion();
      debugPrint('[HealthRepo] Android SDK version: $sdkVersion');

      // Step 1: Check Health Connect availability first (Android 13+)
      if (sdkVersion >= 33) {
        debugPrint(
          '[HealthRepo] Step 1: Checking Health Connect availability...',
        );
        final isAvailable = await _isHealthConnectAvailable();
        if (!isAvailable) {
          debugPrint(
            '[HealthRepo] ❌ Health Connect is not available on this device',
          );
          debugPrint(
            '[HealthRepo] User needs to install Health Connect from Play Store',
          );
          return false;
        }
        debugPrint('[HealthRepo] ✅ Health Connect is available');
      }

      // Step 2: Configure Health plugin (required before requesting authorization)
      debugPrint('[HealthRepo] Step 2: Configuring Health plugin');
      await _health.configure();
      debugPrint('[HealthRepo] ✅ Health plugin configured');

      // Step 3: Check and request Android runtime permission for activity recognition
      debugPrint(
        '[HealthRepo] Step 3: Checking ACTIVITY_RECOGNITION permission status',
      );
      if (await Permission.activityRecognition.isDenied) {
        debugPrint(
          '[HealthRepo] ACTIVITY_RECOGNITION is denied, requesting...',
        );
        final activityStatus = await Permission.activityRecognition.request();
        debugPrint(
          '[HealthRepo] ACTIVITY_RECOGNITION permission result: ${activityStatus.name}',
        );

        if (!activityStatus.isGranted) {
          debugPrint('[HealthRepo] ❌ ACTIVITY_RECOGNITION permission denied');
          return false;
        }
        debugPrint('[HealthRepo] ✅ ACTIVITY_RECOGNITION permission granted');
      } else {
        debugPrint(
          '[HealthRepo] ✅ ACTIVITY_RECOGNITION permission already granted',
        );
      }

      // Step 4: Branch based on Android version
      if (sdkVersion >= 33) {
        // Android 13+ (API 33+): Health Connect is mandatory
        debugPrint(
          '[HealthRepo] Android 13+ detected - using Health Connect flow',
        );
        return await _requestHealthConnectPermission(sdkVersion);
      } else {
        // Android 12 and below: Legacy behavior (may still use Health Connect if available)
        debugPrint(
          '[HealthRepo] Android 12 or below detected - using legacy flow',
        );
        return await _requestLegacyPermission();
      }
    } catch (e, stackTrace) {
      debugPrint('[HealthRepo] ❌ Error requesting permission: $e');
      debugPrint('[HealthRepo] Stack trace: $stackTrace');
      developer.log(
        'Error requesting Health Connect permission',
        name: 'HealthRepo',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Request Health Connect permissions for Android 13+
  Future<bool> _requestHealthConnectPermission(int sdkVersion) async {
    debugPrint(
      '[HealthRepo] ▶ _requestHealthConnectPermission() - Android 13+ flow',
    );
    debugPrint(
      '[HealthRepo] SDK version: $sdkVersion (${sdkVersion >= 34 ? "Android 14+" : "Android 13"})',
    );

    try {
      // Check if Health Connect permissions are already granted
      debugPrint(
        '[HealthRepo] Checking existing Health Connect permissions...',
      );
      final hasPerm = await _health.hasPermissions(_types) ?? false;
      debugPrint('[HealthRepo] Health.hasPermissions(...) = $hasPerm');

      if (hasPerm) {
        debugPrint('[HealthRepo] ✅ Health Connect permissions already granted');
        return true;
      }

      debugPrint(
        '[HealthRepo] Health Connect permissions not granted, requesting...',
      );

      // Request Health Connect permissions (STEPS only, READ access)
      // IMPORTANT: On Android 14+, Health Connect is part of the system framework
      // The permission dialog is handled by the system, not a separate app
      debugPrint(
        '[HealthRepo] Requesting Health Connect authorization for STEPS (READ)',
      );
      debugPrint(
        '[HealthRepo] Note: Android ${sdkVersion >= 34 ? "14+ uses system Health Connect" : "13 uses Health Connect APK"}',
      );

      const types = [HealthDataType.STEPS];
      const permissions = [HealthDataAccess.READ];

      final granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );
      debugPrint('[HealthRepo] requestAuthorization() result: $granted');

      if (granted) {
        debugPrint(
          '[HealthRepo] ✅ Health Connect permissions granted successfully',
        );
      } else {
        debugPrint('[HealthRepo] ❌ Health Connect permissions denied');
        debugPrint('[HealthRepo] Possible reasons:');
        debugPrint('[HealthRepo]   1. User denied the permission');
        debugPrint(
          '[HealthRepo]   2. AndroidManifest.xml missing intent-filter for ACTION_SHOW_PERMISSIONS_RATIONALE',
        );
        debugPrint(
          '[HealthRepo]   3. AndroidManifest.xml missing activity-alias for VIEW_PERMISSION_USAGE (Android 14+)',
        );
        debugPrint(
          '[HealthRepo]   4. Missing android.intent.category.HEALTH_PERMISSIONS category',
        );
        debugPrint(
          '[HealthRepo]   5. App needs to be uninstalled and reinstalled after manifest changes',
        );
      }

      return granted;
    } catch (e, stackTrace) {
      debugPrint(
        '[HealthRepo] ❌ Error in Health Connect permission request: $e',
      );
      debugPrint('[HealthRepo] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Request permissions for Android 12 and below (legacy flow)
  Future<bool> _requestLegacyPermission() async {
    debugPrint(
      '[HealthRepo] ▶ _requestLegacyPermission() - Android 12 and below flow',
    );

    try {
      // For older Android versions, try Health Connect first, fallback to legacy if needed
      debugPrint('[HealthRepo] Attempting Health Connect authorization...');
      const types = [HealthDataType.STEPS];
      const permissions = [HealthDataAccess.READ];

      final granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );
      debugPrint('[HealthRepo] Legacy requestAuthorization() result: $granted');

      if (granted) {
        debugPrint('[HealthRepo] ✅ Legacy Health Connect permissions granted');
        return true;
      } else {
        debugPrint('[HealthRepo] ❌ Legacy Health Connect permissions denied');
        debugPrint(
          '[HealthRepo] Note: On older Android, Google Fit may be used as fallback',
        );
        // Note: The health plugin handles Google Fit fallback internally
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('[HealthRepo] ❌ Error in legacy permission request: $e');
      debugPrint('[HealthRepo] Stack trace: $stackTrace');
      return false;
    }
  }

  @override
  Future<int> getTodaySteps() async {
    debugPrint('[HealthRepo] ▶ getTodaySteps() called');

    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);

      debugPrint('[HealthRepo] Querying steps from $start to $now');

      final steps = await _health.getTotalStepsInInterval(start, now);
      final stepCount = steps ?? 0;

      debugPrint('[HealthRepo] ✅ Steps retrieved: $stepCount');

      return stepCount;
    } catch (e, stackTrace) {
      debugPrint('[HealthRepo] ❌ Error getting steps: $e');
      debugPrint('[HealthRepo] Stack trace: $stackTrace');
      developer.log(
        'Error getting today steps',
        name: 'HealthRepo',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  @override
  Future<double> getTodayActiveCalories() async {
    // Calories are no longer synced from Health Connect.
    // This method is kept for interface compatibility but always returns 0.0.
    // Do NOT call Health Connect for calories - use workout sessions instead.
    debugPrint(
      '[HealthRepo] getTodayActiveCalories() called - returning 0.0 (calories not synced from Health Connect)',
    );
    return 0.0;
  }

  @override
  Future<int> getStepsForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[HealthRepo] ▶ getStepsForDateRange() called: $startDate to $endDate',
      );
    }

    try {
      // Normalize dates to start of day
      final normalizedStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final normalizedEnd = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
        999,
      );

      if (kDebugMode) {
        debugPrint(
          '[HealthRepo] Querying steps from $normalizedStart to $normalizedEnd',
        );
      }

      final steps = await _health.getTotalStepsInInterval(
        normalizedStart,
        normalizedEnd,
      );
      final stepCount = steps ?? 0;

      if (kDebugMode) {
        debugPrint('[HealthRepo] ✅ Total steps in range: $stepCount');
      }

      return stepCount;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[HealthRepo] ❌ Error getting steps for date range: $e');
        debugPrint('[HealthRepo] Stack trace: $stackTrace');
      }
      developer.log(
        'Error getting steps for date range',
        name: 'HealthRepo',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  @override
  Future<Map<DateTime, int>> getDailySteps({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[HealthRepo] ▶ getDailySteps() called: $startDate to $endDate',
      );
    }

    try {
      // Normalize start to beginning of day
      final normalizedStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

      final result = <DateTime, int>{};
      var currentDay = normalizedStart;

      // Iterate day by day and query steps for each day
      while (currentDay.isBefore(normalizedEnd) ||
          currentDay.isAtSameMomentAs(normalizedEnd)) {
        final dayStart = DateTime(
          currentDay.year,
          currentDay.month,
          currentDay.day,
        );
        final dayEnd = DateTime(
          currentDay.year,
          currentDay.month,
          currentDay.day,
          23,
          59,
          59,
          999,
        );

        try {
          final daySteps = await _health.getTotalStepsInInterval(
            dayStart,
            dayEnd,
          );
          result[dayStart] = daySteps ?? 0;
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              '[HealthRepo] ⚠️ Error getting steps for day $dayStart: $e',
            );
          }
          result[dayStart] = 0;
        }

        // Move to next day
        currentDay = DateTime(
          currentDay.year,
          currentDay.month,
          currentDay.day + 1,
        );
      }

      if (kDebugMode) {
        debugPrint(
          '[HealthRepo] ✅ Generated ${result.length} daily step entries',
        );
      }

      return result;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[HealthRepo] ❌ Error getting daily steps: $e');
        debugPrint('[HealthRepo] Stack trace: $stackTrace');
      }
      developer.log(
        'Error getting daily steps',
        name: 'HealthRepo',
        error: e,
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  @override
  Future<bool> hasStepsPermission() async {
    if (kDebugMode) {
      debugPrint('[HealthRepo] ▶ hasStepsPermission() called');
    }

    try {
      // Check Android runtime permission first
      final activityStatus = await Permission.activityRecognition.status;
      if (!activityStatus.isGranted) {
        if (kDebugMode) {
          debugPrint(
            '[HealthRepo] ❌ ACTIVITY_RECOGNITION permission not granted',
          );
        }
        return false;
      }

      // Get Android SDK version for platform-specific checks
      final sdkVersion = await _getAndroidSdkVersion();
      if (kDebugMode) {
        debugPrint('[HealthRepo] Android SDK version: $sdkVersion');
      }

      // Check Health Connect permission
      final hasPerm = await _health.hasPermissions(_types) ?? false;
      if (kDebugMode) {
        debugPrint('[HealthRepo] Health Connect permission: $hasPerm');
      }

      return hasPerm;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[HealthRepo] ❌ Error checking permission: $e');
        debugPrint('[HealthRepo] Stack trace: $stackTrace');
      }
      developer.log(
        'Error checking steps permission',
        name: 'HealthRepo',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
