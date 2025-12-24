# Cloudinary Integration - Phase 5 Implementation

## Goal

Integrate Cloudinary image uploads for sports/activity entities. Add support for icon and cover images in the admin activity management flow.

## Files Modified

### Domain Layer

#### `lib/domain/activities/activity.dart`
- **Added**: `iconUrl` field (optional String) - Cloudinary URL for icon image
- **Added**: `coverUrl` field (optional String) - Cloudinary URL for cover image
- **Updated**: `copyWith()` to include new fields
- **Backward Compatible**: `iconName` field remains for Material Icons support

### Data Layer

#### `lib/data/activities/activity_dto.dart`
- **Added**: `iconUrl` and `coverUrl` fields
- **Updated**: `fromFirestore()`, `toFirestore()`, `toDomain()`, `fromDomain()` to handle new fields

### Presentation Layer

#### `lib/features/admin_activities/presentation/pages/activity_form_page.dart`
- **Added**: Image upload UI sections for icon and cover
- **Added**: State variables: `_iconUrl`, `_coverUrl`, `_isUploadingIcon`, `_isUploadingCover`
- **Added**: Methods:
  - `_buildImageUploadSection()` - Widget for image upload UI
  - `_uploadIconImage()` - Upload icon via `UploadSportIconUseCase`
  - `_uploadCoverImage()` - Upload cover via `UploadSportCoverUseCase`
  - `_getMimeType()` - Helper for MIME type detection
- **Updated**: `_handleSave()` to include `iconUrl` and `coverUrl` in Activity creation/update
- **UX**: Image upload only enabled when editing existing activity (has ID)

#### `lib/features/admin_activities/presentation/pages/activity_list_page.dart`
- **Added**: `_buildActivityIcon()` method
  - Displays `iconUrl` (Cloudinary) if available
  - Falls back to `iconName` (Material Icon) if no URL
  - Falls back to first letter of name as default
- **Added**: `_getIconData()` helper for Material Icon lookup
- **Updated**: `_buildActivityCard()` to use new icon display logic

## Key Features

### 1. Image Upload Flow

**Icon Upload**:
1. User edits existing activity (must have ID)
2. Taps "Tải lên ảnh" in Icon section
3. Image picker opens
4. Image selected → bytes read
5. Upload via `UploadSportIconUseCase`
   - Folder: `sports/icons`
   - Public ID: `sport_{sportId}_icon`
6. URL saved to `_iconUrl` state
7. URL persisted when activity is saved

**Cover Upload**:
- Same flow as icon, but:
  - Folder: `sports/covers`
  - Public ID: `sport_{sportId}_cover`
  - Higher resolution (1920x1080 max)

### 2. Display Priority

**Activity Icon Display** (in list):
1. `iconUrl` (Cloudinary) - if available
2. `iconName` (Material Icon) - if no URL
3. First letter of name - default

### 3. UX Considerations

- **Create Mode**: Image upload disabled (activity must have ID first)
  - Shows info message: "Vui lòng lưu hoạt động trước khi tải ảnh"
- **Edit Mode**: Image upload enabled
  - Can upload, change, or remove images
  - Images persist when activity is saved

### 4. Error Handling

- Network errors: "Lỗi kết nối. Vui lòng kiểm tra internet và thử lại."
- Server errors: "Lỗi server. Vui lòng thử lại sau."
- All errors shown via SnackBar

## Code Changes Summary

### Activity Model (Before → After)

**Before**:
```dart
class Activity {
  final String? iconName; // Material Icon name only
  // ...
}
```

**After**:
```dart
class Activity {
  final String? iconName; // Material Icon (legacy/fallback)
  final String? iconUrl;  // Cloudinary URL (preferred)
  final String? coverUrl; // Cloudinary URL
  // ...
}
```

### Form Page (Before → After)

**Before**:
- Only text fields for activity data
- No image upload capability

**After**:
- Image upload sections for icon and cover
- Preview of uploaded images
- Upload/change/remove buttons
- Loading states during upload

### List Page (Before → After)

**Before**:
```dart
CircleAvatar(
  child: Text(activity.iconName ?? activity.name[0]),
)
```

**After**:
```dart
_buildActivityIcon(activity) // Handles URL → iconName → letter fallback
```

## User Flow

### Creating Activity with Images

1. **Create Activity**:
   - Fill in activity details (name, category, MET, etc.)
   - Save activity (gets ID from Firestore)
   - Form closes, returns to list

2. **Edit Activity to Add Images**:
   - Open activity for editing
   - Image upload sections are now enabled
   - Upload icon image → preview appears
   - Upload cover image → preview appears
   - Save activity → URLs persisted to Firestore

### Editing Activity Images

1. Open activity for editing
2. See existing images (if any)
3. Upload new images or remove existing
4. Save activity → URLs updated in Firestore

## Testing

### Manual Testing Steps

1. **Create New Activity**:
   - Navigate to admin activities page
   - Tap "Add" button
   - Fill in activity details
   - Verify image upload sections show info message (disabled)
   - Save activity

2. **Edit Activity to Upload Images**:
   - Open created activity for editing
   - Verify image upload sections are enabled
   - Upload icon image
   - Verify preview appears
   - Upload cover image
   - Verify preview appears
   - Save activity

3. **Verify Images in List**:
   - Return to activities list
   - Verify icon displays from Cloudinary URL
   - Verify images load correctly

4. **Test Error Cases**:
   - Turn off internet → upload should fail with network error
   - Verify error messages are user-friendly

### Expected Behavior

**Create Mode**:
- Image upload buttons disabled
- Info message shown: "Vui lòng lưu hoạt động trước khi tải ảnh"

**Edit Mode**:
- Image upload buttons enabled
- Can upload, change, or remove images
- Preview shows uploaded images
- URLs saved when activity is saved

**List Display**:
- Icons display from Cloudinary URLs
- Fallback to Material Icons if no URL
- Fallback to letter if no icon

## Firestore Schema Update

### Activity Document Structure

**Before**:
```json
{
  "iconName": "fitness_center",
  // ...
}
```

**After** (with images):
```json
{
  "iconName": "fitness_center",
  "iconUrl": "https://res.cloudinary.com/dimdb3tou/image/upload/v1234567890/sports/icons/sport_abc123_icon.jpg",
  "coverUrl": "https://res.cloudinary.com/dimdb3tou/image/upload/v1234567890/sports/covers/sport_abc123_cover.jpg",
  // ...
}
```

**Backward Compatible**:
- Existing activities with only `iconName` continue to work
- New uploads add `iconUrl` and `coverUrl` fields
- UI handles both gracefully

## Rollback Notes

If Phase 5 needs to be rolled back:

1. **Revert Activity model**:
   - Remove `iconUrl` and `coverUrl` fields from `activity.dart`
   - Remove from `copyWith()`

2. **Revert ActivityDto**:
   - Remove `iconUrl` and `coverUrl` fields
   - Remove from all conversion methods

3. **Revert Form Page**:
   - Remove image upload sections
   - Remove upload methods
   - Restore original form layout

4. **Revert List Page**:
   - Restore original icon display logic

5. **No data migration needed** - existing activities continue to work

## Integration Notes

### Current State
- ✅ Activity model supports iconUrl and coverUrl
- ✅ Form page has image upload UI
- ✅ List page displays images
- ✅ Use cases integrated (UploadSportIcon, UploadSportCover)
- ✅ Backward compatible with existing activities

### Workflow Limitation
- **Image upload requires activity ID**: Must create activity first, then edit to upload images
- **Rationale**: Public ID needs sportId, which is only available after activity creation
- **Workaround**: Create activity → Edit activity → Upload images → Save

### Future Improvements (Optional)
- Allow uploading images during creation (generate temporary ID)
- Batch upload (icon + cover together)
- Image cropping/editing before upload

## Architecture Validation

### ✅ Clean Architecture Maintained

1. **Domain Layer**: Pure, no dependencies on infrastructure
2. **Data Layer**: Implements domain interfaces
3. **Presentation Layer**: Uses use cases, not direct repository access
4. **Dependency Direction**: Presentation → Domain → Data (correct)

### ✅ Backward Compatibility

- Existing activities with only `iconName` continue to work
- No breaking changes to Activity model
- UI gracefully handles both URL and iconName
- No data migration required

## Next Steps

After Phase 5 is validated:
1. ✅ **Phase 5 Complete** - Sports images integrated
2. ⏸️ **Optional Phase 6** - Image URL transformations (f_auto, q_auto, etc.)
3. ⏸️ **Optional Phase 7** - Documentation updates

Phase 5 completes the core Cloudinary integration for both user avatars and sports images.

