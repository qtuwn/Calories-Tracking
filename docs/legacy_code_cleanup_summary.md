# Legacy Code Cleanup Summary

## Overview

This document summarizes the cleanup of legacy code after migrating Profile, Foods, and Diary modules to the DDD + hybrid cache-first architecture.

## Completed Actions

### STEP 1: Identified Legacy Files

**Profile Module:**
- ✅ `lib/features/onboarding/domain/profile_model.dart` - Still used (69 references), marked as deprecated
- ✅ `lib/data/firebase/profile_repository.dart` - Still used (7 references), marked as deprecated

**Foods Module:**
- ✅ `lib/features/foods/data/food_model.dart` - Still used, marked as deprecated
- ✅ `lib/features/foods/data/food_repository.dart` - Still used, marked as deprecated
- ✅ `lib/features/foods/data/food_providers.dart` - Still used, marked as deprecated

**Diary Module:**
- ✅ `lib/data/firebase/diary_repository.dart` - **REMOVED** (no longer referenced)

### STEP 2: Added @Deprecated Annotations

All legacy classes and providers have been marked with `@Deprecated` annotations pointing to their replacements:

1. **ProfileModel** → Use `domain/profile/profile.dart` and `ProfileService`
2. **ProfileRepository** (legacy) → Use `domain/profile/profile_repository.dart` and `FirestoreProfileRepository`
3. **Food** (legacy model) → Use `domain/foods/food.dart` and `FoodService`
4. **FoodRepository** (legacy) → Use `domain/foods/food_repository.dart` and `FirestoreFoodRepository`
5. **foodRepositoryProvider** (legacy) → Use `shared/state/food_providers.dart::foodRepositoryProvider`

### STEP 3: Removed Unused Files

- ✅ **Deleted:** `lib/data/firebase/diary_repository.dart`
  - Reason: No longer referenced anywhere in the codebase
  - Replacement: `lib/data/diary/firestore_diary_repository.dart`

### STEP 4: Cleaned Up Code

- ✅ Updated TODO comments in adapters to reflect current migration status
- ✅ All deprecated code is clearly marked with migration guidance

## Files Still in Use (Marked as Deprecated)

These files are still referenced but marked as deprecated. They will be removed in a future migration phase:

### Profile Module
- `lib/features/onboarding/domain/profile_model.dart` - Used by:
  - Meal plan services (kcal_calculator, meal_plan_validation_service, etc.)
  - Onboarding flow
  - Profile adapters
- `lib/data/firebase/profile_repository.dart` - Used by:
  - Weight repository (for syncing weight to profile)
  - Some legacy auth providers

### Foods Module
- `lib/features/foods/data/food_model.dart` - Used by:
  - Legacy FoodRepository
- `lib/features/foods/data/food_repository.dart` - Used by:
  - Meal plan editor pages
  - Food admin page
  - Legacy food providers
- `lib/features/foods/data/food_providers.dart` - Used by:
  - Food admin page (for category filter)
  - Meal plan pages (via old foodRepositoryProvider)

## Migration Status

### ✅ Fully Migrated Modules

1. **Diary Module**
   - ✅ All UI uses `DiaryEntry` from `domain/diary/diary_entry.dart`
   - ✅ All providers use `DiaryService` from `shared/state/diary_providers.dart`
   - ✅ Legacy repository removed
   - ✅ Cache-first architecture fully implemented

2. **Profile Module (Core)**
   - ✅ All UI uses `Profile` from `domain/profile/profile.dart`
   - ✅ All providers use `ProfileService` from `shared/state/profile_providers.dart`
   - ✅ Cache-first architecture fully implemented
   - ⚠️ Meal plan services still use ProfileModel (via adapter)

3. **Foods Module (Core)**
   - ✅ All UI uses `Food` from `domain/foods/food.dart`
   - ✅ Core providers use `FoodService` from `shared/state/food_providers.dart`
   - ✅ Cache-first architecture fully implemented
   - ⚠️ Some meal plan pages still use legacy FoodRepository

## Next Steps (Future Migration)

1. **Migrate Meal Plan Services**
   - Update `kcal_calculator.dart` to use `Profile` instead of `ProfileModel`
   - Update other meal plan services to use domain entities
   - Remove `ProfileToProfileModelAdapter` once complete

2. **Migrate Meal Plan Pages**
   - Update meal plan editor pages to use new `FoodRepository` from `shared/state/food_providers.dart`
   - Replace `features/foods/data/food_providers.dart` imports with `shared/state/food_providers.dart`

3. **Migrate Weight Repository**
   - Update `weight_repository.dart` to use new `ProfileRepository` interface
   - Remove dependency on legacy `ProfileRepository`

4. **Final Cleanup**
   - Remove deprecated files once all references are migrated
   - Remove adapter classes
   - Update documentation

## Architecture Compliance

### ✅ Current State

All new code follows the DDD + hybrid cache-first architecture:

- **Domain Layer** (`lib/domain/`)
  - Pure Dart entities (Profile, Food, DiaryEntry)
  - Abstract repository interfaces
  - Abstract cache interfaces
  - Service classes coordinating cache + repository

- **Data Layer** (`lib/data/`)
  - DTOs for Firestore mapping
  - Firestore repository implementations
  - SharedPreferences cache implementations

- **Presentation Layer** (`lib/features/`, `lib/shared/state/`)
  - Riverpod providers using services
  - Cache-first streams
  - UI widgets consuming providers

### ⚠️ Legacy Code Still Present

Legacy code is clearly marked with `@Deprecated` annotations and will be removed in future phases. The adapters ensure backward compatibility during the transition.

## Validation

- ✅ Project compiles without errors
- ✅ All deprecated code is clearly marked
- ✅ No broken imports
- ✅ Legacy DiaryRepository successfully removed
- ✅ All modules use cache-first architecture for new code

## Notes

- The adapters (`ProfileToProfileModelAdapter`, `ProfileModelAdapter`) are intentionally kept to support gradual migration
- Legacy code is marked as deprecated but not removed to prevent breaking changes
- All deprecation messages point to migration guides and replacement classes

