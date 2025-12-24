import 'dart:typed_data';
import '../image_asset.dart';
import '../image_storage_failure.dart';
import '../image_storage_repository.dart';

/// Use case for uploading sport/activity cover image
/// 
/// This use case handles the business logic for uploading a sport's cover image:
/// - Maps to correct Cloudinary folder: "sports/covers"
/// - Generates public ID: "sport_{sportId}_cover"
/// 
/// Throws [ImageStorageFailure] on upload failure.
class UploadSportCoverUseCase {
  final ImageStorageRepository _repository;

  UploadSportCoverUseCase(this._repository);

  /// Upload sport cover image
  /// 
  /// [bytes] - Image file bytes
  /// [fileName] - Original file name (e.g., "cover.jpg")
  /// [mimeType] - MIME type (e.g., "image/jpeg", "image/png")
  /// [sportId] - Sport/Activity ID (used to generate public_id: "sport_{sportId}_cover")
  /// 
  /// Returns [ImageAsset] with secure URL and metadata.
  /// 
  /// Throws [ImageStorageFailure] on failure.
  Future<ImageAsset> execute({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String sportId,
  }) async {
    // Validate inputs
    if (sportId.trim().isEmpty) {
      throw ImageUploadServerFailure('Sport ID cannot be empty');
    }

    if (bytes.isEmpty) {
      throw ImageUploadServerFailure('Image bytes cannot be empty');
    }

    // Map to Cloudinary folder and public ID according to conventions
    const folder = 'sports/covers';
    final publicId = 'sport_${sportId}_cover';

    // Upload with public_id (allows identifying/updating sport cover)
    return await _repository.uploadImage(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      folder: folder,
      publicId: publicId,
    );
  }
}

