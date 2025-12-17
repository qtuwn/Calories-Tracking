import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/profile/profile.dart';
import '../../domain/profile/profile_repository.dart';
import '../../domain/profile/profile_cache.dart';
import '../../domain/profile/profile_service.dart';
import '../../data/profile/firestore_profile_repository.dart';
import '../../data/profile/shared_prefs_profile_cache.dart';

/// FutureProvider for SharedPreferences instance
/// 
/// IMPORTANT: This provider is overridden in main.dart with a preloaded instance
/// before runApp() to ensure it's available synchronously during routing.
/// 
/// Override is required because IntroGate -> ProfileGate -> onboardingCacheProvider
/// needs SharedPreferences immediately during initial routing (before first frame).
/// 
/// The override in main.dart looks like:
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// ProviderScope(
///   overrides: [
///     sharedPreferencesFutureProvider.overrideWithValue(AsyncValue.data(prefs)),
///   ],
///   ...
/// )
/// ```
final sharedPreferencesFutureProvider = FutureProvider<SharedPreferences>((ref) async {
  // This implementation should never be called in production because main.dart
  // overrides this provider with a preloaded instance.
  // However, we provide a fallback for tests or edge cases.
  return await SharedPreferences.getInstance();
});

/// Synchronous provider that unwraps the FutureProvider
/// 
/// This maintains backward compatibility with existing code that expects synchronous access.
/// Safe to use because main.dart ensures the FutureProvider is overridden with preloaded data.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  final asyncValue = ref.watch(sharedPreferencesFutureProvider);
  return asyncValue.when(
    data: (prefs) => prefs,
    loading: () => throw StateError(
      'SharedPreferences not yet loaded. This should not happen because main.dart '
      'preloads SharedPreferences and overrides sharedPreferencesFutureProvider before runApp().'
    ),
    error: (error, stack) => throw StateError(
      'Failed to load SharedPreferences: $error'
    ),
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

