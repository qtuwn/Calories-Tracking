import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../domain/images/image_storage_failure.dart';
import '../../domain/images/use_cases/upload_user_avatar_use_case.dart';
import '../../domain/profile/profile_repository.dart';
import '../images/cloudinary_url_builder.dart';

/// Service for migrating base64 avatars to Cloudinary URLs
/// 
/// This service handles silent migration of existing base64 avatars to Cloudinary.
/// Migration runs once per profile when a base64 avatar is detected.
class ProfileAvatarMigrationService {
  final ProfileRepository _profileRepository;
  final UploadUserAvatarUseCase _uploadUseCase;

  ProfileAvatarMigrationService({
    required ProfileRepository profileRepository,
    required UploadUserAvatarUseCase uploadUseCase,
  })  : _profileRepository = profileRepository,
        _uploadUseCase = uploadUseCase;

  /// Migrate base64 avatar to Cloudinary URL if needed
  /// 
  /// Phase 6: Finalized migration with cache-safe URLs and clean repository usage.
  /// 
  /// Returns true if migration was attempted (success or failure)
  /// Returns false if migration was not needed (no base64 or already migrated)
  Future<bool> migrateIfNeeded({
    required String userId,
    required String profileId,
    String? photoBase64,
    String? photoUrl,
  }) async {
    // Skip if no base64 data
    if (photoBase64 == null || photoBase64.isEmpty) {
      return false;
    }

    // Skip if already migrated (has URL)
    if (photoUrl != null && photoUrl.isNotEmpty) {
      debugPrint(
        '[ProfileAvatarMigrationService] ℹ️ Profile $profileId already has photoUrl, skipping migration',
      );
      return false;
    }

    debugPrint(
      '[ProfileAvatarMigrationService] 🔵 Starting migration for profile $profileId',
    );

    try {
      // Decode base64 to bytes
      final bytes = base64Decode(photoBase64);
      debugPrint(
        '[ProfileAvatarMigrationService] ✅ Decoded base64 to ${bytes.length} bytes',
      );

      // Upload to Cloudinary
      final imageAsset = await _uploadUseCase.execute(
        bytes: bytes,
        fileName: 'avatar_$profileId.jpg',
        mimeType: 'image/jpeg',
        uid: userId,
      );

      debugPrint(
        '[ProfileAvatarMigrationService] ✅ Uploaded to Cloudinary: ${imageAsset.url}',
      );

      // Build cache-safe URL with transformations
      final cacheSafeUrl = CloudinaryUrlBuilder.avatar(
        baseUrl: imageAsset.url,
        size: 256,
        version: imageAsset.version,
      );

      // Update profile with cache-safe URL
      await _profileRepository.updateProfileAvatarUrl(
        userId: userId,
        profileId: profileId,
        photoUrl: cacheSafeUrl,
      );

      // Remove base64 from storage using repository method
      await _profileRepository.removeProfileAvatarBase64(
        userId: userId,
        profileId: profileId,
      );

      debugPrint(
        '[ProfileAvatarMigrationService] ✅ Migration completed for profile $profileId',
      );

      return true;
    } on ImageStorageFailure catch (e) {
      // Network/server errors - will retry on next profile load
      debugPrint(
        '[ProfileAvatarMigrationService] ⚠️ Migration failed (will retry later): $e',
      );
      return true; // Migration was attempted
    } catch (e, stackTrace) {
      // Other errors (invalid base64, etc.) - log but don't retry
      debugPrint(
        '[ProfileAvatarMigrationService] 🔥 Migration error for profile $profileId: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      return true; // Migration was attempted
    }
  }
}

