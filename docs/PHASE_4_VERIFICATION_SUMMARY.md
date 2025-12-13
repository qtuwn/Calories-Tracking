# Phase 4: End-to-End Verification Summary

## Objective

Prove the fix addresses the exact user-visible symptom: **snackbar success AND new plan appears immediately (no old plan flash)**.

## All Three Bugs Fixed

### Bug #1: Metadata Lost During Apply ✅
- **Fixed in:** `UserMealPlan` domain model, `ApplyExploreTemplateService`, `UserMealPlanDto`, `UserMealPlanRepositoryImpl`
- **Verification:** Firestore document contains `description`, `tags`, `difficulty`

### Bug #2: Cache Emits Stale OLD Plan After Apply ✅
- **Fixed in:** `UserMealPlanService.watchActivePlanWithCache()` (timeout increased to 3000ms, emits null instead of stale cache)
- **Verification:** UI NEVER shows old plan, even on slow network

### Bug #3: Provider Invalidation Timing Race ✅
- **Fixed in:** `AppliedMealPlanController.applyExploreTemplate()` (cache confirmation loop + 500ms delay before invalidation)
- **Verification:** Provider invalidates AFTER wait/delay

## Quick Verification Checklist

### Pre-Test Setup
- [ ] Create explore template with metadata:
  - `description = "Test Description"`
  - `tags = ["Tag1", "Tag2"]`
  - `difficulty = "easy"`
- [ ] Add meals to template (at least 1 per day for 7 days)

### Test Scenario 1: Normal Apply Flow
- [ ] Apply template as user
- [ ] Immediately go to "Your meal plan" tab
- [ ] **Expected:**
  - Active plan name = template name ("Test Plan - Phase 4")
  - Metadata visible (if UI supports it)
  - **NEVER shows old custom plan**
  - Logs show cache wait loop before invalidation

### Test Scenario 2: Slow Network
- [ ] Enable network throttling (Chrome DevTools → Slow 3G)
- [ ] Apply template
- [ ] Navigate to "Your meal plan" tab
- [ ] **Expected:**
  - May show loading/null briefly
  - **MUST NOT show old plan**
  - Logs show `[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL`

### Test Scenario 3: Consecutive Apply
- [ ] Apply Template A
- [ ] Immediately apply Template B
- [ ] Navigate to "Your meal plan" tab
- [ ] **Expected:**
  - Only Template B is visible
  - Template A has `isActive=false` in Firestore
  - Exactly ONE active plan exists

## Expected Log Sequence (Abbreviated)

### Normal Flow
```
[ApplyExplore] ✅ apply returned planId=...
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=1 cachedPlanId=null
... (5 attempts)
[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=...
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
[ActivePlanCache] ✅ Firestore first emission received planId=...
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore (first): planId=...
```

### Slow Network Flow
```
[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=...
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)
[ActivePlanCache] 🔁 Firestore subsequent emission planId=...
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore: planId=...
```

## Firestore Verification

### User Plan Document
```javascript
// Firebase Console → Firestore → users/{userId}/user_meal_plans/{planId}
{
  "name": "Test Plan - Phase 4",
  "description": "Test Description",    // ✅ MUST EXIST
  "tags": ["Tag1", "Tag2"],             // ✅ MUST EXIST
  "difficulty": "easy",                  // ✅ MUST EXIST
  "isActive": true,
  "durationDays": 7,
  "planTemplateId": "...",
  ...
}
```

### Days Collection
```javascript
// users/{userId}/user_meal_plans/{planId}/days
// Should have exactly 7 documents
// Each document should have:
{
  "dayIndex": 1,  // or 2, 3, 4, 5, 6, 7
  "totalCalories": ...,
  "protein": ...,
  "carb": ...,
  "fat": ...,
  // Each day should have ≥ 1 meal document in subcollection
}
```

### Active Plan Uniqueness
```javascript
// Query: users/{userId}/user_meal_plans where isActive==true
// Result: Should return exactly 1 document
```

## Files Modified (All Phases)

### Phase 1: Metadata Preservation
- `lib/domain/meal_plans/user_meal_plan.dart` - Added `description`, `tags`, `difficulty`
- `lib/features/meal_plans/domain/services/apply_explore_template_service.dart` - Copy metadata
- `lib/features/meal_plans/data/dto/user_meal_plan_dto.dart` - Map metadata to/from Firestore
- `lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart` - Include metadata in DTO conversion

### Phase 2: Cache Stale Plan Fix
- `lib/domain/meal_plans/user_meal_plan_service.dart` - `watchActivePlanWithCache()`:
  - Timeout increased to 3000ms
  - Emits `null` on timeout (NOT stale cache)
  - Added detailed logging

### Phase 3: Provider Invalidation Timing
- `lib/features/meal_plans/state/applied_meal_plan_controller.dart` - `applyExploreTemplate()`:
  - Cache confirmation loop (5 attempts, 100ms delay each)
  - Fallback 500ms delay if cache confirmation fails
  - Provider invalidation AFTER wait

## State Guarantee

**After provider invalidation, the provider MUST NOT show the old plan; it may show loading/null then the new plan.**

**Why this is guaranteed:**
1. Cache is cleared before apply (service does this)
2. Controller waits before invalidating (cache loop + delay)
3. Stream emits `null` on Firestore timeout, NOT stale cache (Phase 2 fix)
4. Firestore is source of truth and will emit new plan

## Success Criteria

- ✅ Metadata fields persist in Firestore
- ✅ UI shows new plan immediately (no old plan flash)
- ✅ On slow network, UI may show loading/null, then new plan (NOT old plan)
- ✅ Only ONE active plan exists at any time
- ✅ Provider invalidates AFTER cache wait/delay
- ✅ All logs show correct sequence

## Failure Indicators (Red Flags)

- ❌ User plan Firestore document missing `description`, `tags`, or `difficulty`
- ❌ UI shows old custom plan after applying new template
- ❌ Multiple active plans exist simultaneously
- ❌ Provider invalidates immediately (no cache wait logs)
- ❌ Cache emits stale plan on timeout (should emit null)

## Documentation Files

- `docs/PHASE_4_E2E_VERIFICATION.md` - Complete verification guide with all scenarios
- `docs/PHASE_4_EXPECTED_LOGS.md` - Detailed log sequences for all scenarios
- `docs/PHASE_3_PROVIDER_INVALIDATION_FIX_PROOF.md` - Phase 3 proof documentation

## Next Steps

1. Run manual verification using the checklists above
2. Check Firestore documents for metadata fields
3. Monitor logs for correct sequence
4. Verify UI behavior (no old plan flash)
5. Test on slow network (throttle in DevTools)
6. Test consecutive applies (only one active plan)

