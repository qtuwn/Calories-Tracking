import 'dart:typed_data';
import 'image_asset.dart';
import 'image_storage_failure.dart';

/// Abstract repository interface for image storage operations
/// 
/// This is a pure domain interface with no dependencies on Flutter or external services.
/// Implementations should be in the data layer.
/// 
/// This abstraction allows the domain layer to remain independent of the specific
/// image storage provider (Cloudinary, Firebase Storage, etc.).
abstract class ImageStorageRepository {
  /// Upload an image to cloud storage
  /// 
  /// [bytes] - The image file bytes (Uint8List)
  /// [fileName] - Original file name (e.g., "avatar.jpg", "icon.png")
  /// [mimeType] - MIME type of the image (e.g., "image/jpeg", "image/png")
  /// [folder] - Storage folder path (e.g., "users/avatars", "sports/icons")
  /// [publicId] - Optional unique identifier for the image. If not provided, storage provider auto-generates an unguessable ID.
  /// 
  /// Returns [ImageAsset] with the secure URL and metadata.
  /// 
  /// Throws [ImageStorageFailure] on failure:
  /// - [ImageUploadNetworkFailure] for network errors
  /// - [ImageUploadServerFailure] for server/API errors
  /// - [ImageUploadInvalidResponseFailure] for invalid responses
  Future<ImageAsset> uploadImage({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String folder,
    String? publicId,
  });
}

