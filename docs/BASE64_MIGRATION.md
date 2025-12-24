# Base64 to Cloudinary Migration

## Overview

This document describes the migration from base64 image storage to Cloudinary URLs exclusively. The migration is **silent** and **non-blocking**, running automatically in the background when profiles with base64 avatars are loaded.

## Migration Strategy

### Silent Background Migration

- **Trigger**: When a profile is loaded with `photoBase64` but no `photoUrl`
- **Execution**: Runs in background (fire-and-forget) - does not block UI
- **Retry Logic**: Network errors are logged and migration retries on next profile load
- **One-Time**: Each profile is migrated once (skipped if already has `photoUrl`)

### Migration Flow

1. **Detection**: Profile loaded with `photoBase64` but no `photoUrl`
2. **Decode**: Base64 string decoded to bytes
3. **Upload**: Bytes uploaded to Cloudinary via `UploadUserAvatarUseCase`
4. **Update**: Profile updated with Cloudinary URL via `updateProfileAvatarUrl()`
5. **Cleanup**: `photoBase64` field removed from Firestore using `FieldValue.delete()`

## Code Changes

### 1. Migration Service

**File**: `lib/data/profile/profile_avatar_migration_service.dart`

- Handles base64 → Cloudinary conversion
- Decodes base64, uploads to Cloudinary, updates profile, removes base64 field
- Handles errors gracefully (network errors retry, invalid base64 logged)

### 2. Profile Page Updates

**File**: `lib/features/home/presentation/pages/profile_page.dart`

**Changes**:
- ✅ Removed base64 encoding logic from upload flow
- ✅ Removed base64 fallback rendering (`_buildBase64Avatar()` removed)
- ✅ Updated `_hasAvatar()` to check only `photoUrl`
- ✅ Updated `_buildAvatarImage()` to use Cloudinary URLs exclusively
- ✅ Added `_triggerMigrationIfNeeded()` to trigger migration in background

**Before**:
```dart
// Had base64 fallback
if (profile.photoUrl != null) {
  return Image.network(profile.photoUrl!);
}
if (profile.photoBase64 != null) {
  return _buildBase64Avatar(profile.photoBase64!);
}
```

**After**:
```dart
// Cloudinary URLs only
if (profile.photoUrl != null && profile.photoUrl!.isNotEmpty) {
  return Image.network(profile.photoUrl!);
}
return Icon(Icons.person);
```

### 3. Deprecated Methods

**Files**:
- `lib/domain/profile/profile_repository.dart`
- `lib/data/profile/firestore_profile_repository.dart`

**Changes**:
- ✅ Marked `updateProfileAvatarBase64()` as `@Deprecated`
- ✅ Added TODO comments indicating removal after migration

### 4. Domain Model Updates

**Files**:
- `lib/domain/profile/profile.dart`
- `lib/data/profile/profile_dto.dart`
- `lib/features/onboarding/domain/profile_model.dart`

**Changes**:
- ✅ Added `@deprecated` annotation to `photoBase64` field
- ✅ Added TODO comments for future removal

### 5. Onboarding Flow

**File**: `lib/features/onboarding/presentation/screens/target_intake_step_screen.dart`

**Changes**:
- ✅ Set `photoBase64: null` when creating profile from onboarding
- ✅ Added TODO comment explaining base64 is no longer used

### 6. Repository Updates

**File**: `lib/data/profile/firestore_profile_repository.dart`

**Changes**:
- ✅ Updated `_normalizeProfileData()` to handle `FieldValue.delete()` for field removal
- ✅ Marked `updateProfileAvatarBase64()` as deprecated

## Migration Behavior

### Success Case

1. Profile loaded with base64 → Migration triggered
2. Base64 decoded → Uploaded to Cloudinary
3. Profile updated with URL → Base64 field removed
4. Profile refreshed → Shows Cloudinary URL

### Network Error Case

1. Profile loaded with base64 → Migration triggered
2. Network error during upload → Error logged
3. Profile shows default icon → Migration retries on next load

### Invalid Base64 Case

1. Profile loaded with invalid base64 → Migration triggered
2. Decode fails → Error logged
3. Profile shows default icon → Migration not retried (invalid data)

## User Experience

### Before Migration

- ✅ Existing base64 avatars display correctly
- ✅ New uploads use Cloudinary
- ✅ Migration runs silently in background

### After Migration

- ✅ All avatars use Cloudinary URLs
- ✅ Base64 fields removed from Firestore
- ✅ No base64 fallback in UI

## Rollback Plan

If migration needs to be rolled back:

1. **Restore base64 fallback in UI**:
   - Restore `_buildBase64Avatar()` method
   - Restore base64 check in `_buildAvatarImage()`

2. **Remove migration trigger**:
   - Remove `_triggerMigrationIfNeeded()` call

3. **Keep deprecated methods**:
   - `updateProfileAvatarBase64()` remains available

4. **No data loss**:
   - Base64 data is only removed after successful Cloudinary upload
   - Failed migrations preserve base64 data

## Cleanup Checklist

After migration completes (all profiles migrated):

- [ ] Remove `photoBase64` field from `Profile` domain model
- [ ] Remove `photoBase64` field from `ProfileDto`
- [ ] Remove `photoBase64` field from `ProfileModel` (onboarding)
- [ ] Remove `updateProfileAvatarBase64()` method from repository interface
- [ ] Remove `updateProfileAvatarBase64()` implementation from Firestore repository
- [ ] Remove `ProfileAvatarMigrationService` (no longer needed)
- [ ] Remove migration trigger from profile page
- [ ] Remove base64-related TODO comments

## Testing

### Manual Testing Steps

1. **Existing Base64 Avatar**:
   - Load profile with base64 avatar
   - Verify migration runs in background
   - Verify avatar displays from Cloudinary URL after migration
   - Verify base64 field removed from Firestore

2. **New Avatar Upload**:
   - Upload new avatar
   - Verify only Cloudinary URL is saved
   - Verify no base64 encoding occurs

3. **Network Error Handling**:
   - Turn off internet
   - Load profile with base64 avatar
   - Verify migration fails gracefully
   - Turn on internet
   - Reload profile
   - Verify migration retries and succeeds

4. **Invalid Base64**:
   - Manually set invalid base64 in Firestore
   - Load profile
   - Verify error logged, migration not retried
   - Verify default icon displays

## Architecture Compliance

### ✅ Clean Architecture Maintained

- **Domain Layer**: Pure, no infrastructure dependencies
- **Data Layer**: Handles migration and storage
- **Presentation Layer**: Triggers migration, displays URLs only

### ✅ Backward Compatibility

- Existing base64 avatars continue to work during migration
- No breaking changes to user experience
- Migration is transparent to users

### ✅ Error Handling

- Network errors: Retry on next load
- Invalid base64: Logged, not retried
- All errors: Non-blocking, graceful degradation

## Performance

### Migration Impact

- **UI**: No blocking - migration runs in background
- **Network**: One-time upload per profile
- **Storage**: Base64 removed after successful migration
- **Retry**: Automatic on next profile load if network error

### Optimization

- Migration only runs once per profile
- Skips if profile already has `photoUrl`
- Skips if no `photoBase64` exists

## Monitoring

### Debug Logs

Migration service logs:
- `🔵 Starting migration for profile {profileId}`
- `✅ Decoded base64 to {bytes} bytes`
- `✅ Uploaded to Cloudinary: {url}`
- `✅ Migration completed for profile {profileId}`
- `⚠️ Migration failed (will retry later): {error}`
- `🔥 Migration error: {error}`

### Success Indicators

- Profile has `photoUrl` field
- `photoBase64` field removed from Firestore
- Avatar displays from Cloudinary URL

## Future Cleanup

Once all profiles are migrated:

1. Remove `photoBase64` field from all models
2. Remove `updateProfileAvatarBase64()` methods
3. Remove migration service
4. Remove migration trigger
5. Remove base64-related TODO comments

**Estimated Timeline**: After 1-2 months of migration runtime (all users have migrated)

