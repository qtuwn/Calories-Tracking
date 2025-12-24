import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../domain/images/image_asset.dart';
import '../../domain/images/image_storage_failure.dart';
import '../../domain/images/image_storage_repository.dart';
import '../cloudinary/cloudinary_client.dart';

/// Cloudinary implementation of ImageStorageRepository
/// 
/// This repository wraps the CloudinaryClient and converts infrastructure
/// results into domain models (ImageAsset).
/// 
/// Handles error translation from infrastructure exceptions to domain failures.
class CloudinaryImageStorageRepository implements ImageStorageRepository {
  final CloudinaryClient _client;

  /// Create a CloudinaryImageStorageRepository
  /// 
  /// [client] - The CloudinaryClient instance to use for uploads
  CloudinaryImageStorageRepository({
    required CloudinaryClient client,
  }) : _client = client;

  /// Create with default Cloudinary configuration
  /// 
  /// Uses cloudName "dimdb3tou" and uploadPreset "ankhoe_uploads"
  factory CloudinaryImageStorageRepository.createDefault() {
    return CloudinaryImageStorageRepository(
      client: CloudinaryClient(
        cloudName: 'dimdb3tou',
        uploadPreset: 'ankhoe_uploads',
      ),
    );
  }

  @override
  Future<ImageAsset> uploadImage({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String folder,
    String? publicId,
  }) async {
    debugPrint(
      '[CloudinaryImageStorageRepository] 🔵 Uploading image: folder=$folder, publicId=${publicId ?? 'auto-generated'}',
    );

    try {
      // Delegate to infrastructure client (bytes-based upload)
      // Note: publicId is optional - if null, Cloudinary auto-generates an unguessable ID
      final result = await _client.uploadImageBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        folder: folder,
        publicId: publicId,
      );

      // Convert infrastructure result to domain model
      final imageAsset = ImageAsset(
        url: result.secureUrl,
        publicId: result.publicId,
        version: result.version,
        format: result.format,
        width: result.width,
        height: result.height,
        bytes: result.bytes,
      );

      debugPrint(
        '[CloudinaryImageStorageRepository] ✅ Upload successful: ${imageAsset.url}',
      );

      return imageAsset;
    } on CloudinaryUploadException catch (e) {
      debugPrint('[CloudinaryImageStorageRepository] 🔥 Cloudinary upload failed: $e');
      
      // Translate infrastructure exception to domain failure
      if (e.statusCode != null) {
        // Server error (HTTP 4xx, 5xx)
        throw ImageUploadServerFailure(
          'Image upload failed: ${e.message}',
          statusCode: e.statusCode,
          serverMessage: e.responseBody,
        );
      } else if (e.message.contains('timeout') || 
                 e.message.contains('Network error') ||
                 e.message.contains('connection')) {
        // Network error
        throw ImageUploadNetworkFailure('Network error during upload: ${e.message}');
      } else if (e.message.contains('parse') || 
                 e.message.contains('Invalid JSON') ||
                 e.message.contains('invalid response')) {
        // Invalid response
        throw ImageUploadInvalidResponseFailure('Invalid response from server: ${e.message}');
      } else {
        // Generic server failure
        throw ImageUploadServerFailure('Image upload failed: ${e.message}');
      }
    } catch (e, stackTrace) {
      if (e is ImageStorageFailure) {
        rethrow;
      }
      
      debugPrint('[CloudinaryImageStorageRepository] 🔥 Unexpected error: $e');
      debugPrint('[CloudinaryImageStorageRepository] Stack trace: $stackTrace');
      throw ImageUploadNetworkFailure('Unexpected error during upload: $e');
    }
  }
}

