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

  /// @deprecated Use updateProfileAvatarUrl instead
  /// This method is kept for backward compatibility only.
  /// TODO: Remove after base64 migration completes
  @Deprecated('Use updateProfileAvatarUrl instead. Base64 support will be removed.')
  Future<void> updateProfileAvatarBase64({
    required String userId,
    required String profileId,
    required String photoBase64,
  });

  /// Update profile avatar using Cloudinary URL
  Future<void> updateProfileAvatarUrl({
    required String userId,
    required String profileId,
    required String photoUrl,
  });

  /// Phase 6: Remove legacy base64 avatar field after successful migration
  /// 
  /// This method removes the photoBase64 field from Firestore after
  /// a successful migration to Cloudinary. It is idempotent and safe to call
  /// multiple times.
  Future<void> removeProfileAvatarBase64({
    required String userId,
    required String profileId,
  });
}

