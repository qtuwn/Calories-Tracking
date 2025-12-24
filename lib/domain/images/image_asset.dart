/// Domain model representing an uploaded image asset
/// 
/// This is a pure domain entity with no dependencies on Flutter or external services.
/// It represents the result of an image upload operation.
class ImageAsset {
  /// The secure HTTPS URL to access the image
  final String url;

  /// The public ID of the image in Cloudinary
  final String publicId;

  /// Optional version number (for cache invalidation)
  final int? version;

  /// Optional image format (e.g., "jpg", "png", "webp")
  final String? format;

  /// Optional image width in pixels
  final int? width;

  /// Optional image height in pixels
  final int? height;

  /// Optional file size in bytes
  final int? bytes;

  const ImageAsset({
    required this.url,
    required this.publicId,
    this.version,
    this.format,
    this.width,
    this.height,
    this.bytes,
  });

  /// Create a copy with updated fields
  ImageAsset copyWith({
    String? url,
    String? publicId,
    int? version,
    String? format,
    int? width,
    int? height,
    int? bytes,
  }) {
    return ImageAsset(
      url: url ?? this.url,
      publicId: publicId ?? this.publicId,
      version: version ?? this.version,
      format: format ?? this.format,
      width: width ?? this.width,
      height: height ?? this.height,
      bytes: bytes ?? this.bytes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageAsset &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          publicId == other.publicId;

  @override
  int get hashCode => url.hashCode ^ publicId.hashCode;

  @override
  String toString() => 'ImageAsset(url: $url, publicId: $publicId)';
}

