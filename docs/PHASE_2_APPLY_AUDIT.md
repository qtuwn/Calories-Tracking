# Phase 2: Apply Explore Meal Plan Audit

## Problem Statement

User taps "Start / Apply" on an explore template:
- UI shows "Applied successfully"
- But "Your Meal Plans" still shows the previously active user-created plan
- Logs indicate apply method ran and returned success

## Root Causes Identified

### Root Cause 1: Cache Race Condition in watchActivePlanWithCache (CRITICAL)

**File**: `lib/domain/meal_plans/user_meal_plan_service.dart`

**Location**: `watchActivePlanWithCache()` method, lines 40-179

**Issue**: The stream logic has a race condition:

1. Line 30: Cache is loaded asynchronously: `final cachedPlanFuture = _cache.loadActivePlan(userId);`
2. Line 40: Firestore stream is started: `final firestoreStream = _repository.getActivePlan(userId);`
3. Line 73: Waits for first Firestore emission with 500ms timeout
4. Line 98-112: If Firestore timeout, emits cache as fallback

**The Problem**: 
- When provider is invalidated after apply, a new stream is created
- Cache is cleared (we call `clearActivePlan` twice in service)
- BUT: The Firestore query might not immediately reflect the new plan (Firestore eventual consistency + query propagation delay)
- The 500ms timeout might be too short in some cases, causing cache fallback to null
- OR: If Firestore emits the OLD plan (before new plan propagates), the old plan gets emitted

**Fix Strategy**: After apply, we should:
1. Clear cache BEFORE applying (already done ✅)
2. Ensure provider invalidation triggers a fresh stream
3. Add a verification step: After apply completes, verify the new plan is actually in Firestore before returning
4. Increase timeout slightly OR add retry logic for first emission after apply

### Root Cause 2: Metadata Not Preserved in ApplyExploreTemplateService

**File**: `lib/features/meal_plans/domain/services/apply_explore_template_service.dart`

**Location**: `applyTemplate()` method, lines 22-61

**Issue**: When creating `UserMealPlan` from `ExploreMealPlan`, only these fields are copied:
- ✅ `name` (line 50)
- ✅ `goalType` (line 51)
- ✅ `dailyCalories` (line 56)
- ✅ `durationDays` (line 57)
- ❌ `description` - NOT copied
- ❌ `tags` - NOT copied
- ❌ `difficulty` - NOT copied

**Impact**: Applied plans lose metadata fields.

**Fix**: Add these fields to `UserMealPlan` if they exist, or ensure `ApplyExploreTemplateService` copies all relevant metadata.

### Root Cause 3: Provider Invalidation May Not Force Fresh Query

**File**: `lib/shared/state/user_meal_plan_providers.dart`

**Location**: `activeMealPlanProvider`, lines 52-63

**Issue**: When `ref.invalidate()` is called, it recreates the provider. However, Firestore streams are lazy - they only emit when subscribed. There might be a delay between:
- Provider invalidation
- New stream subscription
- Firestore query execution
- First emission

**Fix**: Ensure cache is cleared synchronously BEFORE provider invalidation, and add a small delay or verification step.

## Apply Pipeline Trace

### End-to-End Flow:

1. **UI**: `MealDetailPage._startPlan()` (line 836)
   - Calls `appliedController.applyExploreTemplate(...)`

2. **Controller**: `AppliedMealPlanController.applyExploreTemplate()` (line 90)
   - Loads template
   - Calls `service.applyExploreTemplateAsActivePlan(...)`
   - Invalidates `activeMealPlanProvider` (line 153)

3. **Service**: `UserMealPlanService.applyExploreTemplateAsActivePlan()` (line 278)
   - Clears cache (line 288)
   - Calls repository (line 292)
   - Clears cache AGAIN (line 303)
   - Does NOT save to cache (intentionally - lets stream handle it)

4. **Repository**: `UserMealPlanRepositoryImpl.applyExploreTemplateAsActivePlan()` (line 834)
   - Uses batch write to deactivate old plans and create new active plan
   - Has post-write verification (lines 1157-1185) - checks exactly 1 active plan exists
   - Returns new plan

5. **Provider**: `activeMealPlanProvider` (line 52)
   - On invalidation, recreates stream
   - Calls `service.watchActivePlanWithCache(userId)`

6. **Stream**: `watchActivePlanWithCache()` (line 40)
   - Loads cache (should be null after clear)
   - Waits for Firestore first emission (500ms timeout)
   - Emits Firestore or cache fallback

## Fixes Required

### Fix 1: Add Retry Logic for Firestore First Emission After Apply
- After clearing cache, wait longer for Firestore first emission
- Or: Add a verification query before returning from apply

### Fix 2: Preserve Metadata in ApplyExploreTemplateService
- Copy `description`, `tags`, `difficulty` from template to user plan
- Note: Need to check if `UserMealPlan` domain model supports these fields

### Fix 3: Ensure Cache is Cleared Synchronously
- Already done, but add verification logging

### Fix 4: Add Post-Apply Verification
- After repository apply, verify the new plan is actually queryable from Firestore
- Wait for query to return the new plan before returning from service

## Verification Steps

After fixes:
1. Apply an explore template
2. Check logs for: cache cleared, Firestore write succeeded, new plan verified
3. Check "Your Meal Plans" UI shows new plan immediately
4. Verify exactly 1 active plan exists in Firestore
5. Verify metadata fields are preserved in applied plan

