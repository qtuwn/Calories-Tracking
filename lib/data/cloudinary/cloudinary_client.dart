import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Result of a successful Cloudinary image upload
class CloudinaryUploadResult {
  final String secureUrl;
  final String publicId;
  final int? version;
  final String? format;
  final int? width;
  final int? height;
  final int? bytes;

  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    this.version,
    this.format,
    this.width,
    this.height,
    this.bytes,
  });

  @override
  String toString() => 'CloudinaryUploadResult(secureUrl: $secureUrl, publicId: $publicId)';
}

/// Exception thrown when Cloudinary upload fails
class CloudinaryUploadException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  const CloudinaryUploadException(
    this.message, {
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() => 'CloudinaryUploadException: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// Low-level HTTP client for Cloudinary image uploads
/// 
/// This is a pure infrastructure service with no business logic.
/// It handles multipart form uploads to Cloudinary's upload API.
/// 
/// Uses unsigned upload preset for security (no API secret required).
class CloudinaryClient {
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1';
  final String cloudName;
  final String uploadPreset;
  final http.Client _httpClient;

  /// Create a CloudinaryClient
  /// 
  /// [cloudName] - Your Cloudinary cloud name (e.g., "dimdb3tou")
  /// [uploadPreset] - Unsigned upload preset name (e.g., "ankhoe_uploads")
  /// [httpClient] - Optional HTTP client for dependency injection (useful for testing)
  CloudinaryClient({
    required this.cloudName,
    required this.uploadPreset,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Upload an image file to Cloudinary (unsigned upload)
  /// 
  /// [file] - The image file to upload
  /// [folder] - Optional Cloudinary folder path (e.g., "users/avatars", "sports/icons")
  /// [publicId] - Optional Public ID for the uploaded image. If not provided, Cloudinary auto-generates an unguessable ID.
  /// 
  /// Returns [CloudinaryUploadResult] with secure URL and metadata.
  /// 
  /// Throws [CloudinaryUploadException] on failure:
  /// - Network errors
  /// - Non-200 HTTP responses
  /// - Invalid JSON responses
  /// - File read errors
  Future<CloudinaryUploadResult> uploadImage({
    required File file,
    String? folder,
    String? publicId,
  }) async {
    debugPrint('[CloudinaryClient] 🔵 Starting file upload: folder=$folder, publicId=$publicId');

    // Validate file exists
    if (!await file.exists()) {
      throw CloudinaryUploadException('File does not exist: ${file.path}');
    }

    // Read file bytes
    List<int> fileBytes;
    try {
      fileBytes = await file.readAsBytes();
      debugPrint('[CloudinaryClient] ✅ Read ${fileBytes.length} bytes from file');
    } catch (e, stackTrace) {
      debugPrint('[CloudinaryClient] 🔥 Error reading file: $e');
      debugPrint('[CloudinaryClient] Stack trace: $stackTrace');
      throw CloudinaryUploadException('Failed to read file: $e');
    }

    // Determine MIME type from file extension
    final mimeType = _getMimeType(file.path);
    final fileName = file.path.split('/').last;

    // Delegate to bytes-based upload
    return uploadImageBytes(
      bytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
      folder: folder,
      publicId: publicId,
    );
  }

  /// Upload image bytes to Cloudinary (unsigned upload)
  /// 
  /// [bytes] - The image file bytes (`Uint8List` or `List<int>`)
  /// [fileName] - Original file name (e.g., "avatar.jpg", "icon.png")
  /// [mimeType] - MIME type of the image (e.g., "image/jpeg", "image/png")
  /// [folder] - Optional Cloudinary folder path (e.g., "users/avatars", "sports/icons")
  /// [publicId] - Optional Public ID for the uploaded image. If not provided, Cloudinary auto-generates an unguessable ID.
  /// 
  /// Returns [CloudinaryUploadResult] with secure URL and metadata.
  /// 
  /// Throws [CloudinaryUploadException] on failure:
  /// - Network errors
  /// - Non-200 HTTP responses
  /// - Invalid JSON responses
  Future<CloudinaryUploadResult> uploadImageBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? folder,
    String? publicId,
  }) async {
    debugPrint('[CloudinaryClient] 🔵 Starting unsigned upload: upload_preset=$uploadPreset');
    debugPrint('[CloudinaryClient] File: $fileName, MIME: $mimeType, Size: ${bytes.length} bytes');
    if (folder != null) debugPrint('[CloudinaryClient] Folder: $folder');
    if (publicId != null) debugPrint('[CloudinaryClient] Public ID: $publicId');

    // Build upload URL
    final uploadUrl = Uri.parse('$_baseUrl/$cloudName/image/upload');
    debugPrint('[CloudinaryClient] 📤 Request endpoint: $uploadUrl');

    // Create multipart request
    final request = http.MultipartRequest('POST', uploadUrl);

    // Add file bytes with contentType set during creation
    final fileField = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
      contentType: MediaType.parse(mimeType),
    );
    request.files.add(fileField);

    // Add required unsigned upload parameters
    request.fields['upload_preset'] = uploadPreset;
    
    // Add optional folder if provided
    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }
    
    // Add optional public_id if provided (otherwise Cloudinary auto-generates)
    if (publicId != null && publicId.isNotEmpty) {
      request.fields['public_id'] = publicId;
    }
    
    // Log request fields (excluding sensitive data)
    debugPrint('[CloudinaryClient] 📋 Request fields: upload_preset=${request.fields['upload_preset']}, folder=${request.fields['folder'] ?? 'none'}, public_id=${request.fields['public_id'] ?? 'auto-generated'}');

    try {
      debugPrint('[CloudinaryClient] 📤 Sending multipart request to Cloudinary...');

      // Send request with timeout
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw CloudinaryUploadException('Upload request timed out after 60 seconds');
            },
          );

      // Read response
      final response = await http.Response.fromStream(streamedResponse);
      final statusCode = response.statusCode;
      final responseSnippet = response.body.length > 200 
          ? '${response.body.substring(0, 200)}...' 
          : response.body;
      
      debugPrint('[CloudinaryClient] 📥 Response status: $statusCode');
      debugPrint('[CloudinaryClient] 📥 Response snippet: $responseSnippet');

      // Check status code
      if (statusCode != 200) {
        debugPrint('[CloudinaryClient] ❌ Upload failed: status=$statusCode');
        throw CloudinaryUploadException(
          'Cloudinary upload failed with status $statusCode',
          statusCode: statusCode,
          responseBody: response.body,
        );
      }

      // Parse JSON response
      try {
        final responseData = _parseJsonResponse(response.body);
        final result = _createUploadResult(responseData);

        debugPrint('[CloudinaryClient] ✅ Upload successful: ${result.secureUrl}');
        return result;
      } catch (e, stackTrace) {
        debugPrint('[CloudinaryClient] 🔥 Error parsing response: $e');
        debugPrint('[CloudinaryClient] Response body: ${response.body}');
        debugPrint('[CloudinaryClient] Stack trace: $stackTrace');
        throw CloudinaryUploadException(
          'Failed to parse Cloudinary response: $e',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
    } catch (e, stackTrace) {
      if (e is CloudinaryUploadException) {
        rethrow;
      }

      debugPrint('[CloudinaryClient] 🔥 Network error during upload: $e');
      debugPrint('[CloudinaryClient] Stack trace: $stackTrace');
      throw CloudinaryUploadException('Network error: $e');
    }
  }

  /// Parse JSON response from Cloudinary
  Map<String, dynamic> _parseJsonResponse(String body) {
    try {
      // Cloudinary may return JSON wrapped in parentheses: ({"secure_url": ...})
      String cleanedBody = body.trim();
      if (cleanedBody.startsWith('(') && cleanedBody.endsWith(')')) {
        cleanedBody = cleanedBody.substring(1, cleanedBody.length - 1);
      }

      // Parse as JSON
      final decoded = jsonDecode(cleanedBody) as Map<String, dynamic>;
      return decoded;
    } catch (e) {
      throw Exception('Invalid JSON response: $e');
    }
  }

  /// Create CloudinaryUploadResult from parsed response
  CloudinaryUploadResult _createUploadResult(Map<String, dynamic> data) {
    final secureUrl = data['secure_url'] as String?;
    final publicId = data['public_id'] as String?;
    final version = data['version'] as int?;
    final format = data['format'] as String?;
    final width = data['width'] as int?;
    final height = data['height'] as int?;
    final bytes = data['bytes'] as int?;

    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('Missing secure_url in Cloudinary response');
    }
    if (publicId == null || publicId.isEmpty) {
      throw Exception('Missing public_id in Cloudinary response');
    }

    return CloudinaryUploadResult(
      secureUrl: secureUrl,
      publicId: publicId,
      version: version,
      format: format,
      width: width,
      height: height,
      bytes: bytes,
    );
  }

  /// Get MIME type from file extension
  String _getMimeType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // Default fallback
    }
  }

  /// Dispose resources (closes HTTP client if custom)
  void dispose() {
    _httpClient.close();
  }
}

