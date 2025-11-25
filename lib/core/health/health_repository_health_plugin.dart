import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'health_repository.dart';

class HealthRepositoryHealthPlugin implements HealthRepository {
  final Health _health = Health();

  static const _types = <HealthDataType>[HealthDataType.STEPS];

  @override
  Future<bool> requestPermission() async {
    debugPrint('[HealthRepo] ▶ requestPermission() called');
    debugPrint('[HealthRepo] Requesting permission for types: $_types');

    try {
      // Step 1: Request Android runtime permission for activity recognition
      debugPrint('[HealthRepo] Step 1: requesting ACTIVITY_RECOGNITION runtime permission');
      final activityStatus = await Permission.activityRecognition.request();
      debugPrint('[HealthRepo] ACTIVITY_RECOGNITION permission result: ${activityStatus.name}');
      
      if (!activityStatus.isGranted) {
        debugPrint('[HealthRepo] ❌ ACTIVITY_RECOGNITION permission denied');
        return false;
      }
      debugPrint('[HealthRepo] ✅ ACTIVITY_RECOGNITION permission granted');

      // Step 2: Check if Health Connect permissions are already granted
      debugPrint('[HealthRepo] Step 2: Health.hasPermissions(...)');
      final hasPerm = await _health.hasPermissions(_types) ?? false;
      debugPrint('[HealthRepo] Step 2: Health.hasPermissions(...) = $hasPerm');
      
      if (hasPerm) {
        debugPrint('[HealthRepo] ✅ Health Connect permissions already granted');
        return true;
      }
      debugPrint('[HealthRepo] Health Connect permissions not granted yet, requesting...');

      // Step 3: Request Health Connect permissions (STEPS only, READ access)
      debugPrint('[HealthRepo] Step 3: requesting Health Connect authorization for STEPS only');
      debugPrint('[HealthRepo] Types: $_types');
      debugPrint('[HealthRepo] Access: [HealthDataAccess.READ]');
      
      const types = [HealthDataType.STEPS];
      const permissions = [HealthDataAccess.READ];
      final granted = await _health.requestAuthorization(types, permissions: permissions);
      
      debugPrint('[HealthRepo] requestAuthorization() result: $granted');
      
      if (granted) {
        debugPrint('[HealthRepo] ✅ Health Connect permissions granted successfully');
      } else {
        debugPrint('[HealthRepo] ❌ Health Connect permissions denied or not granted');
      }
      
      return granted;
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
    debugPrint('[HealthRepo] getTodayActiveCalories() called - returning 0.0 (calories not synced from Health Connect)');
    return 0.0;
  }
}

