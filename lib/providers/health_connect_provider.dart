import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simple provider tracking Health Connect connections per feature.
///
/// This is intentionally lightweight: it only tracks boolean flags for the
/// features that use Health Connect (nutrition, activity, steps, weight).
/// You can extend it later to persist the state or to perform the actual
/// integration flow.
class HealthConnectProvider extends ChangeNotifier {
  bool _nutrition = false;
  bool _activity = false;
  bool _steps = false;
  bool _weight = false;

  bool get connectedNutrition => _nutrition;
  bool get connectedActivity => _activity;
  bool get connectedSteps => _steps;
  bool get connectedWeight => _weight;

  void setNutritionConnected(bool v) {
    _nutrition = v;
    notifyListeners();
  }

  void setActivityConnected(bool v) {
    _activity = v;
    notifyListeners();
  }

  void setStepsConnected(bool v) {
    _steps = v;
    notifyListeners();
  }

  void setWeightConnected(bool v) {
    _weight = v;
    notifyListeners();
  }

  /// Convenience to mark all connected (used for quick debug/dev flows).
  void setAll(bool v) {
    _nutrition = v;
    _activity = v;
    _steps = v;
    _weight = v;
    notifyListeners();
  }

  /// Request permission to read weight from the platform health store.
  ///
  /// On iOS this uses HealthKit via the `health` plugin. On Android this will
  /// attempt to open the Health Connect Play Store page as a fallback; a full
  /// Health Connect integration would require the Health Connect client SDK.
  Future<bool> requestWeightPermission() async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final types = <HealthDataType>[HealthDataType.WEIGHT];
        final health = Health();
        await health.configure();
        final granted = await health.requestAuthorization(types);
        if (granted) setWeightConnected(true);
        return granted;
      } else if (Platform.isAndroid) {
        // Try to open Health Connect app in Play Store so user can install/config
        final uri = Uri.parse(
          'market://details?id=com.google.android.apps.healthdata',
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          final web = Uri.parse(
            'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
          );
          await launchUrl(web);
        }
        // We cannot determine grant state here; caller should verify or rely on
        // the native plugin integration. Return false to indicate unknown.
        return false;
      }
    } catch (_) {}
    return false;
  }

  /// Request permission to read steps/activity data.
  Future<bool> requestStepsPermission() async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final types = <HealthDataType>[HealthDataType.STEPS];
        final health = Health();
        await health.configure();
        final granted = await health.requestAuthorization(types);
        if (granted) setStepsConnected(true);
        return granted;
      } else if (Platform.isAndroid) {
        final uri = Uri.parse(
          'market://details?id=com.google.android.apps.healthdata',
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          final web = Uri.parse(
            'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
          );
          await launchUrl(web);
        }
        return false;
      }
    } catch (_) {}
    return false;
  }

  /// Convenience method to request both weight and steps permissions.
  Future<bool> requestAll() async {
    final w = await requestWeightPermission();
    final s = await requestStepsPermission();
    // If either granted on iOS, mark nutrition/activity accordingly (best-effort).
    if (w || s) {
      setNutritionConnected(true);
      setActivityConnected(true);
    }
    return w || s;
  }
}
