# Meal Plans Module Migration to DDD + Hybrid Cache-First Architecture

## Overview

This document outlines the migration plan for the Meal Plans module to follow the same DDD + hybrid cache-first architecture pattern used in Profile, Foods, and Diary modules.

## Current State

### User Meal Plans
- **Domain Models**: Located in `lib/features/meal_plans/domain/models/user/`
  - `UserMealPlan` - Pure domain model (no Flutter/Firebase)
  - `UserMealDay` - Day summary model
  - `UserMealEntry` - Meal item (alias for MealItem)
- **Repository**: `UserMealPlanRepository` interface in `lib/features/meal_plans/domain/repositories/`
- **Implementation**: `UserMealPlanRepositoryImpl` in `lib/features/meal_plans/data/repositories/`
- **DTOs**: `UserMealPlanDto`, `UserMealDayDto`, `MealItemDto` in `lib/features/meal_plans/data/dto/`
- **Status**: Models are already pure domain, but missing cache/service layers

### Explore Meal Plans
- **Domain Models**: Already in `lib/domain/meal_plans/explore_meal_plan.dart`
- **Repository**: `ExploreMealPlanRepository` interface in `lib/domain/meal_plans/`
- **Service**: `ExploreMealPlanService` in `lib/domain/meal_plans/`
- **Implementation**: `FirestoreExploreMealPlanRepository` in `lib/data/meal_plans/`
- **Status**: Domain structure exists, but missing cache layer

## Migration Plan

### Phase 1: Create Unified Domain Structure ✅ (In Progress)

1. **Create unified MealPlanGoalType enum** ✅
   - File: `lib/domain/meal_plans/meal_plan_goal_type.dart`
   - Supports both User Meal Plans and Explore Meal Plans goal types
   - Handles mapping between different enum values

2. **Create User Meal Plan domain entities** ✅
   - File: `lib/domain/meal_plans/user_meal_plan.dart`
   - Includes `UserMealPlan`, `UserMealPlanStatus`, `UserMealPlanType` enums
   - JSON serialization support for caching

3. **Create User Meal Plan repository interface** ✅
   - File: `lib/domain/meal_plans/user_meal_plan_repository.dart`
   - Includes `MealItem` and `MealPlanDay` helper classes
   - Matches existing repository interface

4. **Create User Meal Plan cache interface** ✅
   - File: `lib/domain/meal_plans/user_meal_plan_cache.dart`
   - Methods for caching active plan, plans list, individual plans

5. **Create User Meal Plan service** ✅
   - File: `lib/domain/meal_plans/user_meal_plan_service.dart`
   - Cache-first logic for `watchActivePlanWithCache`, `watchPlansForUserWithCache`
   - Write methods that update cache

### Phase 2: Implement Data Layer (In Progress)

1. **Create SharedPreferences cache implementation** ✅
   - File: `lib/data/meal_plans/shared_prefs_user_meal_plan_cache.dart`
   - Implements `UserMealPlanCache`
   - Key patterns: `cached_user_meal_plan_active_<uid>`, `cached_user_meal_plans_list_<uid>`

2. **Create Firestore repository wrapper** ✅
   - File: `lib/data/meal_plans/firestore_user_meal_plan_repository.dart`
   - Wraps existing `UserMealPlanRepositoryImpl`
   - Adapter converts between legacy models and new domain models
   - Handles goal type mapping

3. **Add cache layer to Explore Meal Plans** (Pending)
   - Create `ExploreMealPlanCache` interface
   - Create `SharedPrefsExploreMealPlanCache` implementation
   - Update `ExploreMealPlanService` to use cache

### Phase 3: Create Riverpod Providers (Pending)

1. **Create `user_meal_plan_providers.dart`**
   - `userMealPlanCacheProvider`
   - `userMealPlanRepositoryProvider`
   - `userMealPlanServiceProvider`
   - `activeMealPlanProvider(uid)` - Stream provider with cache
   - `userMealPlansProvider(uid)` - Stream provider with cache
   - `activeMealPlanLoadOnceProvider(uid)` - Future provider

2. **Update Explore Meal Plan providers**
   - Add cache provider
   - Update service provider to use cache
   - Update stream providers to use cache-first service

### Phase 4: Migrate UI and Controllers (Pending)

1. **Update meal plan controllers**
   - `ActiveMealPlanProvider` → use `activeMealPlanProvider(uid)`
   - `UserCustomMealPlanController` → use `userMealPlanServiceProvider`
   - `AppliedMealPlanController` → use `userMealPlanServiceProvider`

2. **Update UI screens**
   - `MealUserActivePage` → use `activeMealPlanProvider(uid)`
   - `MealCustomRoot` → use `userMealPlansProvider(uid)`
   - `MealDetailPage` → use new providers
   - `MealDayEditorPage` → use new providers

3. **Update Explore Meal Plan screens**
   - Use cache-aware providers
   - Instant loading from cache

### Phase 5: Cleanup Legacy Code (Pending)

1. **Mark legacy models as deprecated**
   - `lib/features/meal_plans/domain/models/user/user_meal_plan.dart`
   - Keep adapters for compatibility

2. **Remove unused legacy code**
   - After full migration, remove adapters
   - Remove legacy model files

## Implementation Status

### ✅ Completed
- Unified `MealPlanGoalType` enum
- User Meal Plan domain entities (`lib/domain/meal_plans/user_meal_plan.dart`)
- User Meal Plan repository interface
- User Meal Plan cache interface
- User Meal Plan service
- SharedPreferences cache implementation
- Firestore repository wrapper with adapter

### 🔄 In Progress
- Fixing import issues
- Creating providers

### ⏳ Pending
- Explore Meal Plan cache layer
- Riverpod providers
- UI migration
- Legacy code cleanup

## Key Design Decisions

1. **Goal Type Mapping**: Created unified `MealPlanGoalType` enum that supports both User Meal Plans (loseFat, maintain) and Explore Meal Plans (loseWeight, maintainWeight, etc.)

2. **Adapter Pattern**: Using adapter to convert between legacy models (in `features/meal_plans/domain/`) and new domain models (in `lib/domain/meal_plans/`) to enable gradual migration

3. **Repository Wrapper**: `FirestoreUserMealPlanRepository` wraps the existing `UserMealPlanRepositoryImpl` to avoid duplicating Firestore logic

4. **Cache Strategy**: 
   - Active plan cached separately for instant access
   - Plans list cached for quick loading
   - Individual plans cached for detail views

## Next Steps

1. Fix import issues in domain files
2. Create Riverpod providers
3. Add Explore Meal Plan cache layer
4. Migrate UI screens to use new providers
5. Test cache-first behavior
6. Clean up legacy code

## Notes

- The existing `UserMealPlanRepositoryImpl` is well-structured and handles complex Firestore operations (transactions, batch writes, etc.)
- The adapter pattern allows us to keep using the existing repository while migrating to new domain models
- Cache invalidation is handled automatically when plans are saved/deleted
- Goal type mapping ensures compatibility between different enum values used in User vs Explore plans

