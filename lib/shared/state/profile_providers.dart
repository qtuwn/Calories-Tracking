import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/profile/profile.dart';
import '../../domain/profile/profile_repository.dart';
import '../../domain/profile/profile_cache.dart';
import '../../domain/profile/profile_service.dart';
import '../../data/profile/firestore_profile_repository.dart';
import '../../data/profile/shared_prefs_profile_cache.dart';

/// Provider for SharedPreferences instance
/// 
/// IMPORTANT: This provider should be overridden in main.dart with a preloaded instance.
/// If not overridden, it will attempt to get SharedPreferences, but this should never happen
/// in production since main.dart preloads it before runApp().
/// 
/// The override ensures SharedPreferences is always available synchronously,
/// eliminating the need for Dummy caches and preventing race conditions.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  // This should never be called if main.dart properly overrides it
  // But we provide a fallback for safety
  throw StateError(
    'sharedPreferencesProvider must be overridden in main.dart with a preloaded instance. '
    'Ensure SharedPreferences.getInstance() is called before runApp() and passed via ProviderScope.overrides.',
  );
});

/// Provider for ProfileCache implementation
/// 
/// SharedPreferences is guaranteed to be available since it's preloaded in main.dart
/// and provided via ProviderScope.overrides.
final profileCacheProvider = Provider<ProfileCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
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
/// 
/// Cache is guaranteed to be available since SharedPreferences is preloaded in main.dart.
final profileServiceProvider = Provider<ProfileService>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final cache = ref.watch(profileCacheProvider);
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
    StreamProvider.autoDispose.family<Profile?, String>((ref, uid) {
  final service = ref.watch(profileServiceProvider);
  return service.watchProfileWithCache(uid);
});

/// Future provider for loading profile once (cache-first, then Firestore)
/// 
/// Useful for one-time profile loads where you don't need a stream.
final profileLoadOnceProvider =
    FutureProvider.autoDispose.family<Profile?, String>((ref, uid) {
  final service = ref.watch(profileServiceProvider);
  return service.loadOnce(uid);
});

