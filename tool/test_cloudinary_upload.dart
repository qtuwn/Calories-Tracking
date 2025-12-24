import 'dart:io';
import 'dart:typed_data';
import 'package:calories_app/data/images/cloudinary_image_storage_repository.dart';

/// Manual test script for Cloudinary image upload
/// 
/// Usage:
///   `dart run tool/test_cloudinary_upload.dart <path_to_image_file>`
/// 
/// Example:
///   dart run tool/test_cloudinary_upload.dart /tmp/test_image.jpg
void main(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Error: Please provide an image file path');
    print('Usage: dart run tool/test_cloudinary_upload.dart <path_to_image_file>');
    exit(1);
  }

  final imagePath = args[0];
  final file = File(imagePath);

  // Check if file exists
  if (!await file.exists()) {
    print('❌ Error: File does not exist: $imagePath');
    exit(1);
  }

  print('📁 Reading image file: $imagePath');

  // Read file bytes
  Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
    print('✅ Read ${bytes.length} bytes from file');
  } catch (e) {
    print('❌ Error reading file: $e');
    exit(1);
  }

  // Determine MIME type from extension
  final extension = imagePath.split('.').last.toLowerCase();
  final mimeType = _getMimeType(extension);
  final fileName = file.path.split('/').last;

  print('📋 File info:');
  print('   Name: $fileName');
  print('   MIME Type: $mimeType');
  print('   Size: ${bytes.length} bytes');

  // Create repository
  final repository = CloudinaryImageStorageRepository.createDefault();
  print('\n🔵 Starting Cloudinary upload...');
  print('   Folder: users/avatars');
  print('   Public ID: user_test_123 (optional - can be null for auto-generation)');

  try {
    // Upload image
    final imageAsset = await repository.uploadImage(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      folder: 'users/avatars',
      publicId: 'user_test_123', // Optional - can be null to let Cloudinary auto-generate
    );

    print('\n✅ Upload successful!');
    print('\n📊 Result:');
    print('   URL: ${imageAsset.url}');
    print('   Public ID: ${imageAsset.publicId}');
    if (imageAsset.version != null) {
      print('   Version: ${imageAsset.version}');
    }
    if (imageAsset.format != null) {
      print('   Format: ${imageAsset.format}');
    }
    if (imageAsset.width != null && imageAsset.height != null) {
      print('   Dimensions: ${imageAsset.width}x${imageAsset.height}');
    }
    if (imageAsset.bytes != null) {
      print('   Size: ${imageAsset.bytes} bytes');
    }

    print('\n🔗 You can access the image at:');
    print('   ${imageAsset.url}');
  } catch (e) {
    print('\n❌ Upload failed: $e');
    exit(1);
  }
}

/// Get MIME type from file extension
String _getMimeType(String extension) {
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

