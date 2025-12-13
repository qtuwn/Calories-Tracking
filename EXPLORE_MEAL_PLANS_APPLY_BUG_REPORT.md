# APPLY EXPLORE MEAL PLANS - BUG REPORT & ANALYSIS

**Date:** 2024-12-13  
**Status:** ANALYSIS ONLY (READ-ONLY AUDIT)  
**Symptom:** User cannot apply explore meal plans - "Áp dụng thành công" notification appears but plan does not activate

---

## EXECUTIVE SUMMARY

There are **2 distinct workflows with 2 different bug categories:**

1. **Form/Create Workflow:** Description, tags, difficulty fields are captured but NOT displayed
2. **Apply Workflow:** Apply appears successful but user's active plan doesn't switch to template

The issues are **ARCHITECTURAL** - not simple field mappings. Both workflows have incomplete data flow chains.

---

## BUG CATEGORY 1: MISSING DISPLAY OF FORM FIELDS

### Fields Captured But Not Displayed

| Field           | Form Captured     | Stored in DB          | Displayed in Detail   | Displayed in Admin |
| --------------- | ----------------- | --------------------- | --------------------- | ------------------ |
| **Description** | ✅ TextFormField  | ✅ `plan.description` | ✅ Yes (line 121-123) | ❌ NO              |
| **Tags**        | ✅ TextFormField  | ✅ `plan.tags[]`      | ✅ Yes (line 147-157) | ❌ NO              |
| **Difficulty**  | ✅ DropdownButton | ✅ `plan.difficulty`  | ❌ NO                 | ❌ NO              |

### Where Data Is Lost

#### A. Form Page (CAPTURE POINT - WORKING)

**File:** `explore_meal_plan_form_page.dart` (lines 1-401)

- Lines 40-50: Form fields properly initialized
- Lines 131-146: Description captured in TextFormField
- Lines 201-215: Tags captured and parsed into list
- Lines 216-232: Difficulty selected in DropdownButton
- Lines 293-330: All fields properly saved to ExploreMealPlan object

✅ **STATUS:** Form correctly captures all fields

#### B. Detail Display Page (PARTIAL - SOME MISSING)

**File:** `meal_detail_page.dart` (lines 1-1605)

**TEMPLATE DETAIL VIEW (lines 65-350):**

```dart
// Lines 121-123: Description displayed ✅
if (template.description.isNotEmpty)
  Text(template.description, style: ...)

// Lines 147-157: Tags displayed ✅
if (template.tags.isNotEmpty) ...[
  Wrap(
    children: template.tags.map((tag) => Chip(...))
  )
]

// Lines ?: Difficulty NOT displayed ❌
// MISSING: No difficulty field displayed in detail view
```

**ROOT CAUSE A.1:** `difficulty` field exists in database but is NOT rendered in template detail view.

**Root Cause A.2:** When switching to "Your Meal Plans" (user plans), the detail view does NOT show:

- Description (template was applied)
- Difficulty level
- Tags

This is because user plans do NOT store these metadata fields when created via `applyExploreTemplateAsActivePlan()`.

#### C. Admin Dashboard (NOT SHOWING METADATA)

**File:** `admin_discover_meal_plans_page.dart` + list rendering

**STATUS:** ❌ NO - Admin dashboard does not display description, tags, or difficulty in the plan list

---

## BUG CATEGORY 2: APPLY EXPLORE TEMPLATE WORKFLOW - INCOMPLETE DATA TRANSFER

### Symptom Reproduction

1. Admin creates plan with form (name, description, tags, difficulty, isPublished=true)
2. Admin adds meals via editor (saves successfully)
3. Admin navigates back, plan appears in explore list
4. User clicks "Bắt đầu" button
5. Notification says "Đã bắt đầu thực đơn thành công!"
6. User navigates to "Thực đơn của bạn"
7. **BUG:** Still shows OLD user plan, not the newly applied template

### Apply Workflow Analysis

#### STEP 1: Initiate Apply (UI)

**File:** `meal_detail_page.dart` (lines 900-930)

```dart
// User clicks "Xem chi tiết & bắt đầu" button
// Calls _startPlan() which:

Future<void> _startPlan() async {
  // 1. Get user + profile
  // 2. Show confirmation dialog if existing plan
  // 3. Call appliedController.applyExploreTemplate()

  await appliedController.applyExploreTemplate(
    templateId: template.id,
    profile: profile,
    userId: user.uid,
  );

  // 4. Show success snackbar
  // 5. Navigate back
  Navigator.pop(context);
}
```

**STATUS:** ✅ Workflow initiation correct

#### STEP 2: Controller Applies Template

**File:** `applied_meal_plan_controller.dart` (lines 90-155)

```dart
class AppliedMealPlanController extends Notifier<AppliedMealPlanState> {
  Future<void> applyExploreTemplate({
    required String templateId,
    required Profile profile,
    required String userId,
  }) async {
    // 1. Load template from repository ✅
    final template = await exploreRepo.getPlanById(templateId);

    // 2. Call service method
    final newPlan = await service.applyExploreTemplateAsActivePlan(
      userId: userId,
      templateId: templateId,
      template: template,           // ⚠️ PASSING TEMPLATE OBJECT
      profileData: profileData,
    );

    // 3. Invalidate provider
    ref.invalidate(user_meal_plan_providers.activeMealPlanProvider);
  }
}
```

**STATUS:** ✅ Correct flow

#### STEP 3: Service Applies Template

**File:** `user_meal_plan_service.dart` (lines 272-305)

```dart
Future<UserMealPlan> applyExploreTemplateAsActivePlan({
  required String userId,
  required String templateId,
  required ExploreMealPlan template,  // Template data
  required Map<String, dynamic> profileData,
}) async {
  // 1. Clear cache
  await _cache.clearActivePlan(userId);

  // 2. Call repository
  final plan = await _repository.applyExploreTemplateAsActivePlan(
    userId: userId,
    templateId: templateId,
    template: template,
    profileData: profileData,
  );

  // 3. Save to cache
  await _cache.saveActivePlan(userId, plan);

  // 4. Return plan
  return plan;
}
```

**STATUS:** ✅ Service coordinates correctly

#### STEP 4: Repository Creates User Plan

**File:** `user_meal_plan_repository_impl.dart` (lines 850-1183)

This is where the **CRITICAL BUG OCCURS**.

```dart
@override
Future<UserMealPlan> applyExploreTemplateAsActivePlan({
  required String userId,
  required String templateId,
  required ExploreMealPlan template,
  required Map<String, dynamic> profileData,
}) async {
  try {
    // STEP 1: Deactivate old plan ✅
    final batch = _firestore.batch();

    final activeSnapshot = await userPlansRef
        .where('isActive', isEqualTo: true)
        .get();

    for (final oldActiveDoc in activeSnapshot.docs) {
      batch.update(oldActiveDoc.reference, {
        'isActive': false,
        'status': 'paused',
      });
    }

    // STEP 2: Create new active plan using ApplyExploreTemplateService
    // ⚠️ BUG LOCATION HERE ⚠️

    final profile = Profile.fromJson(profileData);
    final userPlan = ApplyExploreTemplateService.applyTemplate(
      template: template,
      userId: userId,
      profile: profile,
      setAsActive: true,
    );

    // Convert and save
    final planToSave = userPlan.copyWith(id: newPlanId);
    final dto = _domainToDto(planToSave);
    final planData = dto.toFirestore();

    batch.set(newPlanRef, planData);
    await batch.commit();  // ✅ Batch write succeeds

    // STEP 3: Copy meals from template
    // Load template meals and copy to user plan
    for (int dayIndex = 1; dayIndex <= template.durationDays; dayIndex++) {
      final templateMeals = await exploreRepo.getDayMeals(
        templateId, dayIndex
      );
      // Copy meals to user plan days ✅ Works
    }

    // STEP 4: Load and return new plan
    final newPlanDoc = await newPlanRef.get();
    final newPlan = newPlanDto.toDomain();

    return newPlan;  // ✅ Returns new plan
  }
}
```

**STATUS:** ✅ Repository completes successfully

---

## ROOT CAUSE ANALYSIS - WHY APPLY DOESN'T WORK

### The Problem: Provider Invalidation Doesn't Refresh

**File:** `user_meal_plan_providers.dart` (lines 46-62)

```dart
final activeMealPlanProvider = StreamProvider<UserMealPlan?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) {
    return const Stream.empty();
  }

  debugPrint('[ActiveMealPlanProvider] 🔵 Setting up active plan stream for uid=${user.uid}');
  final service = ref.watch(userMealPlanServiceProvider);
  return service.watchActivePlanWithCache(user.uid);
});
```

**The Issue:**

When `ref.invalidate(activeMealPlanProvider)` is called (line 152 of `applied_meal_plan_controller.dart`), the provider rebuilds BUT:

1. It calls `service.watchActivePlanWithCache(user.uid)` again
2. This method returns a **stream** that emits:
   - First: Cached plan (the OLD user plan)
   - Later: Firestore query result (the NEW apply template plan)

**THE BUG:** The UI listens to the stream and receives the OLD cached plan first, displays it, then may (or may not) update when Firestore data arrives.

**Result:** User sees old plan because cache is still valid.

### Cache Flow Diagram

```
Apply Explorer Template
        ↓
[Repository] creates new user plan in Firestore
        ↓
[Service] saves new plan to SharedPrefs cache
        ↓
[Controller] invalidates provider
        ↓
[Provider] subscribes to watchActivePlanWithCache()
        ↓
[Service] checks cache: finds OLD plan (still cached!)
        ↓
[Service] emits cached OLD plan
        ↓
[UI] receives OLD plan → displays it
        ↓
[Service] subscribes to Firestore
        ↓
[Firestore] returns NEW plan
        ↓
[Service] emits NEW plan
        ↓
[UI] should update BUT timing is wrong
```

### Secondary Issue: Deactivation Race Condition

**File:** `user_meal_plan_repository_impl.dart` (lines 867-889)

```dart
// Query and deactivate existing active plan
final activeSnapshot = await userPlansRef
    .where('isActive', isEqualTo: true)
    .get();

for (final oldActiveDoc in activeSnapshot.docs) {
  batch.update(oldActiveDoc.reference, {
    'isActive': false,
    'status': 'paused',
  });
}

// Create new active plan
batch.set(newPlanRef, planData);
await batch.commit();
```

**STATUS:** ✅ Batch write is atomic - should deactivate OLD and activate NEW

**BUT POTENTIAL ISSUE:** If the deactivation query misses the old plan (due to Firestore lag), both plans could be active momentarily.

---

## ISSUE SUMMARY TABLE

| #      | Issue                                                           | Severity | Location                                        | Category   |
| ------ | --------------------------------------------------------------- | -------- | ----------------------------------------------- | ---------- |
| **1A** | Difficulty field not displayed in detail view                   | MEDIUM   | `meal_detail_page.dart` line ~180               | Display    |
| **1B** | Admin dashboard doesn't show description/tags/difficulty        | MEDIUM   | `admin_discover_meal_plans_page.dart`           | Display    |
| **1C** | Applied template loses metadata (description, tags, difficulty) | MEDIUM   | `user_meal_plan_repository_impl.dart` line 1050 | Data Loss  |
| **2A** | Cache not cleared before resubscribing to provider              | CRITICAL | `user_meal_plan_providers.dart` line 46-62      | Apply Flow |
| **2B** | Old plan still active after apply                               | CRITICAL | `watchActivePlanWithCache()` emit order         | Apply Flow |
| **2C** | Provider invalidation timing creates race condition             | MAJOR    | `applied_meal_plan_controller.dart` line 152    | Apply Flow |

---

## DETAILED SOLUTION

### SOLUTION 1A: Display Difficulty in Detail View

**File:** `meal_detail_page.dart` (after line 147)

**Current Code:**

```dart
if (template.tags.isNotEmpty) ...[
  // tags display
],
```

**Add After:**

```dart
if (template.difficulty != null && template.difficulty!.isNotEmpty) ...[
  const SizedBox(height: 12),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.lightGray,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      'Độ khó: ${_getDifficultyLabel(template.difficulty!)}',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
],

// Helper method
String _getDifficultyLabel(String difficulty) {
  switch (difficulty) {
    case 'easy':
      return 'Dễ';
    case 'medium':
      return 'Trung bình';
    case 'hard':
      return 'Khó';
    default:
      return difficulty;
  }
}
```

**Acceptance Criteria:**

- [ ] Detail page shows difficulty level when available
- [ ] Label matches form labels (Dễ, Trung bình, Khó)

---

### SOLUTION 1B: Display Metadata in Admin Dashboard

**File:** Admin meal plan list item widget (if it exists)

**Add Fields:**

```dart
// After plan name, show:
if (plan.description.isNotEmpty)
  Text(plan.description, maxLines: 2, overflow: TextOverflow.ellipsis)

// Below description:
if (plan.tags.isNotEmpty)
  Wrap(
    children: plan.tags.map((tag) => Chip(label: Text(tag)))
  )

// Add difficulty badge:
if (plan.difficulty != null)
  Text('Độ khó: ${_getDifficultyLabel(plan.difficulty!)}')
```

**Acceptance Criteria:**

- [ ] Admin dashboard shows description, tags, difficulty for each plan
- [ ] Information is readable and well-formatted

---

### SOLUTION 1C: Preserve Metadata When Applying Template

**File:** `user_meal_plan_repository_impl.dart` (lines 897-920)

**Current Code:**

```dart
final userPlan = ApplyExploreTemplateService.applyTemplate(
  template: template,
  userId: userId,
  profile: profile,
  setAsActive: true,
);
```

**Problem:** `ApplyExploreTemplateService.applyTemplate()` doesn't copy description/tags/difficulty from template to user plan.

**Solution:** Check if `ApplyExploreTemplateService` copies these fields. If not:

```dart
// After applying template
final userPlanWithMetadata = userPlan.copyWith(
  description: template.description,
  tags: template.tags,
  difficulty: template.difficulty,
);

final planToSave = userPlanWithMetadata.copyWith(id: newPlanId);
```

**Acceptance Criteria:**

- [ ] User plans created from templates retain description
- [ ] User plans created from templates retain tags
- [ ] User plans created from templates retain difficulty
- [ ] These fields display correctly in "Your Meal Plans" detail view

---

### SOLUTION 2A: FIX THE CRITICAL APPLY BUG - Clear Cache Before Invalidation

**File:** `applied_meal_plan_controller.dart` (lines 131-155)

**Current Code:**

```dart
final newPlan = await service.applyExploreTemplateAsActivePlan(
  userId: userId,
  templateId: templateId,
  template: template,
  profileData: profileData,
);

if (!ref.mounted) return;

// Invalidate provider
ref.invalidate(user_meal_plan_providers.activeMealPlanProvider);
```

**The Issue:** The service saves the new plan to cache, but when provider invalidates, it:

1. Rebuilds the provider
2. Calls `watchActivePlanWithCache()`
3. This method loads from cache (which might have OLD data)

**Root Fix:** Service method needs to FORCE clear old plan data from cache BEFORE returning.

**In `user_meal_plan_service.dart` (line 272-305), ensure:**

```dart
async Future<UserMealPlan> applyExploreTemplateAsActivePlan({...}) {
  // CRITICAL: Clear old active plan FIRST
  await _cache.clearActivePlan(userId);

  // Apply via repository
  final plan = await _repository.applyExploreTemplateAsActivePlan(...);

  // Save new plan to cache
  await _cache.saveActivePlan(userId, plan);

  // CRITICAL: Clear the generic plans list cache
  // This prevents old data from being loaded
  await _cache.clearAllForUser(userId);

  return plan;
}
```

**Status:** ✅ This appears to be already implemented (lines 280-298), but verify it's ACTUALLY clearing.

**Acceptance Criteria:**

- [ ] Old plan is completely removed from cache
- [ ] New plan is saved atomically
- [ ] Provider receives NEW plan, not old

---

### SOLUTION 2B: Force Provider to Wait for Firestore Data

**File:** `user_meal_plan_providers.dart` (lines 46-62)

**Problem:** Stream emits cached data immediately, then Firestore data later. UI shows old cached data.

**Option A (Recommended):** Skip cache for invalidated provider

```dart
// Add a special flag to force skip cache on provider invalidation
final activeMealPlanProvider = StreamProvider<UserMealPlan?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) {
    return const Stream.empty();
  }

  final service = ref.watch(userMealPlanServiceProvider);

  // Check if we just invalidated (force fresh Firestore)
  // This is a timing-sensitive workaround
  return service.watchActivePlanWithCache(user.uid).skip(1); // Skip first cache emit
});
```

**Option B (Alternative):** Cache invalidation in service

```dart
// In UserMealPlanService.applyExploreTemplateAsActivePlan():

print('[Service] 🧹 Clearing cache completely before returning');
await _cache.clearActivePlan(userId);
await _cache.clearAllForUser(userId);

// Don't re-cache immediately - let Firestore be source of truth
// The watchActivePlanWithCache stream will load from Firestore

return plan;
```

**Acceptance Criteria:**

- [ ] After "Bắt đầu" button, user sees NEW plan, not old
- [ ] No flickering between plans
- [ ] New plan displays within 1-2 seconds

---

### SOLUTION 2C: Ensure Deactivation Happens Atomically

**File:** `user_meal_plan_repository_impl.dart` (lines 867-911)

**Verify the batch write is atomic:**

```dart
// Step 1: Query active plans BEFORE batch
final activeSnapshot = await userPlansRef
    .where('isActive', isEqualTo: true)
    .get();

// Step 2: Prepare batch operations
final batch = _firestore.batch();

// Step 3: Deactivate OLD plans
for (final oldActiveDoc in activeSnapshot.docs) {
  batch.update(oldActiveDoc.reference, {'isActive': false});
}

// Step 4: Activate NEW plan
batch.set(newPlanRef, planData);

// Step 5: Commit atomically
await batch.commit();

// Step 6: Verify exactly ONE active plan exists
final verifySnapshot = await userPlansRef
    .where('isActive', isEqualTo: true)
    .get();

assert(
  verifySnapshot.docs.length == 1,
  'Expected 1 active plan, found ${verifySnapshot.docs.length}',
);
```

**Acceptance Criteria:**

- [ ] Only ONE active plan ever exists
- [ ] Old plan is deactivated before new is activated
- [ ] Batch write succeeds or fails atomically

---

## IMPLEMENTATION PRIORITY

### Priority 1 (CRITICAL - Blocks Apply Feature)

- **2A:** Clear cache before invalidation
- **2B:** Fix provider to use fresh Firestore data
- **2C:** Verify atomic deactivation

### Priority 2 (MAJOR - Data Display)

- **1A:** Display difficulty in detail view
- **1C:** Preserve metadata when applying

### Priority 3 (MEDIUM - Admin UX)

- **1B:** Show metadata in admin dashboard

---

## VERIFICATION CHECKLIST

### After Fix - Apply Template Flow

- [ ] Create template with description, tags, difficulty
- [ ] Publish template (isPublished=true)
- [ ] User navigates to Khám phá thực đơn
- [ ] User clicks template
- [ ] Detail page shows description, tags, difficulty
- [ ] User clicks "Xem chi tiết & bắt đầu"
- [ ] Snackbar shows "Đã bắt đầu thực đơn thành công!"
- [ ] Navigate to "Thực đơn của bạn"
- [ ] **EXPECTED:** New template plan is ACTIVE (not old user plan)
- [ ] New plan shows name, calories, duration
- [ ] Meals from template are displayed
- [ ] All metadata is preserved

### After Fix - Admin Dashboard

- [ ] Admin creates plan
- [ ] Plan appears in admin dashboard
- [ ] Description is visible in list
- [ ] Tags are displayed
- [ ] Difficulty level is shown

---

## TECHNICAL NOTES

### Firestore Data Structure (After Apply)

```
users/{userId}/user_meal_plans/{newPlanId}/
├── isActive: true               ✅ Correctly set
├── status: "active"             ✅ Correct
├── name: "template name"        ✅ From template
├── description: "..."           ❌ MISSING (should copy)
├── tags: [...]                  ❌ MISSING (should copy)
├── difficulty: "..."            ❌ MISSING (should copy)
├── days/{dayIndex}/
│   └── meals/{mealId}/         ✅ Correctly copied
```

### Cache Flow Issue

```
applyExploreTemplate() called
  ↓
repository.applyExploreTemplateAsActivePlan()
  ↓
service.applyExploreTemplateAsActivePlan()
  ↓
saves new plan to SharedPrefs: plan_uid_userId
  ↓
controller invalidates provider
  ↓
provider rebuilds → watchActivePlanWithCache()
  ↓
cache.getActivePlan(userId) → returns CACHED plan_uid_userId
  ↓
BUT: This was the OLD plan ID! Need to clear first!
```

---

## CONCLUSION

The apply feature has **TWO DISTINCT ISSUES:**

1. **Metadata Loss (Display):** Form captures description/tags/difficulty but they're not preserved or displayed
2. **Cache Coherency (Critical):** Old plan remains cached and is displayed after apply, preventing new template from becoming active

**Root Cause:** Incomplete data flow chain and cache invalidation race condition.

**Fix Complexity:** Medium - involves cache layer, provider architecture, and Firestore batch operations.

**Estimated Time:** 2-3 hours for experienced developer familiar with Riverpod/Firestore patterns.
