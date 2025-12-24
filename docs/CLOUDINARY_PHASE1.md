# Cloudinary Integration - Phase 1 Implementation

## Goal

Implement a minimal, isolated Cloudinary HTTP client for image uploads. This infrastructure service has no dependencies on UI or business logic, making it easy to test and integrate in later phases.

## Files Created

### `lib/data/cloudinary/cloudinary_client.dart`

A pure infrastructure service that:
- Handles multipart form uploads to Cloudinary API
- Uses unsigned upload preset (no API secret required)
- Provides robust error handling (network, HTTP, JSON parsing)
- Returns typed results with secure URL and metadata
- Supports file overwriting via public_id
- Is testable via dependency injection (http.Client)

## Key Features

### 1. Upload Method
```dart
Future<CloudinaryUploadResult> uploadImage({
  required File file,
  required String folder,
  required String publicId,
  bool overwrite = false,
})
```

### 2. Error Handling
- `CloudinaryUploadException` for all failure cases
- Network timeout (60 seconds)
- HTTP status code validation
- JSON parsing error handling
- File read error handling

### 3. Configuration
- Cloud name: `dimdb3tou` (passed to constructor)
- Upload preset: `ankhoe_uploads` (passed to constructor)
- Base URL: `https://api.cloudinary.com/v1_1/{cloudName}/image/upload`

### 4. Response Parsing
- Handles Cloudinary's JSON response format
- Extracts: `secure_url`, `public_id`, `version`, `format`, `width`, `height`, `bytes`
- Validates required fields

## How to Test

### Manual Testing Steps

1. **Prepare a test image file**
   ```bash
   # Create a small test image (or use an existing one)
   # Place it in a known location, e.g., /tmp/test_image.jpg
   ```

2. **Create a simple test script** (temporary, for Phase 1 validation)
   
   Create `test/cloudinary_client_test_manual.dart`:
   ```dart
   import 'dart:io';
   import 'package:calories_app/data/cloudinary/cloudinary_client.dart';

   void main() async {
     final client = CloudinaryClient(
       cloudName: 'dimdb3tou',
       uploadPreset: 'ankhoe_uploads',
     );

     try {
       // Replace with actual file path
       final testFile = File('/path/to/test_image.jpg');
       
       final result = await client.uploadImage(
         file: testFile,
         folder: 'an_khoe_app/users/avatars',
         publicId: 'user_test_123',
         overwrite: true,
       );

       print('✅ Upload successful!');
       print('Secure URL: ${result.secureUrl}');
       print('Public ID: ${result.publicId}');
       print('Version: ${result.version}');
     } catch (e) {
       print('❌ Upload failed: $e');
     } finally {
       client.dispose();
     }
   }
   ```

3. **Run the test**
   ```bash
   flutter run test/cloudinary_client_test_manual.dart
   ```

4. **Verify in Cloudinary Dashboard**
   - Log into Cloudinary dashboard
   - Navigate to Media Library
   - Check folder: `an_khoe_app/users/avatars`
   - Verify image with public_id: `user_test_123`

### Expected Behavior

**Success Case:**
- Image uploads successfully
- Returns `CloudinaryUploadResult` with `secureUrl`
- Image appears in Cloudinary dashboard
- Console shows: `✅ Upload successful!`

**Error Cases to Test:**
1. **Invalid file path**: Should throw `CloudinaryUploadException` with "File does not exist"
2. **Network timeout**: Should throw `CloudinaryUploadException` with timeout message
3. **Invalid preset**: Should throw `CloudinaryUploadException` with HTTP status code
4. **Invalid JSON response**: Should throw `CloudinaryUploadException` with parsing error

### Unit Testing (Future)

The client is designed for easy unit testing:
- Inject mock `http.Client` via constructor
- Test error scenarios without network calls
- Verify multipart request construction
- Test response parsing logic

## Integration Notes

### Current State
- ✅ Client is isolated and has no dependencies on UI or domain
- ✅ No changes to existing code
- ✅ Can be tested independently

### Next Phase (Phase 2)
- Will create domain abstraction (`ImageStorageRepository`)
- Will wrap this client in repository implementation
- Will add domain models (`ImageAsset`)

## Rollback Notes

If Phase 1 needs to be rolled back:

1. **Delete the file**:
   ```bash
   rm lib/data/cloudinary/cloudinary_client.dart
   ```

2. **No other files were modified**, so no additional cleanup needed

3. **No dependencies added** (uses existing `http` package)

## Configuration Checklist

Before testing, ensure:

- [ ] Cloudinary account has cloud name: `dimdb3tou`
- [ ] Upload preset `ankhoe_uploads` exists and is configured as:
  - [ ] **Unsigned** (no signature required)
  - [ ] **Allowed formats**: jpg, png, gif, webp (or all)
  - [ ] **Max file size**: Reasonable limit (e.g., 10MB)
  - [ ] **Folder**: `an_khoe_app` (or root, if folder is set in request)
- [ ] Preset allows overwrite (if testing overwrite=true)

## Troubleshooting

### Error: "Upload preset not found"
- Verify preset name: `ankhoe_uploads`
- Check preset is unsigned
- Verify preset is active in Cloudinary dashboard

### Error: "Network error"
- Check internet connection
- Verify Cloudinary API is accessible
- Check firewall/proxy settings

### Error: "Invalid JSON response"
- Check Cloudinary dashboard for upload logs
- Verify preset configuration
- Check file format is supported

### Error: "File does not exist"
- Verify file path is correct
- Check file permissions
- Ensure file is accessible from app

## Security Notes

- ✅ No API secret stored in app (uses unsigned preset)
- ✅ Secure URLs returned (HTTPS)
- ✅ File validation (existence check)
- ⚠️ Preset should have upload restrictions configured in dashboard:
  - File size limits
  - Allowed formats
  - Folder restrictions (if needed)

## Next Steps

After Phase 1 is validated:
1. ✅ **Phase 1 Complete** - Infrastructure ready
2. ⏸️ **Wait for approval** before Phase 2
3. **Phase 2** will add domain abstraction layer

