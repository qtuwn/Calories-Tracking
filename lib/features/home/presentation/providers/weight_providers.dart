import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/data/firebase/weight_repository.dart';
import 'package:calories_app/features/home/domain/weight_entry.dart';
import 'package:calories_app/shared/state/auth_providers.dart';

/// Provider for WeightRepository
final weightRepositoryProvider = Provider<WeightRepository>((ref) {
  return WeightRepository();
});

/// Helper provider to get current user ID from auth state
/// 
/// Returns null if user is not signed in.
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user?.uid,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Stream provider for the latest weight entry
/// 
/// Returns null if no weight entries exist yet.
/// Automatically updates when new weights are added.
final latestWeightProvider = StreamProvider<WeightEntry?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  
  if (uid == null) {
    debugPrint('[LatestWeightProvider] ⚠️ No user signed in, returning empty stream');
    return Stream.value(null);
  }

  final repository = ref.watch(weightRepositoryProvider);
  debugPrint('[LatestWeightProvider] 🔵 Watching latest weight for uid=$uid');
  
  return repository.watchLatestWeight(uid: uid);
});

/// Stream provider for recent weight entries (last N days)
/// 
/// Defaults to 7 days. Returns empty list if no entries exist.
/// Automatically updates when new weights are added.
final recentWeightsProvider = StreamProvider.family<List<WeightEntry>, int>((ref, days) {
  final uid = ref.watch(currentUserIdProvider);
  
  if (uid == null) {
    debugPrint('[RecentWeightsProvider] ⚠️ No user signed in, returning empty stream');
    return Stream.value([]);
  }

  final repository = ref.watch(weightRepositoryProvider);
  debugPrint('[RecentWeightsProvider] 🔵 Watching recent weights for uid=$uid, days=$days');
  
  return repository.watchRecentWeights(uid: uid, days: days);
});

/// Default provider for recent weights (last 7 days)
/// 
/// Convenience provider that uses 7 days as the default period.
final recentWeights7DaysProvider = recentWeightsProvider(7);

/// Controller for weight write operations
/// 
/// Handles adding/updating weight entries.
class WeightController extends Notifier<void> {
  WeightRepository get _repository => ref.read(weightRepositoryProvider);

  @override
  void build() {
    // No state needed, this is a service-like notifier
  }

  /// Update today's weight entry
  /// 
  /// If an entry for today already exists, it will be updated.
  /// Otherwise, a new entry will be created.
  /// 
  /// Also syncs with profile.currentWeightKg.
  Future<void> updateTodayWeight(double weightKg) async {
    final uid = ref.read(currentUserIdProvider);
    
    if (uid == null) {
      throw Exception('Bạn cần đăng nhập để cập nhật cân nặng');
    }

    if (weightKg <= 0 || weightKg > 500) {
      throw Exception('Cân nặng phải từ 0 đến 500 kg');
    }

    try {
      await _repository.addOrUpdateTodayWeight(
        uid: uid,
        weightKg: weightKg,
      );

      debugPrint('[WeightController] ✅ Successfully updated weight to $weightKg kg');
    } catch (e, stackTrace) {
      debugPrint('[WeightController] 🔥 Error updating weight: $e');
      debugPrint('[WeightController] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

/// Provider for WeightController
final weightControllerProvider = NotifierProvider<WeightController, void>(
  WeightController.new,
);

