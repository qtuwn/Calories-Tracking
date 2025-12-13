# Phase 2: Cache Stale Plan Fix - Proof Documentation

## Summary

Fixed critical bug where `watchActivePlanWithCache()` would emit stale cached plan when Firestore first emission was delayed. Now emits `null` on timeout instead of cache fallback, preventing stale data from appearing in UI.

## Diff Snippet

### File: `lib/domain/meal_plans/user_meal_plan_service.dart`

**Function: `watchActivePlanWithCache()` (lines 33-180)**

**Key Changes:**

1. **Timeout increased (line 69):**
```dart
// BEFORE:
const timeout = Duration(milliseconds: 1000);

// AFTER:
const timeout = Duration(milliseconds: 3000);
```

2. **Timeout handling - NO cache fallback (lines 73-114):**
```dart
// BEFORE:
try {
  firstRemotePlan = await firstEmissionCompleter.future.timeout(timeout);
  firestoreEmittedQuickly = true;
  // ...
} catch (e) {
  if (e is TimeoutException) {
    print('[UserMealPlanService] [ActivePlan] ⏱️ Firestore timeout (${timeout.inMilliseconds}ms), checking cache fallback');
  }
  firestoreEmittedQuickly = false;
}

// Emit cache as fallback
if (!firestoreEmittedQuickly) {
  final cachedPlan = await cachedPlanFuture;
  if (cachedPlan != null) {
    yield cachedPlan; // ❌ STALE DATA RISK
  }
}

// AFTER:
print('[ActivePlanCache] ⏳ waiting first Firestore emission timeout=${timeout.inMilliseconds}ms');

try {
  firstRemotePlan = await firstEmissionCompleter.future.timeout(timeout);
  firestoreEmittedQuickly = true;
  print('[ActivePlanCache] ✅ Firestore first emission received planId=${firstRemotePlan?.id ?? "null"}');
} catch (e) {
  if (e is TimeoutException) {
    // CRITICAL FIX: Never yield stale cache here - emit null instead
    print('[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)');
    print('[ActivePlanCache] 🔁 Will continue streaming Firestore emissions...');
  }
  firestoreEmittedQuickly = false;
}

// Emit null on timeout (NOT cache)
if (!firestoreEmittedQuickly) {
  print('[UserMealPlanService] [ActivePlan] 📦 Firestore timeout - emitting NULL (no cache fallback to prevent stale data)');
  print('[UserMealPlanService] [ActivePlan] 📡 Will continue streaming Firestore emissions...');
  yield null; // ✅ NO STALE DATA
  lastEmittedPlanId = null;
}
```

3. **Subsequent emission logging (line 141):**
```dart
// ADDED:
print('[ActivePlanCache] 🔁 Firestore subsequent emission planId=${remotePlanId ?? "null"}');
```

## Timeline Log Examples

### Scenario 1: Firestore Emits Quickly (< 3000ms)

```
[UserMealPlanService] [ActivePlan] 🔵 Setting up active plan stream for userId=user123
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
[ActivePlanCache] ✅ Firestore first emission received planId=plan456
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore (first): planId=plan456, name="New Plan"
```

### Scenario 2: Firestore Timeout (> 3000ms) - CRITICAL FIX

```
[UserMealPlanService] [ActivePlan] 🔵 Setting up active plan stream for userId=user123
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)
[ActivePlanCache] 🔁 Will continue streaming Firestore emissions...
[UserMealPlanService] [ActivePlan] 📦 Firestore timeout - emitting NULL (no cache fallback to prevent stale data)
[UserMealPlanService] [ActivePlan] 📡 Will continue streaming Firestore emissions...
[ActivePlanCache] 🔁 Firestore subsequent emission planId=plan456
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore: planId=plan456, name="New Plan", isActive=true
```

**Key difference:** In Scenario 2, we emit `null` immediately instead of stale cache, then emit the correct plan when Firestore arrives.

### Scenario 3: After Apply Operation

```
[UserMealPlanService] [ApplyExplore] 🧹 Cleared stale active plan cache
[UserMealPlanService] [ApplyExplore] ✅ Repository returned new plan: planId=newPlan789
[UserMealPlanService] [ActivePlan] 🔵 Setting up active plan stream for userId=user123
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
[ActivePlanCache] ✅ Firestore first emission received planId=newPlan789
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore (first): planId=newPlan789, name="Applied Plan"
```

**Note:** Cache is cleared before apply, so even if timeout occurred, cache would be null. But the fix ensures we never emit stale cache even if cache wasn't cleared.

## Anti-Regression Verification

### Cache Still Used for Non-Apply Paths

The cache is still used in other methods:
- `loadActivePlanOnce()` - uses cache first (line 184-195)
- `watchPlansForUserWithCache()` - emits cache first (line 201-206)
- `loadPlansForUserOnce()` - uses cache first (line 218-229)

**These are safe** because they are not called during the critical apply flow.

### Cache Still Saved After Firestore Emissions

Cache is still updated after Firestore emissions (lines 96, 148-152), ensuring:
- Fast subsequent loads use cache
- Cache is kept in sync with Firestore
- But cache is NOT used as fallback when Firestore is delayed

## Verification Checklist

- [x] Timeout increased from 1000ms to 3000ms
- [x] On timeout, emit `null` instead of cache
- [x] Continue streaming Firestore emissions after timeout
- [x] Added required timeline logs:
  - `[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms`
  - `[ActivePlanCache] ✅ Firestore first emission received planId=...`
  - `[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)`
  - `[ActivePlanCache] 🔁 Firestore subsequent emission planId=...`
- [x] No code path yields cached plan after timeout
- [x] Cache still used for non-apply paths (verified)
- [x] Cache still saved after Firestore emissions (verified)
- [x] Code compiles without errors

## Code Path Analysis

### Before Fix (BUGGY):
```
Firestore timeout → Check cache → Emit cached plan (STALE) → Firestore emits → Emit new plan
```

### After Fix (CORRECT):
```
Firestore timeout → Emit null (NO STALE) → Firestore emits → Emit new plan
```

## Phase 2 Status: ✅ COMPLETE

The critical bug is fixed:
- ✅ Timeout increased to 3000ms
- ✅ No cache fallback on timeout
- ✅ Emits null on timeout
- ✅ Continues streaming Firestore
- ✅ All required logs added
- ✅ No regression in cache usage for other paths

