# Cloudinary Integration - Phase 0 Audit Report

## Executive Summary

This audit identifies integration points for Cloudinary image storage in the Calories App. The app currently stores user avatars as base64 strings in Firestore, which is inefficient for large images. Cloudinary integration will provide optimized image delivery and reduce Firestore storage costs.

## Current State Analysis

### 1. Image Picking Infrastructure

**Location**: `lib/features/home/presentation/pages/profile_page.dart`

- **Package**: `image_picker: ^1.1.1` (already in dependencies)
- **Usage**: Avatar selection in `_pickAndUploadAvatar()` method (lines 722-829)
- **Current Flow**:
  1. User taps avatar → `ImagePicker().pickImage()` called
  2. Image picked → converted to base64 string
  3. Base64 stored in Firestore `photoBase64` field
  4. UI displays from base64 using `Image.memory(base64Decode(...))`

**Integration Point**: Replace base64 encoding with Cloudinary upload in this method.

### 2. User Profile/Avatar Storage

**Domain Layer**:
- `lib/domain/profile/profile_repository.dart` - Interface with `updateProfileAvatarBase64()` method
- `lib/domain/profile/profile.dart` - Profile entity (no image URL field yet)

**Data Layer**:
- `lib/data/profile/firestore_profile_repository.dart` - Firestore implementation
  - `updateProfileAvatarBase64()` method (lines 389-417)
  - Stores in: `users/{userId}/profiles/{profileId}` document
  - Field: `photoBase64` (String)

**Current Schema**:
```dart
users/{userId}/profiles/{profileId}
  - photoBase64: String (base64 encoded image)
```

**Integration Points**:
1. Add `photoUrl` field to Profile domain entity (optional, for backward compatibility)
2. Extend `ProfileRepository` interface with `updateProfileAvatarUrl()` method
3. Update Firestore repository to support both base64 (legacy) and URL (new) storage
4. Update UI to display from URL when available, fallback to base64

### 3. Sports/Activity Entities

**Domain Layer**:
- `lib/domain/activities/activity.dart` - Activity entity
  - Current fields: `id`, `name`, `category`, `met`, `intensity`, `description`, `iconName`, `isActive`
  - **No image URL fields currently**

**Data Layer**:
- `lib/data/activities/activity_dto.dart` - DTO for Firestore
- `lib/data/activities/firestore_activity_repository.dart` - Firestore implementation
- Storage: `activities` collection (root level)

**Integration Points**:
1. Add `iconUrl` and `coverUrl` fields to Activity domain entity (optional)
2. Update ActivityDto to handle new fields
3. Update Firestore repository to persist URLs
4. Add UI support for uploading sport images in admin pages

### 4. Networking Layer

**HTTP Client**:
- Package: `http: ^1.2.0` (already in dependencies)
- Usage: `lib/features/voice_input/data/remote/gemini_voice_api.dart`
- Pattern: Direct `http.post()` calls with JSON body
- Error handling: try-catch with status code checks, debugPrint logging

**Cloudinary Package**:
- `cloudinary_public: ^0.23.1` already in dependencies
- **Note**: This is a public SDK; we'll use direct HTTP multipart upload for unsigned preset

**Integration Point**: Create new infrastructure service using `http` package for multipart uploads.

### 5. Error Handling & Logging Patterns

**Patterns Observed**:
- `debugPrint()` for logging with emoji prefixes (🔵, ✅, 🔥, etc.)
- Try-catch blocks with stack trace logging
- Exception throwing with descriptive messages
- SnackBar for user-facing errors in UI

**Example** (from `gemini_voice_api.dart`):
```dart
try {
  final response = await http.post(...);
  if (response.statusCode != 200) {
    debugPrint('[Service] ❌ API error: ${response.statusCode}');
    throw Exception('API error: ${response.statusCode}');
  }
} catch (e, stackTrace) {
  debugPrint('[Service] 🔥 Error: $e');
  debugPrint('[Service] Stack trace: $stackTrace');
  rethrow;
}
```

**Integration Point**: Follow same pattern for Cloudinary client.

### 6. Architecture Structure

**Clean Architecture Layers**:
- **Domain**: Pure Dart, no dependencies (`lib/domain/`)
- **Data**: Infrastructure implementations (`lib/data/`)
- **Presentation**: UI and state management (`lib/features/*/presentation/`)

**Repository Pattern**:
- Domain interfaces in `lib/domain/*/`
- Implementations in `lib/data/*/`
- Services orchestrate between repositories and caches

**Integration Points**:
1. **Infrastructure** (`lib/data/`): Cloudinary client service
2. **Domain** (`lib/domain/`): Image storage repository interface
3. **Data** (`lib/data/`): Cloudinary repository implementation
4. **Domain** (`lib/domain/`): Use cases for image uploads
5. **Presentation**: Wire into existing UI flows

## Proposed Integration Points

### Phase 1: Infrastructure (MINIMAL)
- **File**: `lib/data/cloudinary/cloudinary_client.dart`
- **Purpose**: Low-level HTTP client for Cloudinary uploads
- **Dependencies**: `http` package (already present)
- **No UI changes**

### Phase 2: Domain Abstraction
- **File**: `lib/domain/images/image_storage_repository.dart`
- **File**: `lib/domain/images/image_asset.dart` (domain model)
- **File**: `lib/data/images/cloudinary_image_storage_repository.dart`
- **Purpose**: Clean Architecture abstraction

### Phase 3: Use Cases
- **File**: `lib/domain/images/use_cases/upload_user_avatar_use_case.dart`
- **File**: `lib/domain/images/use_cases/upload_sport_icon_use_case.dart`
- **File**: `lib/domain/images/use_cases/upload_sport_cover_use_case.dart`
- **Purpose**: Business logic for specific upload scenarios

### Phase 4: Profile Avatar Integration
- **Files to modify**:
  - `lib/domain/profile/profile.dart` - Add `photoUrl` field
  - `lib/domain/profile/profile_repository.dart` - Add `updateProfileAvatarUrl()` method
  - `lib/data/profile/firestore_profile_repository.dart` - Implement URL update
  - `lib/features/home/presentation/pages/profile_page.dart` - Replace base64 with Cloudinary upload

### Phase 5: Sports Images Integration
- **Files to modify**:
  - `lib/domain/activities/activity.dart` - Add `iconUrl`, `coverUrl` fields
  - `lib/data/activities/activity_dto.dart` - Handle new fields
  - `lib/features/admin_activities/presentation/pages/activity_form_page.dart` - Add image upload UI

## Configuration Requirements

### Cloudinary Settings
- **Cloud Name**: `dimdb3tou`
- **Upload Preset**: `ankhoe_uploads` (unsigned)
- **Asset Folder**: `an_khoe_app`
- **Folders**:
  - `users/avatars`
  - `sports/icons`
  - `sports/covers`

### Public ID Conventions
- Avatar: `user_{uid}`
- Sport icon: `sport_{sportId}_icon`
- Sport cover: `sport_{sportId}_cover`
- **Overwrite**: Enabled for avatars and sports (same public_id)

### Security Notes
- ✅ Using unsigned preset (no API secret needed)
- ✅ No secrets stored in app
- ✅ Preset configured in Cloudinary dashboard
- ⚠️ Preset should have upload restrictions (file size, format) configured

## Dependencies Status

| Package | Version | Status | Usage |
|---------|---------|--------|-------|
| `http` | 1.2.0 | ✅ Present | Will use for multipart uploads |
| `image_picker` | 1.1.1 | ✅ Present | Already used for avatar selection |
| `cloudinary_public` | 0.23.1 | ⚠️ Present but unused | Will not use (prefer direct HTTP) |

## Risk Assessment

### Low Risk
- Infrastructure layer (Phase 1) - isolated, testable
- Domain abstraction (Phase 2) - pure Dart, no side effects

### Medium Risk
- Profile avatar migration - need backward compatibility with base64
- UI integration - need to handle loading/error states

### Mitigation
- Keep base64 support during transition
- Add feature flag if needed
- Comprehensive error handling
- User-friendly error messages

## Next Steps

1. ✅ **Phase 0 Complete** - Audit done
2. ⏳ **Phase 1** - Implement Cloudinary client (MINIMAL, isolated)
3. ⏸️ **Wait for approval** before proceeding to Phase 2

