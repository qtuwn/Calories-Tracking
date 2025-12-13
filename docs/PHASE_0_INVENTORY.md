# Phase 0: Inventory of Duplicates and Deprecated Code

## Summary

This document inventories all duplicate models, deprecated providers, and problematic code patterns that need to be addressed in subsequent phases.

## 1. Duplicate MealItem Definitions

### Found 4 definitions:

1. **`lib/domain/meal_plans/user_meal_plan_repository.dart`** (Line 10)
   - **Fields**: `id`, `mealType`, `foodId`, `servingSize`, `calories`, `protein`, `carb`, `fat`
   - **Status**: Domain layer, used by repository interface
   - **Used by**: Repository implementations, DTOs, services

2. **`lib/features/meal_plans/domain/models/shared/meal_item.dart`** (Line 5)
   - **Fields**: `id`, `mealType`, `foodId`, `servingSize`, `calories`, `protein`, `carb`, `fat`
   - **Status**: Feature domain model (duplicate of #1)
   - **Used by**: Some feature-level code

3. **`lib/features/home/domain/meal_item.dart`** (Line 2)
   - **Fields**: `id`, `name`, `servingSize`, `caloriesPer100g`, `proteinPer100g`, `carbsPer100g`, `fatPer100g`, `gramsPerServing`
   - **Status**: Different purpose (home/diary feature, has `name` field, different structure)
   - **Used by**: Home/diary pages, meal cards

4. **`lib/features/meal_plans/data/dto/meal_item_dto.dart`** (Line 14)
   - **Status**: DTO (acceptable, but should map to canonical domain model)

### Recommendation:
- **Canonical**: Use `lib/domain/meal_plans/user_meal_plan_repository.dart::MealItem` as the single source of truth
- **Remove**: `lib/features/meal_plans/domain/models/shared/meal_item.dart` (duplicate)
- **Keep but rename**: `lib/features/home/domain/meal_item.dart` → rename to `DiaryMealItem` or `HomeMealItem` to avoid confusion
- **Keep**: DTO is fine, but ensure it maps to canonical domain model

## 2. Duplicate MealType Definitions

### Found 2 definitions:

1. **`lib/features/home/domain/meal_type.dart`** (Line 4)
   - **Fields**: `breakfast`, `lunch`, `dinner`, `snack`
   - **Methods**: `displayName`, `icon`, `color`
   - **Used by**: Home/diary features, meal time classifier

2. **`lib/features/meal_plans/domain/models/shared/meal_type.dart`** (Line 6)
   - **Fields**: `breakfast`, `lunch`, `dinner`, `snack`
   - **Methods**: `value`, `fromString`, `icon`, `color`, `displayName`
   - **Used by**: Meal plan features

### Recommendation:
- **Canonical**: Use `lib/features/meal_plans/domain/models/shared/meal_type.dart` (has `fromString` and `value` methods)
- **Remove**: `lib/features/home/domain/meal_type.dart` (migrate all usages)
- **Alternative**: Move to `lib/domain/shared/meal_type.dart` as truly shared domain enum

## 3. Deprecated Providers

### Found in `lib/features/meal_plans/state/meal_plan_repository_providers.dart`:

1. **`userMealPlanRepositoryProvider`** (Line 12)
   - **Status**: @Deprecated
   - **Replacement**: `user_meal_plan_providers.userMealPlanRepositoryProvider`
   - **Still used**: Need to check call sites

2. **`exploreMealPlanRepositoryProvider`** (Line 22)
   - **Status**: @Deprecated
   - **Replacement**: `explore_meal_plan_providers.exploreMealPlanRepositoryProvider`
   - **Still used**: Need to check call sites

### Found in `lib/features/admin_explore_meal_plans/presentation/state/explore_meal_plan_providers.dart`:

3. **`exploreMealPlanRepositoryProvider`** (Line 8)
   - **Status**: @Deprecated
   - **Replacement**: `shared_providers.exploreMealPlanRepositoryProvider`

4. **`exploreMealPlanServiceProvider`** (Line 15)
   - **Status**: @Deprecated
   - **Replacement**: `shared_providers.exploreMealPlanServiceProvider`

### Recommendation:
- Remove all deprecated providers
- Update all call sites to use new providers from `shared/state/`

## 4. Dummy Cache Issue

### Found in `lib/shared/state/user_meal_plan_providers.dart`:

- **`_DummyUserMealPlanCache`** (Line 98)
  - **Problem**: Returns no-op cache when SharedPreferences is not ready
  - **Impact**: Cache operations silently fail, causing race conditions
  - **Location**: Lines 14-21 in `userMealPlanCacheProvider`

### Recommendation:
- Remove `_DummyUserMealPlanCache`
- Make `userMealPlanCacheProvider` async and await SharedPreferences readiness
- Or preload SharedPreferences before `runApp()`

## 5. ProfileModel Usage (Legacy)

### Found 46 references to ProfileModel:

- **Legacy location**: `lib/features/onboarding/domain/profile_model.dart`
- **New location**: `lib/domain/profile/profile.dart`
- **Status**: Still used in meal plan services (kcal_calculator, etc.)
- **Adapters exist**: `ProfileToProfileModelAdapter`, `ProfileModelAdapter`

### Recommendation:
- Migrate meal plan services to use `Profile` instead of `ProfileModel`
- Remove adapters once migration complete

## 6. Files Using Old Models/Providers

### Files importing duplicate MealItem:

1. `lib/features/meal_plans/domain/repositories/user_meal_plan_repository.dart` → uses `features/meal_plans/domain/models/shared/meal_item.dart`
2. `lib/features/meal_plans/domain/repositories/explore_meal_plan_repository.dart` → uses `features/meal_plans/domain/models/shared/meal_item.dart`
3. `lib/features/home/presentation/pages/diary_page.dart` → uses `features/home/domain/meal_item.dart`
4. `lib/features/home/presentation/providers/diary_provider.dart` → uses `features/home/domain/meal_item.dart`
5. `lib/features/home/presentation/widgets/add_meal_item_bottom_sheet.dart` → uses `features/home/domain/meal_item.dart`
6. `lib/features/home/presentation/widgets/meal_card.dart` → uses `features/home/domain/meal_item.dart`
7. `lib/features/home/domain/meal.dart` → uses `features/home/domain/meal_item.dart`

### Files importing duplicate MealType:

1. `lib/features/diary/domain/services/meal_time_classifier.dart` → uses `features/home/domain/meal_type.dart`
2. `lib/features/home/presentation/screens/home_screen.dart` → uses `features/home/domain/meal_type.dart`
3. `lib/features/meal_plans/presentation/pages/meal_day_editor_page.dart` → uses `features/home/domain/meal_type.dart`
4. `lib/features/meal_plans/presentation/pages/meal_user_active_page.dart` → uses `features/home/domain/meal_type.dart`
5. `lib/features/home/presentation/pages/diary_page.dart` → uses `features/home/domain/meal_type.dart`
6. `lib/features/home/presentation/providers/diary_provider.dart` → uses `features/home/domain/meal_type.dart`
7. `lib/features/home/presentation/providers/home_dashboard_providers.dart` → uses `features/home/domain/meal_type.dart`
8. `lib/features/home/presentation/widgets/add_meal_item_bottom_sheet.dart` → uses `features/home/domain/meal_type.dart`
9. `lib/features/home/domain/meal.dart` → uses `features/home/domain/meal_type.dart`

### Files using deprecated providers:

- Need to search for `meal_plan_repository_providers.userMealPlanRepositoryProvider`
- Need to search for `meal_plan_repository_providers.exploreMealPlanRepositoryProvider`
- Need to search for `admin_explore_meal_plans` providers

## 7. Repository Duplication

### UserMealPlanRepository:

1. **Interface**: `lib/domain/meal_plans/user_meal_plan_repository.dart` ✅ (canonical)
2. **Implementation**: `lib/data/meal_plans/firestore_user_meal_plan_repository.dart` ✅ (canonical)
3. **Legacy Implementation**: `lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart` ⚠️ (check if still used)

### Recommendation:
- Ensure only one implementation exists
- Remove legacy implementation if not used

## 8. Apply Template Copy Logic Issues

### Potential issues (need verification):

1. **Empty IDs**: MealItem created with `id = ''` in apply template flow
2. **Empty foodId**: `foodId` may be empty string instead of null
3. **ServingSize defaults**: May default incorrectly when copying from template

### Files to check:
- `lib/domain/meal_plans/user_meal_plan_service.dart` (applyExploreTemplateAsActive)
- `lib/data/meal_plans/firestore_user_meal_plan_repository.dart` (template copying logic)
- `lib/features/meal_plans/state/applied_meal_plan_controller.dart` (apply flow)

## 9. Stream Race Condition

### Location: `lib/domain/meal_plans/user_meal_plan_service.dart`

- **Method**: `watchActivePlanWithCache`
- **Problem**: Emits cached plan immediately, then Firestore emits later, causing UI to show old plan first
- **Impact**: After "Apply Plan", UI briefly shows old plan before new plan appears

### Recommendation:
- Add deduplication by planId
- Delay cache emission slightly or cancel if Firestore emits first
- Ensure Firestore is source of truth

## Files to Change Summary

### Phase 1 (Unify Models):
- `lib/domain/meal_plans/user_meal_plan_repository.dart` (keep MealItem)
- `lib/features/meal_plans/domain/models/shared/meal_item.dart` (DELETE)
- `lib/features/home/domain/meal_item.dart` (RENAME to DiaryMealItem)
- `lib/features/meal_plans/domain/models/shared/meal_type.dart` (keep, move to shared domain)
- `lib/features/home/domain/meal_type.dart` (DELETE, migrate usages)
- All files importing duplicate models (update imports)

### Phase 2 (Remove Deprecated Providers):
- `lib/features/meal_plans/state/meal_plan_repository_providers.dart` (remove deprecated providers)
- `lib/features/admin_explore_meal_plans/presentation/state/explore_meal_plan_providers.dart` (remove deprecated providers)
- All files using deprecated providers (update to new providers)

### Phase 3 (Fix Cache):
- `lib/shared/state/user_meal_plan_providers.dart` (remove _DummyUserMealPlanCache, make provider async)
- `lib/shared/state/profile_providers.dart` (ensure SharedPreferences is ready)
- `lib/main.dart` (preload SharedPreferences if needed)

### Phase 4 (Fix Stream Race):
- `lib/domain/meal_plans/user_meal_plan_service.dart` (fix watchActivePlanWithCache)

### Phase 5 (Fix Apply Template):
- `lib/domain/meal_plans/user_meal_plan_service.dart` (fix applyExploreTemplateAsActive)
- `lib/data/meal_plans/firestore_user_meal_plan_repository.dart` (fix template copying)

### Phase 6 (Update Tests):
- All test files using ProfileModel (migrate to Profile)
- All test files using deprecated models (update)

---

**Next Step**: Proceed to Phase 1 - Unify MealItem and MealType

