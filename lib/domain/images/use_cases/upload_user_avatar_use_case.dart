import 'dart:typed_data';
import '../image_asset.dart';
import '../image_storage_failure.dart';
import '../image_storage_repository.dart';

/// Use case for uploading user avatar image
/// 
/// This use case handles the business logic for uploading a user's avatar:
/// - Maps to correct Cloudinary folder: "users/avatars"
/// - Does NOT set public_id (lets Cloudinary auto-generate unique ID for each upload)
/// - Each upload returns a new unique URL to prevent caching issues
/// 
/// Throws [ImageStorageFailure] on upload failure.
class UploadUserAvatarUseCase {
  final ImageStorageRepository _repository;

  UploadUserAvatarUseCase(this._repository);

  /// Upload user avatar image
  /// 
  /// [bytes] - Image file bytes
  /// [fileName] - Original file name (e.g., "avatar.jpg")
  /// [mimeType] - MIME type (e.g., "image/jpeg", "image/png")
  /// [uid] - User ID (for validation only, not used for public_id)
  /// 
  /// Returns [ImageAsset] with secure URL and metadata.
  /// Each upload returns a NEW unique URL (Cloudinary auto-generates public_id).
  /// 
  /// Throws [ImageStorageFailure] on failure.
  Future<ImageAsset> execute({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String uid,
  }) async {
    // Validate inputs
    if (uid.trim().isEmpty) {
      throw ImageUploadServerFailure('User ID cannot be empty');
    }

    if (bytes.isEmpty) {
      throw ImageUploadServerFailure('Image bytes cannot be empty');
    }

    // Map to Cloudinary folder
    // Do NOT set public_id - let Cloudinary auto-generate unique ID for each upload
    const folder = 'users/avatars';

    // Upload without public_id (Cloudinary auto-generates unguessable ID)
    // This ensures each upload gets a NEW unique URL, preventing cache issues
    return await _repository.uploadImage(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      folder: folder,
      publicId: null, // Let Cloudinary auto-generate unique ID
    );
  }
}

