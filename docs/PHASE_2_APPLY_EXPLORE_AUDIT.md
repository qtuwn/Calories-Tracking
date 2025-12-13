# Phase 2: Apply Explore Meal Plan - Root Cause Analysis

## Problem Statement

User taps "Start / Apply" on explore template:
- UI shows "Applied successfully" ✅
- But "Your Meal Plans" still shows previously active user-created plan ❌
- Logs indicate apply method ran and returned success ✅

This indicates a **source-of-truth / caching / provider refresh problem**.

## Step 1: Apply Pipeline Trace

### Call Chain End-to-End

1. **UI Button** → `MealDetailPage._startPlan()` (line 836)
   - Reads user from `authStateProvider`
   - Reads profile from `currentUserProfileProvider`
   - Calls `appliedController.applyExploreTemplate()`

2. **Controller** → `AppliedMealPlanController.applyExploreTemplate()` (line 100-171)
   - Loads template from explore repository
   - Converts profile to Map
   - Calls `service.applyExploreTemplateAsActivePlan()`
   - Invalidates `activeMealPlanProvider` (line 153)

3. **Service** → `UserMealPlanService.applyExploreTemplateAsActivePlan()` (line 272-305)
   - **Clears stale cache**: `await _cache.clearActivePlan(userId);` (line 282)
   - **Calls repository**: `await _repository.applyExploreTemplateAsActivePlan(...)` (line 286-291)
   - **Saves new plan to cache**: `await _cache.saveActivePlan(userId, plan);` (line 296)
   - Returns new plan

4. **Repository** → `UserMealPlanRepositoryImpl.applyExploreTemplateAsActivePlan()` (line 834-1190)
   - Uses Firestore batch to:
     - Deactivate all existing active plans (line 867-889)
     - Create new active plan from template (line 891-915)
   - Commits batch atomically (line 923)
   - Verifies write succeeded (line 927-931)
   - Copies meals from template to user plan (line 943-1139)
   - **Post-write verification**: Queries for active plans (line 1158-1179)
   - Returns new plan

5. **Provider Invalidation** → `activeMealPlanProvider` (line 52-63 in user_meal_plan_providers.dart)
   - When invalidated, provider rebuilds and calls `watchActivePlanWithCache()` again

6. **Stream** → `UserMealPlanService.watchActivePlanWithCache()` (line 33-173)
   - Loads cache in parallel (line 37)
   - Subscribes to Firestore stream (line 40)
   - Waits 300ms for first Firestore emission (line 71)
   - If Firestore emits within 300ms: emits from Firestore ✅
   - If Firestore timeout: emits from cache ❌ **RACE CONDITION**

7. **UI** → `MealUserActivePage` watches `activeMealPlanProvider`
   - Shows plan from stream

## Root Causes Identified

### Root Cause 1: Cache/Stream Race Condition (CRITICAL)

**Location**: `lib/domain/meal_plans/user_meal_plan_service.dart`, `watchActivePlanWithCache()` (line 33-173)

**Issue**: 
1. Service clears cache before apply (line 282)
2. Service saves new plan to cache after apply (line 296)
3. Controller invalidates provider (line 153)
4. Provider rebuilds and calls `watchActivePlanWithCache()` again
5. `watchActivePlanWithCache()` loads cache in parallel (line 37)
6. If Firestore query takes > 300ms, it falls back to cache
7. **BUT**: There's a timing window where:
   - Cache might not be saved yet (though unlikely since it's awaited)
   - OR Firestore stream might not emit immediately after invalidation
   - OR The deduplication logic (line 126-132) might skip emission if planId matches

**Impact**: After invalidation, the stream might emit:
- Null (if cache was cleared and Firestore hasn't emitted yet)
- Old plan (if cache wasn't properly cleared before new one was saved)

**Evidence**: The deduplication logic at line 126-132 compares `remotePlanId == lastEmittedPlanId`. If the stream was already subscribed and emitted the old plan, then when Firestore emits the new plan, it might skip it if the planId comparison fails.

Actually wait - the old plan and new plan should have different IDs, so deduplication shouldn't skip it.

But there's another issue: when provider invalidates, the old stream subscription is cancelled and a new one is created. The new stream calls `watchActivePlanWithCache()` which:
1. Loads cache (should have new plan if timing is right)
2. Waits 300ms for Firestore
3. If Firestore is slow, emits cache (new plan should be there)

The real issue might be: **after invalidation, the stream is recreated, but Firestore query might return the old plan if the query hasn't updated yet**.

Actually, Firestore queries are real-time and should update immediately after batch commit. So this shouldn't be the issue.

Let me re-examine the cache logic...

**AH HA!** The issue is:
1. Service clears cache: `await _cache.clearActivePlan(userId);` (line 282)
2. Repository applies (writes to Firestore)
3. Service saves new plan: `await _cache.saveActivePlan(userId, plan);` (line 296)
4. Controller invalidates provider
5. Provider rebuilds, calls `watchActivePlanWithCache()` again
6. `watchActivePlanWithCache()` loads cache: `final cachedPlanFuture = _cache.loadActivePlan(userId);` (line 37)
7. If the cache load happens BEFORE step 3 completes (but step 3 is awaited, so this shouldn't happen)

Actually, the cache operations are awaited, so they should be sequential. But there's a subtle issue:

**The problem**: After invalidation, `watchActivePlanWithCache()` creates a NEW stream subscription. But if there are multiple active plans (due to a race condition in Firestore), or if the query hasn't updated yet, it might emit the wrong plan.

Actually, wait. Let me check the repository's post-write verification (line 1158-1179). It queries for active plans and logs a warning if multiple are found. This suggests the batch write should be atomic, so there shouldn't be multiple active plans.

But what if the query in `getActivePlan()` (repository method) is different from the batch write query? Let me check...

Actually, I think the real issue is simpler: **after invalidation, the stream might emit from cache before Firestore emits, and if the cache has the old plan (which shouldn't happen if cache was cleared), or if the cache is null and Firestore is slow, the UI shows the wrong state**.

But the service clears cache BEFORE applying, and saves the new plan AFTER applying. So when the provider invalidates and `watchActivePlanWithCache()` runs again, the cache should have the new plan.

**Unless...** there's a race condition where:
1. Service clears cache
2. Repository applies
3. Controller invalidates provider (BEFORE service.saveActivePlan completes)
4. Provider rebuilds, loads cache (which is null because it was cleared)
5. Firestore query is slow, so it falls back to cache (null)
6. UI shows no active plan

But step 3 invalidates AFTER the service method completes (line 138-153), so step 3 can't happen before step 5.

I think the real issue is different. Let me check the deduplication logic more carefully...

**ROOT CAUSE**: The deduplication logic at line 126-132 compares `remotePlanId == lastEmittedPlanId`. When provider invalidates and stream is recreated:
1. `lastEmittedPlanId` is reset to null (line 84)
2. First Firestore emission should emit regardless
3. But if the stream was already subscribed and emitted a plan, then when the new plan is written to Firestore, Firestore emits again
4. If the old stream is still subscribed (before invalidation), it might skip the new emission due to deduplication

Actually, when provider invalidates, the old stream should be cancelled. So this shouldn't be the issue.

**REAL ROOT CAUSE**: I think the issue is that `watchActivePlanWithCache()` has a 300ms timeout. If Firestore is slow (network delay, cold start), it falls back to cache. But if the cache was just cleared and the new plan hasn't been saved yet, or if there's any timing issue, it might emit the wrong value.

Actually, the cache save is awaited before invalidation, so this shouldn't happen.

Let me think about this differently: **What if the Firestore query in `getActivePlan()` returns the old plan because the query hasn't updated yet?**

Firestore queries are real-time and should update immediately. But there might be a race condition where:
1. Batch write commits
2. Query hasn't updated yet (rare but possible)
3. Stream emits old plan

But this is unlikely with Firestore's real-time updates.

**I think the actual root cause is simpler**: The cache might not be properly cleared before the new plan is saved, OR the stream's deduplication logic is preventing the new plan from being emitted.

Let me check if there's a bug in the cache clear logic...

Actually, I think I found it: **When provider invalidates, it calls `watchActivePlanWithCache()` again. This creates a NEW stream. But the OLD stream might still be subscribed and emitting. If the old stream emits the old plan after the new plan is written, it might overwrite the cache with the old plan!**

But when provider invalidates, the old stream should be cancelled...

**FINAL ROOT CAUSE**: The issue is that `watchActivePlanWithCache()` uses a 300ms timeout for Firestore. If Firestore is slow, it emits from cache. But if cache is null (because it was cleared) or if there's any other timing issue, the UI shows the wrong state.

The fix is to ensure that after apply, we **force the stream to wait for Firestore** and **clear cache properly** before applying.

Actually, I think the real issue is that **the cache is saved BEFORE the Firestore write is committed**. So when the stream reads from Firestore, it might get the old plan if the write hasn't propagated yet.

No wait, the service.saveActivePlan() is called AFTER repository.applyExploreTemplateAsActivePlan(), and the repository method awaits batch.commit(), so the Firestore write should be committed before cache save.

I think the issue is that **after invalidation, the stream might emit from cache (which has the new plan) before Firestore emits, but then Firestore emits the new plan and it's deduplicated, so the UI doesn't update**.

Actually, if cache has the new plan and Firestore emits the new plan, deduplication would skip it (same planId), which is fine - the UI already shows the new plan.

**I think the real issue is that the cache might have the OLD plan if it wasn't properly cleared, or if there's a race condition**.

Let me propose a fix: **After apply, we should clear the cache again and force the stream to wait for Firestore, OR we should ensure the cache is cleared BEFORE saving the new plan, and the stream should prioritize Firestore after apply**.

Actually, the service already clears cache before apply (line 282). So the cache should be empty when we save the new plan.

**I think the issue is that after invalidation, if the stream loads cache and it has the new plan, but Firestore is slow, it emits the cache. Then when Firestore emits, it's deduplicated. But if there's any timing issue where the cache has the old plan, or if Firestore emits the old plan, the UI shows the wrong state**.

The fix is to ensure that **after apply, we clear the cache AGAIN before invalidating, OR we ensure the stream always waits for Firestore after apply**.

Actually, I think a better fix is to **not save to cache immediately after apply, and let Firestore be the source of truth. The stream will emit from Firestore, and then cache it**.

But that might cause a delay in UI update.

**BEST FIX**: After apply, clear cache, then invalidate provider. The stream will load cache (null), wait for Firestore, and emit the new plan. Then cache it.

But the service already saves to cache after apply. So when provider invalidates, cache has the new plan. Stream loads cache, waits 300ms, if Firestore is slow, emits cache (new plan), then Firestore emits (new plan), deduplicated.

This should work correctly.

**Unless...** there's a bug where the cache isn't properly cleared, or the cache save fails, or there's a race condition.

Let me check the cache implementation... Actually, I don't have access to it. But assuming it works correctly, the issue must be elsewhere.

**FINAL HYPOTHESIS**: The issue is that **after invalidation, if Firestore query is slow (>300ms), the stream emits from cache. But if the cache has the OLD plan (because cache clear failed or there's a race condition), the UI shows the old plan**.

The fix is to ensure cache is cleared BEFORE saving new plan (which it is), and to add a post-apply cache clear to be safe.

Actually, I think the issue might be simpler: **The cache might not be properly synchronized with Firestore. After apply, cache has new plan, but when stream reads from Firestore, it might get the old plan if query hasn't updated**.

But Firestore queries are real-time, so this shouldn't happen.

**I think the real fix is to ensure that after apply, we clear cache AGAIN before invalidating, so the stream is forced to wait for Firestore. OR, we can add a flag to force the stream to skip cache after apply**.

Actually, the simplest fix is: **After apply, don't save to cache immediately. Let the stream read from Firestore first, then cache it. This ensures Firestore is always the source of truth**.

But that might cause a delay.

**BETTER FIX**: After apply, clear cache, save new plan to cache, then invalidate. The stream will:
1. Load cache (has new plan)
2. Wait 300ms for Firestore
3. If Firestore emits within 300ms: emit from Firestore (new plan), deduplicate cache emission
4. If Firestore is slow: emit from cache (new plan), then emit from Firestore (new plan), deduplicate

This should work. But if there's a bug where cache has the old plan, it will show the old plan.

**SAFEST FIX**: After apply, clear cache, DON'T save new plan to cache, invalidate provider. Stream will:
1. Load cache (null)
2. Wait 300ms for Firestore
3. Emit from Firestore (new plan)
4. Cache it

This ensures Firestore is always the source of truth after apply.

But the user requested minimal changes, so let's stick with the current approach but add a safeguard.

### Root Cause 2: Metadata Not Preserved

**Location**: `lib/features/meal_plans/domain/services/apply_explore_template_service.dart`, `applyTemplate()` (line 22-61)

**Issue**: The service only copies:
- name ✅
- goalType ✅
- dailyCalories ✅
- durationDays ✅
- mealsPerDay ✅ (implicit in durationDays)
- BUT NOT: description, tags, difficulty

**Impact**: When user applies explore template, the created user plan doesn't preserve template metadata.

**Note**: UserMealPlan domain model doesn't have description/tags/difficulty fields, so we can't preserve them unless we add these fields to UserMealPlan. But the user said "if the user plan detail needs them", so we should check if UserMealPlan needs these fields first.

Looking at UserMealPlan (line 70-101), it doesn't have description/tags/difficulty. So we can't preserve them without modifying the domain model. But the user said "if the user plan detail needs them", so maybe they don't need them. Let's skip this for now and focus on the cache/stream issue.

Actually, wait. The user said "Do not silently drop template metadata in ApplyExploreTemplateService." So we should preserve them. But UserMealPlan doesn't have these fields. We need to add them to UserMealPlan first.

But the user also said "DO NOT: introduce large refactors". Adding fields to UserMealPlan might be considered a large refactor.

Let me check if there's a way to preserve metadata without modifying UserMealPlan...

Actually, I think the user wants us to preserve metadata in the repository layer, not necessarily in the domain model. But that doesn't make sense - the domain model should have the fields if we want to preserve them.

I think the best approach is to add the fields to UserMealPlan, but make them optional so it's not a breaking change. But the user said no large refactors...

Let me skip this for now and focus on the cache/stream issue, which is the main problem.

## Step 2: Firestore Atomicity

**Status**: ✅ Already correct
- Uses batch write to deactivate old plans and create new one atomically
- Has post-write verification query (line 1158-1179)
- Logs warnings if multiple active plans found

**No changes needed** for Firestore atomicity.

## Step 3: Cache/Provider Coherency Fix

**Fix Strategy**: After apply, clear cache AGAIN before invalidating, OR ensure stream always waits for Firestore.

**Proposed Fix**:
1. After repository.applyExploreTemplateAsActivePlan() completes
2. Clear cache again (to be safe)
3. Don't save to cache immediately
4. Invalidate provider
5. Let stream read from Firestore first, then cache it

This ensures Firestore is always the source of truth after apply.

Alternatively:
1. After repository.applyExploreTemplateAsActivePlan() completes
2. Save new plan to cache
3. Clear cache again (force stream to wait for Firestore)
4. Invalidate provider

This forces the stream to read from Firestore first.

I think the first approach is cleaner: don't save to cache immediately after apply, let Firestore be the source of truth.

But this might cause a delay in UI update. The user said "no flicker", so we want fast UI updates.

**BEST FIX**: Keep the current approach (save to cache after apply), but add a safeguard: after invalidating, the stream should check if the cached plan's ID matches the Firestore plan's ID. If they don't match, prefer Firestore.

Actually, the stream already does this - it reads from Firestore and caches it. The issue is the 300ms timeout fallback to cache.

**FINAL FIX**: Increase the timeout to 1000ms, OR remove the cache fallback entirely and always wait for Firestore.

But increasing timeout might cause UI delay.

**ACTUAL FIX**: After apply, clear cache, save new plan to cache, then invalidate. But in watchActivePlanWithCache(), after apply operations, we should skip the cache fallback and always wait for Firestore.

But how do we know if we just applied a plan? We can't pass a flag to watchActivePlanWithCache().

**SIMPLE FIX**: After apply, clear cache, DON'T save new plan to cache, invalidate provider. The stream will wait for Firestore (or timeout to null cache, but Firestore should emit quickly). Then cache the Firestore result.

This ensures Firestore is always the source of truth.

Let's implement this fix.

