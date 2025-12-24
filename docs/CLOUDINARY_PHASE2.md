# Cloudinary Integration - Phase 2 Implementation

## Goal

Create domain-level abstraction for image storage following Clean Architecture principles. This phase introduces pure domain models and interfaces, keeping business logic independent of infrastructure details.

## Files Created

### Domain Layer (Pure Dart, No Dependencies)

#### `lib/domain/images/image_asset.dart`
- **Purpose**: Domain model representing an uploaded image
- **Fields**: `url`, `publicId`, `version`, `format`, `width`, `height`, `bytes`
- **Characteristics**: 
  - Pure Dart class (no Flutter/Firebase dependencies)
  - Immutable with `copyWith()` method
  - Value equality based on `url` and `publicId`

#### `lib/domain/images/image_storage_repository.dart`
- **Purpose**: Abstract repository interface for image storage
- **Method**: `uploadImage(File, String folder, String publicId, bool overwrite)`
- **Characteristics**:
  - Pure domain interface (no external dependencies)
  - Defines contract for image upload operations
  - Allows swapping implementations (Cloudinary, Firebase Storage, etc.)

### Data Layer (Infrastructure Implementation)

#### `lib/data/images/cloudinary_image_storage_repository.dart`
- **Purpose**: Cloudinary implementation of `ImageStorageRepository`
- **Dependencies**: 
  - `CloudinaryClient` (from Phase 1)
  - Domain models (`ImageAsset`, `ImageStorageRepository`)
- **Responsibilities**:
  - Wraps `CloudinaryClient` calls
  - Converts infrastructure results (`CloudinaryUploadResult`) to domain models (`ImageAsset`)
  - Translates infrastructure exceptions to domain exceptions
  - Provides factory method `createDefault()` for convenience

## Architecture Benefits

### 1. Clean Architecture Compliance
- **Domain Layer**: Pure Dart, no external dependencies
- **Data Layer**: Implements domain interfaces
- **Dependency Direction**: Data → Domain (correct direction)

### 2. Testability
- Domain models can be unit tested without infrastructure
- Repository interface can be mocked for use case tests
- Infrastructure can be swapped without changing domain code

### 3. Maintainability
- Clear separation of concerns
- Business logic independent of Cloudinary specifics
- Easy to add alternative implementations (e.g., Firebase Storage)

## Code Structure

### Domain Model
```dart
class ImageAsset {
  final String url;
  final String publicId;
  final int? version;
  // ... other optional fields
}
```

### Domain Interface
```dart
abstract class ImageStorageRepository {
  Future<ImageAsset> uploadImage({
    required File file,
    required String folder,
    required String publicId,
    bool overwrite = false,
  });
}
```

### Data Implementation
```dart
class CloudinaryImageStorageRepository implements ImageStorageRepository {
  final CloudinaryClient _client;
  
  @override
  Future<ImageAsset> uploadImage(...) async {
    final result = await _client.uploadImage(...);
    return ImageAsset(...); // Convert to domain model
  }
}
```

## How to Test

### Manual Testing

1. **Create a test script** (temporary, for Phase 2 validation)

   Create `test/image_storage_repository_test_manual.dart`:
   ```dart
   import 'dart:io';
   import 'package:calories_app/data/images/cloudinary_image_storage_repository.dart';

   void main() async {
     final repository = CloudinaryImageStorageRepository.createDefault();

     try {
       // Replace with actual file path
       final testFile = File('/path/to/test_image.jpg');
       
       final imageAsset = await repository.uploadImage(
         file: testFile,
         folder: 'an_khoe_app/users/avatars',
         publicId: 'user_test_123',
         overwrite: true,
       );

       print('✅ Upload successful!');
       print('URL: ${imageAsset.url}');
       print('Public ID: ${imageAsset.publicId}');
       print('Format: ${imageAsset.format}');
       print('Size: ${imageAsset.width}x${imageAsset.height}');
     } catch (e) {
       print('❌ Upload failed: $e');
     } finally {
       repository.dispose();
     }
   }
   ```

2. **Run the test**
   ```bash
   flutter run test/image_storage_repository_test_manual.dart
   ```

3. **Verify**
   - Image uploads successfully
   - Returns `ImageAsset` domain model
   - URL is accessible
   - Public ID matches expected value

### Unit Testing (Future)

The domain abstraction enables easy unit testing:

```dart
// Mock repository for use case tests
class MockImageStorageRepository implements ImageStorageRepository {
  @override
  Future<ImageAsset> uploadImage(...) async {
    return ImageAsset(url: 'https://...', publicId: 'test_123');
  }
}

// Test use cases without network calls
test('UploadUserAvatar use case', () async {
  final mockRepo = MockImageStorageRepository();
  final useCase = UploadUserAvatarUseCase(mockRepo);
  // ... test logic
});
```

## Integration Notes

### Current State
- ✅ Domain layer is pure and testable
- ✅ Data layer implements domain interface
- ✅ No UI or business logic changes yet
- ✅ Ready for use case layer (Phase 3)

### Dependency Flow
```
Presentation Layer
    ↓ (depends on)
Domain Layer (ImageStorageRepository interface)
    ↑ (implemented by)
Data Layer (CloudinaryImageStorageRepository)
    ↓ (uses)
Infrastructure (CloudinaryClient)
```

### Next Phase (Phase 3)
- Will create use cases:
  - `UploadUserAvatarUseCase`
  - `UploadSportIconUseCase`
  - `UploadSportCoverUseCase`
- Use cases will orchestrate repository calls
- Use cases will handle folder/publicId mapping

## Rollback Notes

If Phase 2 needs to be rolled back:

1. **Delete domain files**:
   ```bash
   rm lib/domain/images/image_asset.dart
   rm lib/domain/images/image_storage_repository.dart
   ```

2. **Delete data implementation**:
   ```bash
   rm lib/data/images/cloudinary_image_storage_repository.dart
   ```

3. **No other files were modified**, so no additional cleanup needed

4. **Phase 1 (CloudinaryClient) remains intact** and can be used directly if needed

## Architecture Validation

### ✅ Clean Architecture Rules Followed

1. **Domain Independence**: Domain layer has zero external dependencies
2. **Dependency Inversion**: Data layer depends on domain interfaces (not vice versa)
3. **Interface Segregation**: Single, focused repository interface
4. **Single Responsibility**: Each class has one clear purpose

### ✅ Naming Conventions

- Domain models: `ImageAsset` (noun, singular)
- Repository interface: `ImageStorageRepository` (matches existing pattern)
- Implementation: `CloudinaryImageStorageRepository` (provider name prefix)
- File structure: Matches existing domain/data organization

## Next Steps

After Phase 2 is validated:
1. ✅ **Phase 2 Complete** - Domain abstraction ready
2. ⏸️ **Wait for approval** before Phase 3
3. **Phase 3** will add use cases for specific upload scenarios

