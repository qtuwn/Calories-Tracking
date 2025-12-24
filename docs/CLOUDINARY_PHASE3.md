# Cloudinary Integration - Phase 3 Implementation

## Goal

Implement use cases for specific image upload scenarios following Clean Architecture principles. Each use case encapsulates business logic for folder/publicId mapping and handles validation.

## Files Created

### Domain Layer (Use Cases)

#### `lib/domain/images/use_cases/upload_user_avatar_use_case.dart`
- **Purpose**: Upload user avatar image
- **Folder Mapping**: `users/avatars`
- **Public ID**: `user_{uid}`
- **Overwrite**: `true` (enabled)
- **Validation**: Checks uid and bytes are not empty

#### `lib/domain/images/use_cases/upload_sport_icon_use_case.dart`
- **Purpose**: Upload sport/activity icon image
- **Folder Mapping**: `sports/icons`
- **Public ID**: `sport_{sportId}_icon`
- **Overwrite**: `true` (enabled)
- **Validation**: Checks sportId and bytes are not empty

#### `lib/domain/images/use_cases/upload_sport_cover_use_case.dart`
- **Purpose**: Upload sport/activity cover image
- **Folder Mapping**: `sports/covers`
- **Public ID**: `sport_{sportId}_cover`
- **Overwrite**: `true` (enabled)
- **Validation**: Checks sportId and bytes are not empty

## Architecture

### Use Case Pattern

Each use case:
1. **Takes bytes** (not File) - maintains Clean Architecture (no `dart:io` dependency)
2. **Validates inputs** - business rule enforcement
3. **Maps folder/publicId** - according to conventions
4. **Calls repository** - delegates to `ImageStorageRepository`
5. **Returns domain model** - `ImageAsset`
6. **Throws domain failures** - `ImageStorageFailure` types

### Folder & Public ID Conventions

| Use Case | Folder | Public ID Pattern | Example |
|----------|--------|-------------------|---------|
| UploadUserAvatar | `users/avatars` | `user_{uid}` | `user_abc123` |
| UploadSportIcon | `sports/icons` | `sport_{sportId}_icon` | `sport_xyz789_icon` |
| UploadSportCover | `sports/covers` | `sport_{sportId}_cover` | `sport_xyz789_cover` |

All use cases enable `overwrite: true` to allow updating existing images.

## Code Structure

### Use Case Example

```dart
class UploadUserAvatarUseCase {
  final ImageStorageRepository _repository;

  UploadUserAvatarUseCase(this._repository);

  Future<ImageAsset> execute({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String uid,
  }) async {
    // Validate
    if (uid.trim().isEmpty) {
      throw ImageUploadServerFailure('User ID cannot be empty');
    }

    // Map folder and publicId
    const folder = 'users/avatars';
    final publicId = 'user_$uid';

    // Delegate to repository
    return await _repository.uploadImage(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      folder: folder,
      publicId: publicId,
      overwrite: true,
    );
  }
}
```

## How to Use

### Example: Upload User Avatar

```dart
// In presentation layer (reads File to bytes)
final file = File('/path/to/avatar.jpg');
final bytes = await file.readAsBytes();
final fileName = file.path.split('/').last;
final mimeType = 'image/jpeg'; // Determine from extension

// Create use case with repository
final repository = CloudinaryImageStorageRepository.createDefault();
final useCase = UploadUserAvatarUseCase(repository);

// Execute use case
try {
  final imageAsset = await useCase.execute(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
    uid: 'user123',
  );
  
  print('Avatar uploaded: ${imageAsset.url}');
} on ImageStorageFailure catch (e) {
  print('Upload failed: $e');
}
```

### Example: Upload Sport Icon

```dart
final repository = CloudinaryImageStorageRepository.createDefault();
final useCase = UploadSportIconUseCase(repository);

final imageAsset = await useCase.execute(
  bytes: bytes,
  fileName: 'icon.png',
  mimeType: 'image/png',
  sportId: 'sport456',
);

// Result: uploaded to sports/icons folder with public_id: sport_sport456_icon
```

## Testing

### Manual Test Script

Update `tool/test_cloudinary_upload.dart` to test use cases:

```dart
// Test UploadUserAvatarUseCase
final repository = CloudinaryImageStorageRepository.createDefault();
final useCase = UploadUserAvatarUseCase(repository);

final imageAsset = await useCase.execute(
  bytes: bytes,
  fileName: fileName,
  mimeType: mimeType,
  uid: 'test_user_123',
);
```

### Unit Testing (Future)

Use cases can be easily unit tested with mock repositories:

```dart
class MockImageStorageRepository implements ImageStorageRepository {
  @override
  Future<ImageAsset> uploadImage(...) async {
    return ImageAsset(url: 'https://...', publicId: 'test');
  }
}

test('UploadUserAvatarUseCase maps folder and publicId correctly', () async {
  final mockRepo = MockImageStorageRepository();
  final useCase = UploadUserAvatarUseCase(mockRepo);
  
  // Test that use case calls repository with correct folder/publicId
  // ...
});
```

## Integration Notes

### Current State
- ✅ Use cases are pure domain (no Flutter/Firebase dependencies)
- ✅ Use cases accept bytes (not File) - maintains Clean Architecture
- ✅ Folder/publicId mapping follows conventions
- ✅ Overwrite enabled for all use cases
- ✅ Input validation included

### Next Phase (Phase 4)
- Will wire use cases into presentation layer
- Will integrate with existing profile/avatar UI
- Will handle File → bytes conversion in presentation layer
- Will persist URLs in Firestore

### Dependency Flow
```
Presentation Layer
    ↓ (reads File → bytes)
Use Cases (UploadUserAvatarUseCase, etc.)
    ↓ (calls)
Domain Repository Interface (ImageStorageRepository)
    ↑ (implemented by)
Data Layer (CloudinaryImageStorageRepository)
    ↓ (uses)
Infrastructure (CloudinaryClient)
```

## Rollback Notes

If Phase 3 needs to be rolled back:

1. **Delete use case files**:
   ```bash
   rm lib/domain/images/use_cases/upload_user_avatar_use_case.dart
   rm lib/domain/images/use_cases/upload_sport_icon_use_case.dart
   rm lib/domain/images/use_cases/upload_sport_cover_use_case.dart
   ```

2. **No other files were modified**, so no additional cleanup needed

3. **Phase 1 & 2 remain intact** and can be used directly if needed

## Architecture Validation

### ✅ Clean Architecture Rules Followed

1. **Domain Independence**: Use cases are pure Dart, no external dependencies
2. **Dependency Inversion**: Use cases depend on repository interface (not implementation)
3. **Single Responsibility**: Each use case handles one specific upload scenario
4. **Input Validation**: Business rules enforced in use cases
5. **Error Handling**: Domain failures thrown (not generic exceptions)

### ✅ Conventions Followed

- Folder paths: `users/avatars`, `sports/icons`, `sports/covers` (no `an_khoe_app` prefix)
- Public ID patterns: `user_{uid}`, `sport_{sportId}_icon`, `sport_{sportId}_cover`
- Overwrite: Enabled for all use cases
- Naming: `Upload{Entity}{Type}UseCase` pattern

## Next Steps

After Phase 3 is validated:
1. ✅ **Phase 3 Complete** - Use cases ready
2. ⏸️ **Wait for approval** before Phase 4
3. **Phase 4** will integrate use cases into presentation layer (UI wiring)

