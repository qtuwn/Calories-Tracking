# Profile Module Migration Guide

This document describes the migration from the old Profile module structure to the new DDD + Hybrid Cache architecture.

## Overview

The Profile module has been refactored to follow Domain-Driven Design (DDD) principles with a hybrid cache architecture for instant loading and offline support.

## Architecture Changes

### Old Structure
```
lib/
  features/onboarding/domain/profile_model.dart  (ProfileModel)
  data/firebase/profile_repository.dart           (ProfileRepository)
  shared/state/auth_providers.dart                (Providers)
```

### New Structure
```
lib/
  domain/profile/
    profile.dart                    (Pure Profile domain entity)
    profile_repository.dart         (Abstract repository interface)
    profile_cache.dart              (Abstract cache interface)
    profile_service.dart            (Business logic with cache coordination)
    profile_model_adapter.dart      (Compatibility adapter)
  
  data/profile/
    profile_dto.dart                (Firestore DTO)
    firestore_profile_repository.dart  (Firestore implementation)
    shared_prefs_profile_cache.dart    (SharedPreferences cache)
  
  shared/state/
    profile_providers.dart          (New providers with cache support)
    auth_providers.dart             (Updated to use new service)
```

## Key Improvements

1. **Instant Loading**: Profile loads from local cache immediately, no waiting for Firestore
2. **Offline Support**: App works offline using cached profile data
3. **Background Sync**: Firestore updates happen in background, UI updates when ready
4. **DDD Architecture**: Clean separation of domain, data, and presentation layers
5. **No Flutter/Firebase in Domain**: Domain layer is pure Dart with no external dependencies

## Migration Steps

### Step 1: Update Imports

**Old:**
```dart
import 'package:calories_app/features/onboarding/domain/profile_model.dart';
import 'package:calories_app/data/firebase/profile_repository.dart';
```

**New:**
```dart
import 'package:calories_app/domain/profile/profile.dart';
import 'package:calories_app/shared/state/profile_providers.dart';
```

### Step 2: Update Providers

**Old:**
```dart
final currentUserProfileProvider = StreamProvider<ProfileModel?>((ref) {
  final repository = ProfileRepository();
  return repository.watchCurrentUserProfile(uid).map((map) {
    return ProfileModel.fromMap(map);
  });
});
```

**New:**
```dart
// Use the new provider with cache support
final profileAsync = ref.watch(currentProfileProvider(uid));

profileAsync.when(
  data: (profile) {
    // Profile loads instantly from cache, updates when Firestore syncs
    if (profile == null) return Text('No profile');
    return Text(profile.nickname ?? 'No name');
  },
  loading: () => CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
);
```

### Step 3: Replace ProfileModel with Profile

**Old:**
```dart
ProfileModel? profile = await getProfile();
if (profile != null) {
  print(profile.nickname);
}
```

**New:**
```dart
Profile? profile = await ref.read(profileLoadOnceProvider(uid).future);
if (profile != null) {
  print(profile.nickname);
}
```

### Step 4: Update Repository Usage

**Old:**
```dart
final repository = ProfileRepository();
await repository.saveProfile(uid, profileMap);
```

**New:**
```dart
final service = await ref.read(profileServiceProvider.future);
await service.saveProfile(uid, profile);
```

### Step 5: Handle ProfileModel Compatibility

If you need to temporarily use the old `ProfileModel` API:

```dart
import 'package:calories_app/domain/profile/profile_model_adapter.dart';

// Convert Profile to ProfileModel for compatibility
final profile = await ref.read(profileLoadOnceProvider(uid).future);
final profileModel = ProfileModel.fromProfile(profile);
```

## Provider Migration

### Old Providers (Deprecated)
- `currentUserProfileProvider` - Returns `ProfileModel?`
- Direct `ProfileRepository()` instantiation

### New Providers
- `currentProfileProvider(uid)` - Returns `Profile?` with cache support
- `profileLoadOnceProvider(uid)` - One-time load (cache-first)
- `profileServiceProvider` - Access to ProfileService
- `profileCacheProvider` - Access to cache implementation
- `profileRepositoryProvider` - Access to repository implementation

## Cache Behavior

### Cache-First Loading
1. App starts → Load profile from SharedPreferences cache
2. UI shows cached profile immediately (no lag)
3. Firestore sync happens in background
4. UI updates when Firestore data arrives

### Offline Mode
- Profile loads from cache even when offline
- Firestore updates are queued and applied when online
- No blocking operations during app startup

### Cache Invalidation
```dart
final service = await ref.read(profileServiceProvider.future);
await service.clearCache(uid);  // Clear specific user
await service.clearAllCache();  // Clear all users
```

## Testing Checklist

- [ ] Profile loads instantly on app startup
- [ ] Profile works offline (no network)
- [ ] Firestore updates propagate to UI
- [ ] Cache persists across app restarts
- [ ] No blocking operations during login
- [ ] Profile updates save to both cache and Firestore
- [ ] Multiple users can switch without issues

## Cleanup Steps (After Full Migration)

1. Remove old `ProfileModel` from `lib/features/onboarding/domain/profile_model.dart`
2. Remove old `ProfileRepository` from `lib/data/firebase/profile_repository.dart`
3. Update all remaining imports to use new structure
4. Remove `ProfileModelAdapter` if no longer needed
5. Update tests to use new providers and domain models

## Troubleshooting

### Profile not loading from cache
- Check SharedPreferences permissions
- Verify cache key format: `cached_profile_<uid>`
- Check logs for cache errors

### Firestore updates not syncing
- Verify Firestore connection
- Check network permissions
- Review `watchProfileWithCache` stream logs

### ProfileModel compatibility issues
- Use `ProfileModelAdapter` for temporary compatibility
- Gradually migrate to `Profile` domain model
- Update all usages to new structure

## Benefits After Migration

✅ **Instant UI**: Profile loads immediately from cache  
✅ **Offline Support**: App works without network  
✅ **Clean Architecture**: DDD + SOLID principles  
✅ **Maintainable**: Clear separation of concerns  
✅ **Testable**: Domain layer has no external dependencies  
✅ **Scalable**: Same pattern can be applied to Foods, Diary, etc.

