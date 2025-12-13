import 'profile.dart';

/// Abstract cache interface for Profile storage
/// 
/// This is a pure domain interface with no dependencies on Flutter or Firebase.
/// Implementations should be in the data layer (e.g., SharedPreferences, Hive).
abstract class ProfileCache {
  /// Load cached profile for a user
  /// Returns null if no cached profile exists
  Future<Profile?> loadProfile(String uid);

  /// Save profile to cache
  Future<void> saveProfile(String uid, Profile profile);

  /// Clear cached profile for a user
  Future<void> clearProfile(String uid);

  /// Clear all cached profiles
  Future<void> clearAll();
}

