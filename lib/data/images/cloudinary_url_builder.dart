/// Cloudinary URL builder for standardized image delivery
/// 
/// Provides cache-safe URLs with automatic format and quality optimization.
/// All URLs use Cloudinary transformations for optimal delivery.
class CloudinaryUrlBuilder {
  /// Build avatar URL with size transformation and cache-busting
  /// 
  /// [baseUrl] - Base Cloudinary URL from upload
  /// [size] - Desired size (width and height) in pixels (default: 256)
  /// [version] - Optional version for cache-busting (from ImageAsset.version)
  /// 
  /// Returns transformed URL with:
  /// - c_fill: Fill mode for consistent sizing
  /// - w_$size, h_$size: Width and height
  /// - f_auto: Automatic format selection (WebP when supported)
  /// - q_auto: Automatic quality optimization
  /// - Cache-busting parameter (version or timestamp)
  static String avatar({
    required String baseUrl,
    int size = 256,
    int? version,
  }) {
    // Insert transformations after /image/upload/
    final transformed = baseUrl.replaceFirst(
      '/image/upload/',
      '/image/upload/c_fill,w_$size,h_$size,f_auto,q_auto/',
    );

    // Add cache-busting parameter
    if (version != null) {
      return '$transformed?v=$version';
    }

    // Fallback to timestamp if no version available
    return '$transformed?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Build sport icon URL with size transformation
  /// 
  /// [baseUrl] - Base Cloudinary URL from upload
  /// [size] - Desired size (width and height) in pixels (default: 72)
  /// 
  /// Returns transformed URL optimized for list thumbnails
  static String sportIcon({
    required String baseUrl,
    int size = 72,
  }) {
    return baseUrl.replaceFirst(
      '/image/upload/',
      '/image/upload/c_fill,w_$size,h_$size,f_auto,q_auto/',
    );
  }

  /// Build sport cover URL with size transformation
  /// 
  /// [baseUrl] - Base Cloudinary URL from upload
  /// [width] - Desired width in pixels (default: 1080)
  /// [height] - Desired height in pixels (default: 720)
  /// 
  /// Returns transformed URL optimized for cover images
  static String sportCover({
    required String baseUrl,
    int width = 1080,
    int height = 720,
  }) {
    return baseUrl.replaceFirst(
      '/image/upload/',
      '/image/upload/c_fill,w_$width,h_$height,f_auto,q_auto/',
    );
  }
}

