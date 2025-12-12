import 'profile.dart';

/// Abstract repository interface for Profile operations
/// 
/// This is a pure domain interface with no dependencies on Flutter or Firebase.
/// Implementations should be in the data layer.
abstract class ProfileRepository {
  /// Check if user has an existing profile
  Future<bool> hasExistingProfile(String userId);

  /// Get user profiles
  Future<List<Map<String, dynamic>>> getUserProfiles(String userId);

  /// Get current user profile (the one with isCurrent = true)
  Future<Map<String, dynamic>?> getCurrentUserProfile(String userId);

  /// Watch current user profile stream
  Stream<Map<String, dynamic>?> watchCurrentUserProfile(String userId);

  /// Watch current user profile as Profile domain entity
  /// Returns a stream of Profile or null
  Stream<Profile?> watchProfile(String userId);

  /// Save a new profile
  /// Returns the created profile ID
  Future<String> saveProfile(String userId, Map<String, dynamic> profileData);

  /// Update an existing profile
  Future<void> updateProfile(
    String userId,
    String profileId,
    Map<String, dynamic> profileData,
  );

  /// Set a profile as current (and unset others)
  Future<void> setCurrentProfile(String userId, String profileId);

  /// Delete a profile
  Future<void> deleteProfile(String userId, String profileId);

  /// Get current profile ID (the one with isCurrent = true)
  Future<String?> getCurrentProfileId(String userId);

  /// Update profile avatar using base64 string
  Future<void> updateProfileAvatarBase64({
    required String userId,
    required String profileId,
    required String photoBase64,
  });
}

