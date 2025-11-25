import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_repository.dart';
import 'health_repository_health_plugin.dart';

/// Provider for HealthRepository.
/// 
/// Currently uses the health plugin implementation.
/// 
/// TODO: In the future, replace HealthRepositoryHealthPlugin with
/// HealthRepositoryNative (using MethodChannel) by changing this provider:
/// 
/// ```dart
/// final healthRepositoryProvider = Provider<HealthRepository>((ref) {
///   return HealthRepositoryNative();
/// });
/// ```
/// 
/// This abstraction ensures the UI and business logic remain unchanged
/// when switching implementations.
final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  // In the future, I will replace this with a native implementation:
  // return HealthRepositoryNative();
  return HealthRepositoryHealthPlugin();
});

