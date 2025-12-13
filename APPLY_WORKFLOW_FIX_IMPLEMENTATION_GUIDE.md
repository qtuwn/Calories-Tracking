# APPLY EXPLORE TEMPLATE - BUG FIX IMPLEMENTATION GUIDE

**Status:** READY FOR IMPLEMENTATION  
**User Responsibility:** Full implementation based on detailed analysis  
**Constraint:** This is analysis only - NO CODE CHANGES MADE

---

## QUICK REFERENCE: BUG LOCATIONS

### Bug #1: Metadata Lost During Apply

**File:** `lib/features/meal_plans/domain/services/apply_explore_template_service.dart`

**Line:** 26-60 (in `applyTemplate()` method)

**Problem:**

```dart
// CURRENT (WRONG) - Missing metadata copy
return UserMealPlan(
  id: '',
  userId: userId,
  planTemplateId: template.id,
  name: template.name,                    // ✅ Copied
  goalType: goalType,                     // ✅ Copied
  type: UserMealPlanType.template,        // ✅ Copied
  startDate: startDate ?? DateTime.now(),
  currentDayIndex: 1,
  status: UserMealPlanStatus.active,
  dailyCalories: finalKcal,
  durationDays: template.durationDays,    // ✅ Copied
  isActive: setAsActive,
  createdAt: DateTime.now(),
  // ❌ MISSING: description, tags, difficulty
);
```

**Required Fix:**

1. Add fields to UserMealPlan domain model
2. Copy metadata in applyTemplate()
3. Update DTO mapping

---

### Bug #2: Cache Returns Stale Data

**File:** `lib/domain/meal_plans/user_meal_plan_service.dart`

**Line:** 33-180 (in `watchActivePlanWithCache()` async generator)

**Problem:**

```dart
// Lines 68-98: Firestore timeout handling
try {
  firstRemotePlan = await firstEmissionCompleter.future.timeout(
    const Duration(milliseconds: 1000)  // ⚠️ Too aggressive timeout
  );
  firestoreEmittedQuickly = true;
} catch (e) {
  // ⚠️ Falls back to cache on timeout
  firestoreEmittedQuickly = false;
}

// Lines 99-114: Cache fallback (THE BUG)
if (!firestoreEmittedQuickly) {
  final cachedPlan = await cachedPlanFuture;
  if (cachedPlan != null) {
    // ❌ Might be OLD plan from before apply!
    yield cachedPlan;
  } else {
    yield null;
  }
}
```

**Two Possible Fixes:**

Option A: Increase Firestore timeout

```dart
const timeout = Duration(milliseconds: 3000);  // Increased from 1000
```

Option B: Skip cache after invalidation

```dart
// At start of watchActivePlanWithCache:
final skipCache = ref.read(someProvider).isJustInvalidated;

// Then use skipCache flag to skip yielding from cache

if (firestoreEmittedQuickly && firstRemotePlan != null) {
  yield firstRemotePlan;  // Always prefer Firestore when available
}
```

---

### Bug #3: Provider Invalidation Timing

**File:** `lib/features/meal_plans/state/applied_meal_plan_controller.dart`

**Line:** 148-152 (in `applyExploreTemplate()` method)

**Problem:**

```dart
// Lines 148-151: Service completes
final newPlan = await service.applyExploreTemplateAsActivePlan(
  // ... parameters
);

// Line 152: Invalidate immediately (WRONG!)
ref.invalidate(user_meal_plan_providers.activeMealPlanProvider);

// ❌ Provider rebuilds but Firestore might not be ready yet
```

**Required Fix:**

Add small delay OR check cache is fresh:

```dart
final newPlan = await service.applyExploreTemplateAsActivePlan(...);

// OPTION 1: Small delay
await Future.delayed(Duration(milliseconds: 500));

// OPTION 2: Verify cache has new plan
final cachedPlan = await cache.loadActivePlan(userId);
if (cachedPlan?.id != newPlan.id) {
  // Cache not updated yet, try again
  await Future.delayed(Duration(milliseconds: 500));
}

// NOW safe to invalidate
ref.invalidate(user_meal_plan_providers.activeMealPlanProvider);
```

---

## DETAILED IMPLEMENTATION STEPS

### STEP 1: Add Metadata Fields to UserMealPlan

**File:** `lib/features/meal_plans/domain/models/user/user_meal_plan.dart`

**Current model (lines 1-50):**

```dart
class UserMealPlan {
  final String id;
  final String userId;
  final String? planTemplateId;
  final String name;
  final MealPlanGoalType goalType;
  final UserMealPlanType type;
  final DateTime startDate;
  final int currentDayIndex;
  final UserMealPlanStatus status;
  final int dailyCalories;
  final int durationDays;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // ❌ MISSING FIELDS
}
```

**Add these fields:**

```dart
final String? description;        // Nullable - null for custom plans
final List<String> tags;          // Empty list for custom plans
final String? difficulty;         // Nullable - null for custom plans
```

**Update constructor parameter list and copyWith() method**

---

### STEP 2: Update ApplyExploreTemplateService

**File:** `lib/features/meal_plans/domain/services/apply_explore_template_service.dart`

**Change the return statement (around line 26-60):**

From:

```dart
return UserMealPlan(
  id: '',
  userId: userId,
  planTemplateId: template.id,
  name: template.name,
  goalType: goalType,
  type: UserMealPlanType.template,
  startDate: startDate ?? DateTime.now(),
  currentDayIndex: 1,
  status: UserMealPlanStatus.active,
  dailyCalories: finalKcal,
  durationDays: template.durationDays,
  isActive: setAsActive,
  createdAt: DateTime.now(),
);
```

To:

```dart
return UserMealPlan(
  id: '',
  userId: userId,
  planTemplateId: template.id,
  name: template.name,
  description: template.description,        // ✅ ADD THIS
  tags: template.tags,                      // ✅ ADD THIS
  difficulty: template.difficulty,          // ✅ ADD THIS
  goalType: goalType,
  type: UserMealPlanType.template,
  startDate: startDate ?? DateTime.now(),
  currentDayIndex: 1,
  status: UserMealPlanStatus.active,
  dailyCalories: finalKcal,
  durationDays: template.durationDays,
  isActive: setAsActive,
  createdAt: DateTime.now(),
);
```

---

### STEP 3: Update UserMealPlanDto Mapping

**File:** `lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart`

**Find UserMealPlanDto class (search for "class UserMealPlanDto")**

**Update fromFirestore() method to include:**

```dart
description: json['description'] as String?,
tags: List<String>.from(json['tags'] as List<dynamic>? ?? []),
difficulty: json['difficulty'] as String?,
```

**Update toFirestore() method to include:**

```dart
'description': description,
'tags': tags,
'difficulty': difficulty,
```

**Update the mapping in \_domainToDto() method:**

```dart
// Find where UserMealPlanDto is created from domain model
// Add the new fields:
description: userMealPlan.description,
tags: userMealPlan.tags,
difficulty: userMealPlan.difficulty,
```

---

### STEP 4: Fix Cache Race Condition

**File:** `lib/domain/meal_plans/user_meal_plan_service.dart`

**Option A (Recommended): Increase timeout**

Find line: `const timeout = Duration(milliseconds: 1000);`

Change to: `const timeout = Duration(milliseconds: 3000);`

Add comment:

```dart
// Increased timeout to 3000ms to account for Firestore replication delays
// especially important after batch writes during plan application
```

**Option B (Alternative): Skip cache on timeout**

After line 98 (where timeout exception is caught):

```dart
// After timeout exception handling, add logic to skip cache:
if (!firestoreEmittedQuickly) {
  // Don't fall back to cache - wait for Firestore instead
  // This prevents returning stale data after apply operations
  yield null;  // Emit null until Firestore responds

  // Continue below to get Firestore data...
} else {
  // Firestore was quick - use it
  yield firstRemotePlan;
  // ... etc
}
```

---

### STEP 5: Improve Invalidation Timing

**File:** `lib/features/meal_plans/state/applied_meal_plan_controller.dart`

Find lines 148-152:

```dart
final newPlan = await service.applyExploreTemplateAsActivePlan(...);

// Add before invalidation:
// Wait for cache to stabilize with new plan
await Future.delayed(const Duration(milliseconds: 500));

ref.invalidate(user_meal_plan_providers.activeMealPlanProvider);
```

Or more robustly:

```dart
final newPlan = await service.applyExploreTemplateAsActivePlan(...);

// Verify new plan is in cache before invalidating
bool cacheUpdated = false;
for (int i = 0; i < 5; i++) {  // Try up to 5 times
  final cachedPlan = await _cache.loadActivePlan(userId);
  if (cachedPlan?.id == newPlan.id) {
    cacheUpdated = true;
    break;
  }
  await Future.delayed(const Duration(milliseconds: 100));
}

if (cacheUpdated) {
  ref.invalidate(user_meal_plan_providers.activeMealPlanProvider);
} else {
  // Log warning - cache not updated but proceed anyway
  debugPrint('Warning: Cache not updated after apply, but proceeding...');
  ref.invalidate(user_meal_plan_providers.activeMealPlanProvider);
}
```

---

## IMPLEMENTATION SEQUENCE

### Phase 1: Foundation (30 minutes)

1. Add fields to UserMealPlan domain model
2. Update constructor + copyWith()
3. Update equality check
4. Update toString() method

### Phase 2: Data Layer (20 minutes)

1. Update UserMealPlanDto mapping
2. Update applyTemplate() service
3. Test Firestore read/write with new fields

### Phase 3: Service Layer (15 minutes)

1. Fix watchActivePlanWithCache() timeout or cache skip logic
2. Test with slow network simulation

### Phase 4: Controller Layer (10 minutes)

1. Add delay/verification before invalidation
2. Test apply workflow end-to-end

### Phase 5: Testing (30 minutes)

1. Metadata preservation test
2. Cache coherency test (slow network)
3. Multiple apply test
4. Admin dashboard display test

---

## VERIFICATION AFTER FIXES

### Test 1: Metadata Flows Through Apply

```dart
// In test:
final template = ExploreMealPlan(
  description: 'Test description',
  tags: ['Tag1', 'Tag2'],
  difficulty: 'hard',
  // ... other fields
);

await repository.applyExploreTemplateAsActivePlan(...);

// Query the new plan
final appliedPlan = await getActivePlan(userId).first;

assert(appliedPlan.description == 'Test description');
assert(appliedPlan.tags.contains('Tag1'));
assert(appliedPlan.difficulty == 'hard');
```

### Test 2: Cache Returns Fresh Data

```dart
// Simulate slow Firestore
// Mock Firestore to delay 2000ms before emitting

await applyTemplate(...);

// Provider rebuilds
final planAsync = ref.watch(activeMealPlanProvider);

// Should get NEW plan, not OLD
assert(planAsync.data == newPlan);
assert(planAsync.data != oldPlan);
```

### Test 3: Multiple Applies Work

```dart
// Apply template A
await applyTemplate(templateA);
var plan = await getActivePlan(userId).first;
assert(plan.name == 'Template A');

// Apply template B immediately
await applyTemplate(templateB);
plan = await getActivePlan(userId).first;
assert(plan.name == 'Template B');

// Verify only ONE active plan
final allPlans = await getAllPlans(userId).first;
final activePlans = allPlans.where((p) => p.isActive).toList();
assert(activePlans.length == 1);
```

---

## EXPECTED OUTCOME

After implementing all 3 fixes:

✅ User clicks "Bắt đầu" on explore template  
✅ Snackbar shows "Áp dụng thành công"  
✅ User navigates to "Thực đơn của bạn"  
✅ **NEW template plan is shown** (not old custom plan)  
✅ Template name, description, tags, difficulty all display correctly  
✅ Plan details show all metadata from template  
✅ Apply works reliably on all networks (fast & slow)

---

## DEBUGGING TIPS

### If apply still shows old plan after fix:

1. Check Firestore:

   - Open Firebase Console
   - Navigate to `users/{userId}/user_meal_plans`
   - Verify only ONE plan has `isActive: true`
   - Verify new plan has correct `description`, `tags`, `difficulty`

2. Check cache:

   - Add logging to `watchActivePlanWithCache()`
   - Log which plan is emitted: cached vs Firestore
   - Verify cache is cleared before apply

3. Check controller:
   - Log before/after invalidation
   - Log what activeMealPlanProvider emits
   - Verify UI receives correct plan

### Enable debug logging:

All files have extensive `debugPrint()` statements. In VS Code:

- Run `flutter run` in debug mode
- Search output for `[UserMealPlanService]` or `[ActivePlan]`
- Follow the timeline to see where things go wrong

---

## RISK ASSESSMENT

### Risk 1: Breaking Custom Plans

**Mitigation:** Make new fields nullable; custom plans have null/empty values

### Risk 2: Firestore Data Compatibility

**Mitigation:** Old plans in Firestore won't have new fields - code handles nulls

### Risk 3: Cache Timeout Increase

**Mitigation:** 3000ms is still fast, Firestore usually emits in <500ms

### Risk 4: Timing Delay in Apply

**Mitigation:** 500ms delay is negligible to user experience

---

## SUCCESS CRITERIA

All of these must pass:

- [ ] New explore template apply shows correct plan in "Thực đơn của bạn"
- [ ] Metadata (description, tags, difficulty) persists to user plan
- [ ] Admin dashboard displays metadata
- [ ] Works on slow networks (3G simulation)
- [ ] Only one plan is active at a time
- [ ] Custom plans still work normally
- [ ] Multiple consecutive applies work correctly
- [ ] No crashes or uncaught exceptions
