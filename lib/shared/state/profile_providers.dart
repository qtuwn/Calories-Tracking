import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/profile/profile.dart';
import '../../domain/profile/profile_repository.dart';
import '../../domain/profile/profile_cache.dart';
import '../../domain/profile/profile_service.dart';
import '../../data/profile/firestore_profile_repository.dart';
import '../../data/profile/shared_prefs_profile_cache.dart';

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

/// Provider for ProfileCache implementation
final profileCacheProvider = FutureProvider<ProfileCache>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SharedPrefsProfileCache(prefs);
});

/// Provider for ProfileRepository implementation
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return FirestoreProfileRepository();
});

/// Provider for ProfileService
/// 
/// This service coordinates between Firestore (repository) and local cache
/// to provide instant profile loading with background synchronization.
final profileServiceProvider = FutureProvider<ProfileService>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final cache = await ref.watch(profileCacheProvider.future);
  return ProfileService(repository: repository, cache: cache);
});

/// Stream provider for current user profile with hybrid cache
/// 
/// Behavior:
/// - Loads cached profile instantly → UI shows immediately
/// - Syncs with Firestore in background
/// - Updates UI when Firestore data arrives
/// - Works offline using cached data
/// 
/// Usage:
/// ```dart
/// final profileAsync = ref.watch(currentProfileProvider('userId'));
/// profileAsync.when(
///   data: (profile) => Text(profile?.nickname ?? 'No profile'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final currentProfileProvider =
    StreamProvider.autoDispose.family<Profile?, String>((ref, uid) async* {
  final serviceAsync = ref.watch(profileServiceProvider);

  await for (final service in serviceAsync.when(
    data: (service) => Stream.value(service),
    loading: () => const Stream<ProfileService?>.empty(),
    error: (_, __) => const Stream<ProfileService?>.empty(),
  )) {
    if (service == null) continue;

    yield* service.watchProfileWithCache(uid);
  }
});

/// Future provider for loading profile once (cache-first, then Firestore)
/// 
/// Useful for one-time profile loads where you don't need a stream.
final profileLoadOnceProvider =
    FutureProvider.autoDispose.family<Profile?, String>((ref, uid) async {
  final serviceAsync = ref.watch(profileServiceProvider);

  return serviceAsync.when(
    data: (service) => service.loadOnce(uid),
    loading: () => Future.value(null),
    error: (_, __) => Future.value(null),
  );
});

