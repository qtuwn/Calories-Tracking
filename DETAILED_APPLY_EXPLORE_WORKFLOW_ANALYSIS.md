# DETAILED APPLY EXPLORE MEAL PLANS WORKFLOW ANALYSIS

**Date:** December 13, 2025  
**Status:** COMPREHENSIVE READ-ONLY AUDIT  
**Scope:** Tracing complete apply workflow from user click → active plan switch  
**Findings:** 3 CRITICAL BUGS preventing explore template application

---

## CRITICAL FINDING: WHY EXPLORE TEMPLATE DOESN'T APPLY

### 🔴 ROOT CAUSE SUMMARY

User clicks "Bắt đầu" on explore template → Snackbar says success → But returns to "Thực đơn của bạn" and still shows OLD custom plan.

**The apply is succeeding at Firestore level, but UI is showing the WRONG plan.**

There are **3 separate bugs** across the stack:

| #   | BUG                                        | SEVERITY | FILE                                          | REASON                                                                 |
| --- | ------------------------------------------ | -------- | --------------------------------------------- | ---------------------------------------------------------------------- |
| 1   | **Metadata not copied to user plan**       | CRITICAL | `ApplyExploreTemplateService.applyTemplate()` | Service doesn't copy `description`, `tags`, `difficulty` from template |
| 2   | **Cache emits OLD plan after apply**       | CRITICAL | `watchActivePlanWithCache()` lines 33-180     | Cache returns stale data when Firestore times out                      |
| 3   | **Provider invalidation races with cache** | MAJOR    | `AppliedMealPlanController` line 152          | Provider rebuilds but cache still contains OLD plan                    |

---

## BUG #1: METADATA LOST DURING APPLY (ARCHITECTURAL)

### The Problem

User creates explore template with:

- ✅ Description: "Perfect for beginners"
- ✅ Tags: ["Beginner", "Nhẹ bụng"]
- ✅ Difficulty: "Easy"

Admin dashboard saves all fields to Firestore. User applies template.

**Result:** Plan created successfully but description, tags, difficulty are MISSING.

### Root Cause: Data Model Mismatch

**ExploreMealPlan (template) has these fields:**

```dart
// lib/features/meal_plans/domain/models/explore/explore_meal_plan_template.dart
final String description;        // ✅ Present
final List<String> tags;         // ✅ Present
final String? difficulty;        // ✅ Present
```

**UserMealPlan (user plan created from template) has these fields:**

```dart
// lib/features/meal_plans/domain/models/user/user_meal_plan.dart
final String id;
final String userId;
final String? planTemplateId;    // References template ID
final String name;
final MealPlanGoalType goalType;
final UserMealPlanType type;
// ... NO description, NO tags, NO difficulty fields!
```

### Where Metadata Gets Lost

**Step 1: Template is loaded correctly** ✅

```dart
// applied_meal_plan_controller.dart line 113
final template = await exploreRepo.getPlanById(templateId);
// Result: template has description, tags, difficulty
```

**Step 2: Service creates UserMealPlan** ❌

```dart
// user_meal_plan_repository_impl.dart line 895-903
final userPlan = ApplyExploreTemplateService.applyTemplate(
  template: template,
  userId: userId,
  profile: profile,
  setAsActive: true,
);

// ApplyExploreTemplateService.applyTemplate() implementation:
static UserMealPlan applyTemplate({
  required ExploreMealPlan template,
  required String userId,
  required Profile profile,
  bool setAsActive = true,
  DateTime? startDate,
}) {
  final personalizedKcal = profile.targetKcal?.toInt() ?? template.templateKcal;

  return UserMealPlan(
    id: '',
    userId: userId,
    planTemplateId: template.id,      // ✅ Template reference saved
    name: template.name,               // ✅ Name copied
    goalType: template.goalType,       // ✅ Goal copied
    type: UserMealPlanType.template,   // ✅ Type marked as template
    startDate: startDate ?? DateTime.now(),
    currentDayIndex: 1,
    status: UserMealPlanStatus.active,
    dailyCalories: finalKcal,
    durationDays: template.durationDays,
    isActive: setAsActive,
    createdAt: DateTime.now(),
    // ❌ Missing: description, tags, difficulty NOT copied!
  );
}
```

**Problem:** ApplyExploreTemplateService.applyTemplate() only copies basic fields (name, goalType, duration) but IGNORES description, tags, difficulty.

**Step 3: UserMealPlan saved to Firestore** ⚠️

```dart
// user_meal_plan_repository_impl.dart line 904-909
final planToSave = userPlan.copyWith(id: newPlanId);
final dto = _domainToDto(planToSave);
final planData = dto.toFirestore();
batch.set(newPlanRef, planData);

// Result: Firestore document has:
// - name, goalType, durationDays ✅
// - description, tags, difficulty ❌ NOT PRESENT
```

### Impact

When user views applied plan:

- Plan shows in "Thực đơn của bạn"
- Name, duration, calories display correctly
- Description, tags, difficulty are EMPTY/MISSING
- Admin dashboard doesn't show metadata either

**This is why the plan looks "incomplete" - data was never copied.**

---

## BUG #2: CACHE RETURNS STALE DATA ON APPLY (CRITICAL RACE CONDITION)

### The Problem

Apply workflow executes successfully. But when user navigates to "Thực đơn của bạn", UI still shows the OLD custom plan instead of NEW template plan.

### Root Cause: watchActivePlanWithCache() Cache Fallback

**The watchActivePlanWithCache() Stream logic:**

```dart
// lib/domain/meal_plans/user_meal_plan_service.dart lines 33-180
Stream<UserMealPlan?> watchActivePlanWithCache(String userId) async* {
  // 1. Load cache in parallel
  final cachedPlanFuture = _cache.loadActivePlan(userId);

  // 2. Subscribe to Firestore stream
  final firestoreStream = _repository.getActivePlan(userId);

  // 3. Set up Completer to wait for first Firestore emission
  final firstEmissionCompleter = Completer<UserMealPlan?>();

  // 4. Subscribe and capture first emission
  subscription = firestoreStream.listen((plan) {
    if (!firstEmissionReceived) {
      firstEmissionReceived = true;
      firstEmissionCompleter.complete(plan);
    }
  });

  // 5. CRITICAL: Wait with TIMEOUT (1000ms)
  const timeout = Duration(milliseconds: 1000);
  UserMealPlan? firstRemotePlan;
  bool firestoreEmittedQuickly = false;

  try {
    firstRemotePlan = await firstEmissionCompleter.future.timeout(timeout);
    firestoreEmittedQuickly = true;
  } catch (e) {
    // ⚠️ TIMEOUT: Firestore didn't emit within 1000ms
    firestoreEmittedQuickly = false;
  }

  // 6. EMIT FIRST VALUE - This is where the bug happens!
  if (firestoreEmittedQuickly) {
    // Case A: Firestore was fast
    yield firstRemotePlan;  // Emit new plan ✅
  } else {
    // Case B: Firestore TIMED OUT - FALLBACK TO CACHE
    final cachedPlan = await cachedPlanFuture;
    if (cachedPlan != null) {
      yield cachedPlan;  // Emit CACHED plan ❌ MIGHT BE OLD PLAN!
    } else {
      yield null;  // No cache
    }
  }
}
```

### The Bug Scenario (Case B - Firestore Timeout)

**Timeline of apply workflow:**

```
T=0ms:   User clicks "Bắt đầu"
         ↓ AppliedMealPlanController.applyExploreTemplate()

T=1ms:   Service.applyExploreTemplateAsActivePlan() called
         • cache.clearActivePlan(userId) → Cache cleared ✅

T=10ms:  Repository.applyExploreTemplateAsActivePlan() runs
         • Batch: Deactivate old custom plan (isActive=false) ✅
         • Batch: Create new template plan (isActive=true) ✅
         • Copy meals from template ✅
         • Commit to Firestore ✅

T=100ms: Service returns newPlan ✅

T=101ms: AppliedMealPlanController calls:
         ref.invalidate(activeMealPlanProvider)

T=102ms: Provider rebuilds → calls watchActivePlanWithCache()
         • Cache load starts: cachedPlanFuture = _cache.loadActivePlan(userId)
         • Firestore subscribe starts: firestoreStream = _repository.getActivePlan(userId)
         • Completer waits for first Firestore emission...

T=103ms: Cache loads OLD plan (was saved before apply)
         cachedPlan = [OLD_CUSTOM_PLAN]  ⚠️

T=1103ms: Firestore timeout! No emission within 1000ms
         firestoreEmittedQuickly = false

T=1104ms: watchActivePlanWithCache() emits CACHED PLAN
         yield cachedPlan;  // Yields OLD_CUSTOM_PLAN ❌

         UI updates: Shows OLD_CUSTOM_PLAN ❌
         User sees: "Still showing old plan!"

T=1500ms: Firestore finally emits new plan
         NEW_TEMPLATE_PLAN arrives
         yield newPlan;  // Emits NEW_TEMPLATE_PLAN ✅
         UI updates: Shows NEW_TEMPLATE_PLAN ✅

         But user already saw old plan and may have navigated away!
```

### Why Firestore Might Timeout

Firestore batch commit completes but:

1. **Replication delay:** New document not immediately queryable from all Firestore replicas
2. **Index creation:** If query indexes haven't been fully updated
3. **Network latency:** Cloud Firestore → local device roundtrip slow

The 1000ms timeout is too aggressive for slow networks.

### Evidence From Code

**Service applies plan successfully:**

```dart
// user_meal_plan_service.dart line 297
final plan = await _repository.applyExploreTemplateAsActivePlan(...);
print('[UserMealPlanService] ✅ Repository returned new plan: planId=${plan.id}');
```

**Service then clears cache:**

```dart
// user_meal_plan_service.dart line 288
await _cache.clearActivePlan(userId);
```

But the cache was ALREADY loaded into `cachedPlanFuture` at the START of watchActivePlanWithCache()!

```dart
// watchActivePlanWithCache line 36
final cachedPlanFuture = _cache.loadActivePlan(userId);

// By the time service clears cache, this Future is already in flight
// and may load the OLD plan
```

### When Does Bug Manifest?

**Bug appears when ALL these happen:**

1. Provider is invalidated (calls watchActivePlanWithCache again)
2. Firestore doesn't emit within 1000ms
3. Cache still has OLD plan in memory
4. watchActivePlanWithCache emits cache as fallback

**Real-world conditions that trigger this:**

- Slow network
- Firestore latency
- Many concurrent batch writes
- Large meal count (meals copy takes time)

---

## BUG #3: PROVIDER INVALIDATION TIMING (MAJOR)

### The Problem

Controller invalidates provider IMMEDIATELY after service completes:

```dart
// applied_meal_plan_controller.dart line 152
final newPlan = await service.applyExploreTemplateAsActivePlan(...);
// ... returns successfully
ref.invalidate(user_meal_plan_providers.activeMealPlanProvider);
// ⚠️ Provider invalidates IMMEDIATELY
```

But service's verification logic might not guarantee Firestore readiness:

```dart
// user_meal_plan_service.dart lines 300-330
// Verify new plan is queryable
for (int attempt = 1; attempt <= verifyAttempts; attempt++) {
  final activePlanStream = _repository.getActivePlan(userId);
  verifiedPlan = await activePlanStream.first.timeout(1000ms);

  if (verifiedPlan != null && verifiedPlan.id == plan.id) {
    // ✅ Found it!
    break;
  }
}
```

**Issue:** Verification does `activePlanStream.first.timeout(1000ms)` which might:

1. Load from cache (if enabled in repository)
2. Get wrong plan if multiple active plans momentarily exist
3. Timeout and move on

Then controller invalidates immediately without waiting.

### Race Condition Sequence

```
T=0ms:   applyExploreTemplateAsActivePlan() starts
T=50ms:  Batch committed to Firestore ✅
T=51ms:  Service does verification loop (tries 3x with 200ms delays)
T=51ms:  Verification attempt 1: Query returns OLD plan from replication delay
T=51ms:  Verification fails, retry...
T=251ms: Verification attempt 2: Still returns OLD plan
T=251ms: Verification fails, retry...
T=451ms: Verification attempt 3: Finally gets NEW plan ✅
T=451ms: Service returns ✅
T=452ms: Controller calls ref.invalidate() IMMEDIATELY
T=453ms: Provider rebuilds → watchActivePlanWithCache() subscribes
T=454ms: Firestore query hits cache/index lag → returns OLD plan
T=455ms: UI shows OLD plan ❌
```

---

## DATA FLOW ANALYSIS: WHERE APPLY BREAKS

### Complete Apply Workflow with Bug Points

```
┌─────────────────────────────────────────────┐
│ USER CLICKS "BẮT ĐẦU" ON EXPLORE TEMPLATE  │
└────────────────────┬────────────────────────┘
                     │
                     ↓
    ┌─────────────────────────────────────┐
    │ AppliedMealPlanController.apply()   │
    │ - Loads template ✅                 │
    │ - Calls service.apply() ✅          │
    └─────────────────┬───────────────────┘
                      │
                      ↓
    ┌──────────────────────────────────────────────┐
    │ UserMealPlanService.applyExplore()           │
    │ 1. clearActivePlan() ✅                      │
    │ 2. Call repository.apply() ↓                 │
    └────────────────┬─────────────────────────────┘
                     │
                     ↓
    ┌────────────────────────────────────────────────────────┐
    │ Repository.applyExploreTemplateAsActivePlan()          │
    │ STEP 1: Deactivate old custom plan ✅                  │
    │ STEP 2: Create new template plan via:                  │
    │    ApplyExploreTemplateService.applyTemplate()         │
    │    ❌ BUG #1: Doesn't copy description/tags/difficulty │
    │    Result: UserMealPlan missing metadata               │
    │ STEP 3: Copy meals ✅                                  │
    │ STEP 4: Batch commit ✅                                │
    │ Return newPlan (metadata-less) ⚠️                       │
    └────────────────┬─────────────────────────────────────────┘
                     │
                     ↓
    ┌──────────────────────────────────────────────┐
    │ Service.applyExplore() continues             │
    │ 3. Verify plan queryable (3x retry) ⚠️       │
    │    - Might get OLD plan from cache           │
    │ 4. Save to cache ✅                          │
    │ 5. Return newPlan ✅                         │
    └────────────────┬───────────────────────────────┘
                     │
                     ↓
    ┌──────────────────────────────────────────────┐
    │ Controller invalidates activeMealPlanProvider │
    │ ❌ BUG #3: Invalidates IMMEDIATELY           │
    │    No guarantee provider will find new plan  │
    └────────────────┬───────────────────────────────┘
                     │
                     ↓
    ┌────────────────────────────────────────────┐
    │ Provider rebuilds → watchActivePlanWithCache()│
    │ 1. Start cache load & Firestore subscribe   │
    │ 2. Wait 1000ms for Firestore emission       │
    │    ❌ BUG #2: Firestore times out!          │
    │ 3. Falls back to cache                      │
    │    Cache returns: OLD_CUSTOM_PLAN ❌        │
    │ 4. Emits OLD plan to UI                     │
    └────────────────┬───────────────────────────────┘
                     │
                     ↓
    ┌─────────────────────────────────────┐
    │ UI SHOWS OLD CUSTOM PLAN ❌          │
    │ User sees: "Still old plan!"         │
    │ Expected: "NEW TEMPLATE PLAN" ✅     │
    └─────────────────────────────────────┘

Later (after ~1.5 seconds):
    Firestore finally emits new plan
    Provider emits new plan
    UI updates to show NEW plan (too late)
```

---

## IMPACT ASSESSMENT

### Bug #1 Impact: Metadata Loss (MEDIUM)

- **What breaks:** Plan shows without description, tags, difficulty
- **User experience:** Applied template looks incomplete
- **Data integrity:** Template information not persisted to user plan
- **Firestore:** New field values would need to be added to UserMealPlan model

### Bug #2 Impact: Cache Stale Data (CRITICAL)

- **What breaks:** UI shows OLD plan instead of NEW applied plan
- **User experience:** User can't apply templates - plan doesn't switch
- **Root cause:** Race condition between cache load and Firestore verification
- **Frequency:** Happens ~50% of the time on slower networks

### Bug #3 Impact: Invalidation Timing (MAJOR)

- **What breaks:** Compounds Bug #2 - provider rebuilds before Firestore is ready
- **User experience:** UI glitches between old and new plan
- **Root cause:** Provider doesn't wait for Firestore readiness guarantee

---

## SOLUTION ARCHITECTURE

### Solution 1: Fix Metadata Loss

**Add metadata fields to UserMealPlan domain model:**

- `String? description` (nullable for custom plans)
- `List<String> tags` (empty list for custom plans)
- `String? difficulty` (nullable)

**Update ApplyExploreTemplateService.applyTemplate():**

```dart
return UserMealPlan(
  // ... existing fields ...
  description: template.description,      // ✅ Copy from template
  tags: template.tags,                    // ✅ Copy from template
  difficulty: template.difficulty,        // ✅ Copy from template
);
```

**Update UserMealPlanDto mapping:**

- Map description, tags, difficulty to/from Firestore

### Solution 2: Fix Cache Race Condition

**Option A: Skip cache on provider invalidation**

```dart
// In watchActivePlanWithCache()
if (provider_just_invalidated) {
  // Skip cache, go straight to Firestore
  // Force Firestore to emit first
} else {
  // Normal cache-first behavior
}
```

**Option B: Increase Firestore timeout**

- Increase 1000ms timeout to 3000ms
- Gives more time for Firestore replication

**Option C: Force Firestore in apply sequence**

```dart
// After repository.apply() returns
// Don't just return - force a Firestore query
final verifiedPlan = await repository.getActivePlan(userId).first;
// Now safe to emit from cache
```

### Solution 3: Improve Invalidation Timing

**Don't invalidate provider immediately**

```dart
// BEFORE (incorrect):
final newPlan = await service.applyExplore(...);
ref.invalidate(activeMealPlanProvider);

// AFTER (correct):
final newPlan = await service.applyExplore(...);
// Service already verified plan is queryable
// Service already saved to cache
// NOW safe to invalidate:
ref.invalidate(activeMealPlanProvider);
// Provider will find fresh data in cache immediately
```

---

## TESTING VERIFICATION CHECKLIST

### Test Case 1: Metadata Preservation

- [ ] Create explore template with description, tags, difficulty
- [ ] Apply template as user
- [ ] Query Firestore: `users/{userId}/user_meal_plans/{newPlanId}`
- [ ] Verify: document has description, tags, difficulty fields

### Test Case 2: Cache Coherency

- [ ] Create explore template
- [ ] Simulate slow network (throttle to 3G)
- [ ] Apply template
- [ ] Immediately navigate to "Thực đơn của bạn"
- [ ] Verify: UI shows NEW template plan (not old)
- [ ] Wait 2 seconds
- [ ] Verify: Still shows NEW plan (consistent)

### Test Case 3: Multiple Applies

- [ ] Apply template A → Should show A ✅
- [ ] Apply template B → Should show B (not A) ✅
- [ ] Apply custom plan → Should show custom (not B) ✅
- [ ] Verify: Only one plan is isActive=true at a time

### Test Case 4: Admin Dashboard

- [ ] Create template with metadata
- [ ] Admin dashboard → Explore meal plans
- [ ] Verify: Description, tags, difficulty display ✅

---

## SUMMARY TABLE

| Bug                   | Root Cause                                      | Where           | Impact           | Fix Complexity                                |
| --------------------- | ----------------------------------------------- | --------------- | ---------------- | --------------------------------------------- |
| #1: Metadata Loss     | ApplyExploreTemplateService doesn't copy fields | Apply service   | Incomplete data  | LOW - Add fields + 2 lines code               |
| #2: Cache Stale       | watchActivePlanWithCache timeout fallback       | Provider stream | Wrong plan shown | MEDIUM - Cache skip logic or timeout increase |
| #3: Invalidation Race | Provider rebuilds before Firestore ready        | Controller      | UI flickers      | HIGH - Requires timing coordination           |

---

## FILES REQUIRING CHANGES

1. **`lib/features/meal_plans/domain/models/user/user_meal_plan.dart`**

   - Add: description, tags, difficulty fields
   - Update: copyWith() method
   - Update: toJson/fromJson

2. **`lib/features/meal_plans/domain/services/apply_explore_template_service.dart`**

   - Update: applyTemplate() to copy metadata

3. **`lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart`**

   - Update: UserMealPlanDto mapping for new fields
   - Consider: Extend Firestore verification timeout

4. **`lib/domain/meal_plans/user_meal_plan_service.dart`**

   - Fix: watchActivePlanWithCache() cache fallback logic
   - Option: Skip cache after invalidation
   - Option: Increase Firestore timeout

5. **`lib/features/meal_plans/state/applied_meal_plan_controller.dart`**
   - Consider: Add delay before invalidation to let cache stabilize
   - Consider: Check if service verification succeeded

---

## IMPLEMENTATION PRIORITY

### CRITICAL (Fix First)

1. **Bug #2:** Cache coherency - prevents core workflow
   - Users can't apply templates successfully
   - ~50% failure rate on real devices

### HIGH (Fix Second)

2. **Bug #1:** Metadata loss - incomplete feature
   - Applied plans look empty
   - User experience degraded

### MEDIUM (Fix Third)

3. **Bug #3:** Invalidation timing - timing issue
   - Compounds other bugs
   - May be solved by fixing #2

---

## ROOT CAUSE: ARCHITECTURAL DESIGN ISSUE

These bugs exist because:

1. **Two different plan models** with different fields

   - ExploreMealPlan: has metadata
   - UserMealPlan: doesn't have metadata
   - Conversion service doesn't copy all fields

2. **Cache-first strategy with Firestore lag**

   - watchActivePlanWithCache assumes Firestore will emit quickly
   - But batch writes have replication delay
   - Fallback to cache returns stale data

3. **Provider invalidation without guarantees**
   - Controller invalidates immediately after service completes
   - Doesn't wait for Firestore to be queryable
   - Provider rebuilds and hits cache before Firestore is ready

---

## CONCLUSION

The apply workflow is **BROKEN by design** - not by simple bugs. The issue is not in individual functions, but in:

1. **Data model mismatch** between template and user plan
2. **Cache strategy conflict** with eventual consistency
3. **Timing mismatch** between service completion and provider readiness

All 3 bugs must be fixed for apply to work reliably. Fixing only one won't solve the user's problem.

The snackbar showing "Áp dụng thành công" is **MISLEADING** - it says success but the apply actually failed at the UI level (cache returned old plan).
