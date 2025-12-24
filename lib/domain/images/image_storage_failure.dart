/// Base class for image storage operation failures
/// 
/// This is a pure domain failure type with no external dependencies.
/// Used to represent various failure scenarios in image upload operations.
abstract class ImageStorageFailure implements Exception {
  final String message;

  const ImageStorageFailure(this.message);

  @override
  String toString() => message;
}

/// Network-related failure during image upload
/// 
/// Examples: connection timeout, no internet, DNS resolution failure
class ImageUploadNetworkFailure extends ImageStorageFailure {
  const ImageUploadNetworkFailure(super.message);
}

/// Server-side failure during image upload
/// 
/// Represents HTTP errors (4xx, 5xx) or Cloudinary API errors
class ImageUploadServerFailure extends ImageStorageFailure {
  final int? statusCode;
  final String? serverMessage;

  const ImageUploadServerFailure(
    super.message, {
    this.statusCode,
    this.serverMessage,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return '$message (status: $statusCode${serverMessage != null ? ', server: $serverMessage' : ''})';
    }
    return message;
  }
}

/// Invalid or malformed response from image storage service
/// 
/// Examples: invalid JSON, missing required fields, unexpected format
class ImageUploadInvalidResponseFailure extends ImageStorageFailure {
  const ImageUploadInvalidResponseFailure(super.message);
}

