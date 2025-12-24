# Cloudinary Integration - Phase 4 Implementation

## Goal

Integrate Cloudinary avatar upload into the existing profile/account flow. Replace base64 storage with Cloudinary URLs while maintaining backward compatibility with existing base64 avatars.

## Files Modified

### Domain Layer

#### `lib/domain/profile/profile.dart`
- **Added**: `photoUrl` field (optional String)
- **Updated**: `copyWith()`, `toJson()`, `fromJson()` to include `photoUrl`
- **Backward Compatible**: `photoBase64` field remains for legacy support

#### `lib/domain/profile/profile_repository.dart`
- **Added**: `updateProfileAvatarUrl()` method
- **Kept**: `updateProfileAvatarBase64()` for backward compatibility

### Data Layer

#### `lib/data/profile/firestore_profile_repository.dart`
- **Added**: `updateProfileAvatarUrl()` implementation
- **Behavior**: Updates `photoUrl` field in Firestore profile document

#### `lib/data/profile/profile_dto.dart`
- **Added**: `photoUrl` field
- **Updated**: `fromFirestore()`, `toFirestore()`, `toDomain()`, `fromDomain()` to handle `photoUrl`

### Presentation Layer

#### `lib/shared/state/image_storage_providers.dart` (NEW)
- **Providers Created**:
  - `imageStorageRepositoryProvider` - Cloudinary repository
  - `uploadUserAvatarUseCaseProvider` - Avatar upload use case
  - `uploadSportIconUseCaseProvider` - Sport icon upload use case
  - `uploadSportCoverUseCaseProvider` - Sport cover upload use case

#### `lib/features/home/presentation/pages/profile_page.dart`
- **Updated**: `_pickAndUploadAvatar()` method
  - Replaced base64 encoding with Cloudinary upload via `UploadUserAvatarUseCase`
  - Reads image bytes from picked file
  - Determines MIME type from file extension
  - Calls use case to upload to Cloudinary
  - Saves returned URL to Firestore via `updateProfileAvatarUrl()`
  - Handles `ImageStorageFailure` types with user-friendly error messages
- **Added**: Helper methods
  - `_hasAvatar()` - Checks if profile has avatar (URL or base64)
  - `_buildAvatarImage()` - Builds avatar widget (URL first, fallback to base64)
  - `_buildBase64Avatar()` - Builds avatar from base64 string
  - `_getMimeType()` - Determines MIME type from file extension
- **Updated**: Avatar display logic
  - Prefers `photoUrl` (Cloudinary) over `photoBase64` (legacy)
  - Shows loading indicator while loading network image
  - Falls back to base64 if URL fails to load
  - Falls back to default icon if no avatar available

## Key Features

### 1. Backward Compatibility
- Existing profiles with `photoBase64` continue to work
- UI displays URL first, falls back to base64
- No data migration required

### 2. Error Handling
- **Network Errors**: User-friendly message "Lỗi kết nối. Vui lòng kiểm tra internet và thử lại."
- **Server Errors**: "Lỗi server. Vui lòng thử lại sau."
- **Invalid Response**: "Lỗi xử lý ảnh. Vui lòng thử lại."
- All errors shown via SnackBar with red background

### 3. Loading States
- Upload state managed by `avatarUploadControllerProvider`
- Network image shows loading indicator while loading
- UI remains responsive during upload

### 4. Image Display Priority
1. **photoUrl** (Cloudinary) - if available
2. **photoBase64** (legacy) - if URL not available
3. **Default icon** - if no avatar

## User Flow

1. User taps avatar circle
2. Image picker opens (gallery)
3. User selects image
4. Image is read as bytes
5. MIME type determined from extension
6. Upload to Cloudinary via `UploadUserAvatarUseCase`
   - Folder: `users/avatars`
   - Public ID: `user_{uid}`
   - Overwrite: `true`
7. Cloudinary returns secure URL
8. URL saved to Firestore `photoUrl` field
9. Profile providers invalidated
10. UI updates to show new avatar from URL
11. Success message shown

## Code Changes Summary

### Upload Flow (Before → After)

**Before (Base64)**:
```dart
final bytes = await picked.readAsBytes();
final base64String = base64Encode(bytes);
await repository.updateProfileAvatarBase64(
  userId: uid,
  profileId: profileId,
  photoBase64: base64String,
);
```

**After (Cloudinary)**:
```dart
final bytes = await picked.readAsBytes();
final useCase = ref.read(uploadUserAvatarUseCaseProvider);
final imageAsset = await useCase.execute(
  bytes: bytes,
  fileName: fileName,
  mimeType: mimeType,
  uid: uid,
);
await repository.updateProfileAvatarUrl(
  userId: uid,
  profileId: profileId,
  photoUrl: imageAsset.url,
);
```

### Avatar Display (Before → After)

**Before**:
```dart
profile?.photoBase64 != null && profile!.photoBase64!.isNotEmpty
  ? Image.memory(base64Decode(profile.photoBase64!))
  : Icon(Icons.person)
```

**After**:
```dart
_buildAvatarImage(profile) // Handles URL → base64 → icon fallback
```

## Testing

### Manual Testing Steps

1. **Open Profile Page**
   - Navigate to account/profile screen
   - Verify current avatar displays (if exists)

2. **Upload New Avatar**
   - Tap avatar circle
   - Select image from gallery
   - Wait for upload (loading indicator should show)
   - Verify success message appears
   - Verify new avatar displays from Cloudinary URL

3. **Verify Backward Compatibility**
   - Check existing profiles with base64 avatars still display
   - Upload new avatar for user with base64 avatar
   - Verify new URL avatar displays (base64 should be ignored)

4. **Test Error Cases**
   - Turn off internet → upload should fail with network error
   - Verify error message is user-friendly

### Expected Behavior

**Success Case**:
- Image uploads to Cloudinary
- URL saved to Firestore
- Avatar updates immediately
- Success message: "Cập nhật ảnh đại diện thành công"

**Error Cases**:
- Network error → "Lỗi kết nối. Vui lòng kiểm tra internet và thử lại."
- Server error → "Lỗi server. Vui lòng thử lại sau."
- Invalid response → "Lỗi xử lý ảnh. Vui lòng thử lại."

## Firestore Schema Update

### Profile Document Structure

**Before**:
```json
{
  "photoBase64": "iVBORw0KGgoAAAANSUhEUgAA..."
}
```

**After** (new uploads):
```json
{
  "photoUrl": "https://res.cloudinary.com/dimdb3tou/image/upload/v1234567890/users/avatars/user_abc123.jpg",
  "photoBase64": null  // or existing base64 for legacy
}
```

**Backward Compatible**:
- Existing documents with only `photoBase64` continue to work
- New uploads add `photoUrl` field
- UI handles both fields gracefully

## Rollback Notes

If Phase 4 needs to be rolled back:

1. **Revert profile_page.dart**:
   - Restore `_pickAndUploadAvatar()` to base64 flow
   - Remove helper methods (`_hasAvatar`, `_buildAvatarImage`, etc.)
   - Restore original avatar display logic

2. **Optional (if keeping photoUrl field)**:
   - Keep `photoUrl` field in Profile model (harmless if unused)
   - Keep `updateProfileAvatarUrl()` method (can be unused)

3. **Delete providers** (if not needed):
   ```bash
   rm lib/shared/state/image_storage_providers.dart
   ```

4. **No data migration needed** - existing base64 avatars continue to work

## Integration Notes

### Current State
- ✅ Avatar upload uses Cloudinary
- ✅ URLs stored in Firestore
- ✅ UI displays from URL (with base64 fallback)
- ✅ Backward compatible with existing base64 avatars
- ✅ Error handling with user-friendly messages
- ✅ Loading states managed

### Next Phase (Phase 5)
- Will integrate sport/activity image uploads
- Will add iconUrl and coverUrl to Activity entity
- Will wire into admin activity management UI

## Architecture Validation

### ✅ Clean Architecture Maintained

1. **Domain Layer**: Pure, no dependencies on infrastructure
2. **Data Layer**: Implements domain interfaces
3. **Presentation Layer**: Uses use cases, not direct repository access
4. **Dependency Direction**: Presentation → Domain → Data (correct)

### ✅ Backward Compatibility

- Existing base64 avatars continue to work
- No breaking changes to Profile model
- UI gracefully handles both URL and base64
- No data migration required

### ✅ User Experience

- Fast uploads (Cloudinary CDN)
- Optimized images (Cloudinary transformations available)
- Reliable error messages
- Smooth loading states

## Next Steps

After Phase 4 is validated:
1. ✅ **Phase 4 Complete** - Avatar upload integrated
2. ⏸️ **Wait for approval** before Phase 5
3. **Phase 5** will add sport/activity image uploads

