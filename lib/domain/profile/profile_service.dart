import 'profile.dart';
import 'profile_repository.dart';
import 'profile_cache.dart';

/// Business logic service for Profile operations with hybrid cache support
/// 
/// This service coordinates between the repository (Firestore) and cache (local storage)
/// to provide instant profile loading with background synchronization.
/// 
/// No dependencies on Flutter or Firebase - pure domain logic.
class ProfileService {
  final ProfileRepository _repository;
  final ProfileCache _cache;

  ProfileService({
    required ProfileRepository repository,
    required ProfileCache cache,
  })  : _repository = repository,
        _cache = cache;

  /// Watch profile with hybrid cache + Firestore sync
  /// 
  /// Behavior:
  /// 1. Load cached profile immediately → emit instantly
  /// 2. Subscribe to Firestore stream
  /// 3. On each Firestore update:
  ///    - Emit the new Profile
  ///    - Save it to cache
  /// 4. Continue streaming even when offline
  /// 
  /// This ensures:
  /// - Instant UI load from cache
  /// - Background Firestore sync
  /// - Offline support
  Stream<Profile?> watchProfileWithCache(String uid) async* {
    // Step 1: Load and emit cached profile immediately
    final cachedProfile = await _cache.loadProfile(uid);
    if (cachedProfile != null) {
      yield cachedProfile;
    }

    // Step 2: Subscribe to Firestore stream
    try {
      await for (final profileMap in _repository.watchCurrentUserProfile(uid)) {
        if (profileMap == null) {
          // No profile in Firestore - keep using cache if available
          continue;
        }

        // Convert map to Profile domain entity
        final profile = _mapToProfile(profileMap);

        if (profile != null) {
          // Step 3: Save to cache and emit
          await _cache.saveProfile(uid, profile);
          yield profile;
        }
      }
    } catch (e) {
      // If Firestore stream fails, continue using cached profile
      // The cached profile was already emitted, so UI remains functional
      if (cachedProfile != null) {
        yield cachedProfile;
      }
    }
  }

  /// Load profile once (cache-first, then Firestore fallback)
  /// 
  /// Behavior:
  /// 1. Try to load from cache
  /// 2. If cache miss, load from Firestore
  /// 3. Save to cache
  /// 4. Return Profile or null
  Future<Profile?> loadOnce(String uid) async {
    // Step 1: Try cache first
    final cachedProfile = await _cache.loadProfile(uid);
    if (cachedProfile != null) {
      return cachedProfile;
    }

    // Step 2: Fallback to Firestore
    try {
      final profileMap = await _repository.getCurrentUserProfile(uid);
      if (profileMap == null) {
        return null;
      }

      final profile = _mapToProfile(profileMap);
      if (profile != null) {
        // Step 3: Save to cache
        await _cache.saveProfile(uid, profile);
      }

      return profile;
    } catch (e) {
      // Firestore error - return null (cache already checked)
      return null;
    }
  }

  /// Save profile to both Firestore and cache
  /// 
  /// This ensures consistency between remote and local storage.
  Future<String> saveProfile(String uid, Profile profile) async {
    // Convert Profile to map for repository
    final profileMap = profile.toJson();

    // Save to Firestore
    final profileId = await _repository.saveProfile(uid, profileMap);

    // Save to cache
    await _cache.saveProfile(uid, profile);

    return profileId;
  }

  /// Update profile in both Firestore and cache
  Future<void> updateProfile(String uid, String profileId, Profile profile) async {
    // Convert Profile to map for repository
    final profileMap = profile.toJson();

    // Update in Firestore
    await _repository.updateProfile(uid, profileId, profileMap);

    // Update cache
    await _cache.saveProfile(uid, profile);
  }

  /// Clear cached profile for a user
  Future<void> clearCache(String uid) async {
    await _cache.clearProfile(uid);
  }

  /// Clear all cached profiles
  Future<void> clearAllCache() async {
    await _cache.clearAll();
  }

  /// Convert Firestore map to Profile domain entity
  /// 
  /// This handles the conversion from repository format to domain format.
  Profile? _mapToProfile(Map<String, dynamic> map) {
    try {
      // Remove 'id' field if present (it's metadata, not part of Profile)
      final data = Map<String, dynamic>.from(map);
      data.remove('id');

      return Profile.fromJson(data);
    } catch (e) {
      return null;
    }
  }
}

