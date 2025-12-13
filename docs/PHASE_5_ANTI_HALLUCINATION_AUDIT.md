# Phase 5: Anti-Hallucination Audit Report

**Date:** 2024-12-XX  
**Scope:** Bug fixes for "Apply Explore Meal Plans" workflow  
**Phases Completed:** Phase 1 (Metadata), Phase 2 (Cache), Phase 3 (Provider Invalidation), Phase 4 (Verification)

---

## Files Changed (Exact List)

### Phase 1: Metadata Preservation (Bug #1)
1. `lib/domain/meal_plans/user_meal_plan.dart`
2. `lib/features/meal_plans/domain/services/apply_explore_template_service.dart`
3. `lib/features/meal_plans/data/dto/user_meal_plan_dto.dart`
4. `lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart`

### Phase 2: Cache Stale Plan Fix (Bug #2)
5. `lib/domain/meal_plans/user_meal_plan_service.dart`

### Phase 3: Provider Invalidation Timing (Bug #3)
6. `lib/features/meal_plans/state/applied_meal_plan_controller.dart`

### Documentation (All Phases)
7. `docs/PHASE_1_METADATA_PROOF.md` (created)
8. `docs/PHASE_2_APPLY_FIX_SUMMARY.md` (created)
9. `docs/PHASE_3_PROVIDER_INVALIDATION_FIX_PROOF.md` (created)
10. `docs/PHASE_4_E2E_VERIFICATION.md` (created)
11. `docs/PHASE_4_EXPECTED_LOGS.md` (created)
12. `docs/PHASE_4_VERIFICATION_SUMMARY.md` (created)

**Total:** 6 code files modified, 6 documentation files created

---

## Phase 1 Result + Evidence

### Bug #1: Metadata Lost During Apply

**Problem:** When applying an explore template, `description`, `tags`, and `difficulty` fields were not copied to the user plan.

**Root Cause:** `UserMealPlan` domain model did not include these fields, and the apply service did not copy them from template.

**Fix Strategy:**
1. Add metadata fields to `UserMealPlan` domain model (backward compatible)
2. Update apply service to copy metadata from template
3. Update DTO mapping to include metadata in Firestore serialization
4. Update repository to pass metadata through DTO conversion

---

### File 1: `lib/domain/meal_plans/user_meal_plan.dart`

**What Changed:**
- Added 3 new optional fields to `UserMealPlan` class:
  - `final String? description;` (line 86)
  - `final List<String> tags;` (line 87, default `const []`)
  - `final String? difficulty;` (line 88)
- Updated constructor to accept these fields (lines 105-107)
- Updated `copyWith()` to include these fields (lines 153-155, 172-174)
- Updated `toJson()` to serialize these fields (lines 195-197)
- Updated `fromJson()` to deserialize these fields (lines 222-224)
- Updated `operator ==` to compare these fields (lines 244-246)
- Updated `hashCode` to include these fields (lines 264-266)

**Why This Maps to Bug #1:**
- Without these fields in the domain model, metadata could not be stored or retrieved.
- This is the foundation for metadata persistence.

**Evidence - Diff Snippet:**
```dart
// BEFORE (missing fields)
class UserMealPlan {
  // ... existing fields ...
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // No metadata fields
}

// AFTER (added fields)
class UserMealPlan {
  // ... existing fields ...
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Metadata fields (optional, backward compatible)
  final String? description;
  final List<String> tags; // Default to empty list
  final String? difficulty; // "easy" | "medium" | "hard"
}
```

**Verification Status:** ✅ VERIFIED - File exists, fields present at lines 86-88

---

### File 2: `lib/features/meal_plans/domain/services/apply_explore_template_service.dart`

**What Changed:**
- Updated `applyTemplate()` method to copy metadata from `ExploreMealPlan` to `UserMealPlan`:
  - `description: template.description`
  - `tags: template.tags`
  - `difficulty: template.difficulty`

**Why This Maps to Bug #1:**
- This is where the metadata copy happens during the apply operation.
- Without this, metadata would not be copied even if the domain model supports it.

**Evidence - Diff Snippet:**
```dart
// BEFORE (no metadata copy)
return UserMealPlan(
  id: '',
  userId: userId,
  planTemplateId: template.id,
  name: template.name,
  // ... other fields ...
  // No description, tags, difficulty
);

// AFTER (metadata copied)
return UserMealPlan(
  id: '',
  userId: userId,
  planTemplateId: template.id,
  name: template.name,
  // ... other fields ...
  description: template.description, // ✅ ADDED
  tags: template.tags,               // ✅ ADDED
  difficulty: template.difficulty,   // ✅ ADDED
);
```

**Verification Status:** ✅ VERIFIED - File read, metadata copy present at lines 64-66

---

### File 3: `lib/features/meal_plans/data/dto/user_meal_plan_dto.dart`

**What Changed:**
- Added 3 fields to `UserMealPlanDto` class:
  - `final String? description;` (line 40)
  - `final List<String> tags;` (line 41, default `const []`)
  - `final String? difficulty;` (line 42)
- Updated constructor (lines 59-61)
- Updated `fromFirestore()` to read these fields (lines 86-88):
  - `description: data['description'] as String?`
  - `tags: List<String>.from((data['tags'] as List?) ?? const [])`
  - `difficulty: data['difficulty'] as String?`
- Updated `toFirestore()` to write these fields (lines 139-141):
  - `'description': description`
  - `'tags': tags`
  - `if (difficulty != null) 'difficulty': difficulty`
- Updated `toDomain()` extension to map these fields (lines 165-167)
- Updated `toDto()` extension to map these fields (lines 191-193)

**Why This Maps to Bug #1:**
- DTO handles Firestore serialization/deserialization.
- Without DTO support, metadata would not be persisted to or read from Firestore.

**Evidence - Diff Snippet:**
```dart
// BEFORE (missing in DTO)
factory UserMealPlanDto.fromFirestore(...) {
  return UserMealPlanDto(
    // ... other fields ...
    createdAt: ...,
    updatedAt: ...,
    // No description, tags, difficulty
  );
}

// AFTER (included in DTO)
factory UserMealPlanDto.fromFirestore(...) {
  return UserMealPlanDto(
    // ... other fields ...
    createdAt: ...,
    updatedAt: ...,
    description: data['description'] as String?,              // ✅ ADDED
    tags: List<String>.from((data['tags'] as List?) ?? const []), // ✅ ADDED
    difficulty: data['difficulty'] as String?,                // ✅ ADDED
  );
}
```

**Verification Status:** ✅ VERIFIED - File exists, fields present at lines 40-42, 86-88, 139-141

---

### File 4: `lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart`

**What Changed:**
- Updated `_domainToDto()` helper method to include metadata fields when converting `UserMealPlan` to `UserMealPlanDto`:
  - `description: plan.description`
  - `tags: plan.tags`
  - `difficulty: plan.difficulty`
- Added logging to verify metadata in Firestore payload:
  - `debugPrint('[UserMealPlanRepository] [ApplyExplore] 🧾 userPlan meta: desc="${planToSave.description}", tags=${planToSave.tags}, difficulty=${planToSave.difficulty}')`
  - `debugPrint('[UserMealPlanRepository] [ApplyExplore] 🧾 Firestore payload includes: description=${planData['description']}, tags=${planData['tags']}, difficulty=${planData['difficulty']}')`

**Why This Maps to Bug #1:**
- Repository layer converts domain models to DTOs before Firestore writes.
- Without this, metadata would not be included in the Firestore write.

**Evidence - Diff Snippet:**
```dart
// BEFORE (missing metadata in DTO conversion)
UserMealPlanDto _domainToDto(UserMealPlan plan) {
  return UserMealPlanDto(
    // ... other fields ...
    createdAt: plan.createdAt,
    updatedAt: plan.updatedAt,
    // No description, tags, difficulty
  );
}

// AFTER (metadata included)
UserMealPlanDto _domainToDto(UserMealPlan plan) {
  return UserMealPlanDto(
    // ... other fields ...
    createdAt: plan.createdAt,
    updatedAt: plan.updatedAt,
    description: plan.description,  // ✅ ADDED
    tags: plan.tags,                // ✅ ADDED
    difficulty: plan.difficulty,    // ✅ ADDED
  );
}
```

**Verification Status:** ✅ VERIFIED - File read, metadata included in `_domainToDto()` at lines 69-71, logging present at lines 916-917

---

### Phase 1 Evidence Pack

**Log Tags Added:**
- `[ApplyExplore] 🧾 template meta: desc=..., tags=..., difficulty=...`
- `[ApplyExplore] 🧾 userPlan meta: desc=..., tags=..., difficulty=...`
- `[UserMealPlanRepository] [ApplyExplore] 🧾 userPlan meta: desc=..., tags=..., difficulty=...`
- `[UserMealPlanRepository] [ApplyExplore] 🧾 Firestore payload includes: description=..., tags=..., difficulty=...`

**Example Firestore Payload:**
```json
{
  "userId": "user123",
  "planTemplateId": "template456",
  "name": "Test Plan - Phase 4",
  "description": "Test Description",          // ✅ NEW FIELD
  "tags": ["Tag1", "Tag2"],                   // ✅ NEW FIELD
  "difficulty": "easy",                        // ✅ NEW FIELD
  "goalType": "lose_fat",
  "type": "template",
  "startDate": "2024-12-XXT00:00:00Z",
  "currentDayIndex": 1,
  "status": "active",
  "dailyCalories": 1800,
  "durationDays": 7,
  "isActive": true,
  "createdAt": "2024-12-XXT00:00:00Z",
  "updatedAt": "2024-12-XXT00:00:00Z"
}
```

**Verification Status:**
- ✅ Domain model fields: VERIFIED
- ✅ DTO mapping: VERIFIED
- ⚠️ Apply service copy: NOT VERIFIED (file not read)
- ⚠️ Repository DTO conversion: NOT VERIFIED (grep only)

---

## Phase 2 Result + Evidence

### Bug #2: Cache Emits Stale OLD Plan After Apply

**Problem:** After applying an explore template, the UI briefly showed the old active plan before switching to the new plan. This happened because `watchActivePlanWithCache()` emitted a stale cached plan when Firestore was slow to emit.

**Root Cause:** The stream logic emitted cached plan as fallback if Firestore didn't emit quickly. After apply operations, cache is cleared, but if Firestore is delayed, the stream might still try to use stale cache data.

**Fix Strategy:**
1. Increase timeout from 1000ms to 3000ms
2. **CRITICAL:** Emit `null` on Firestore timeout instead of falling back to cache
3. Continue streaming Firestore emissions after timeout
4. Add detailed logging for timeline

---

### File 5: `lib/domain/meal_plans/user_meal_plan_service.dart`

**What Changed:**
- **Line 68:** Increased timeout from 1000ms to 3000ms:
  - `const timeout = Duration(milliseconds: 3000);` (was 1000ms)
- **Lines 79-82:** Added timeout handling that emits `null` instead of cache:
  ```dart
  if (e is TimeoutException) {
    // CRITICAL FIX: Never yield stale cache here - emit null instead
    print('[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)');
    print('[ActivePlanCache] 🔁 Will continue streaming Firestore emissions...');
  }
  ```
- **Lines 101-110:** Changed logic to emit `null` when Firestore times out:
  ```dart
  } else {
    // CRITICAL FIX: Firestore timeout - emit null (NOT cache) to prevent stale data
    print('[UserMealPlanService] [ActivePlan] 📦 Firestore timeout - emitting NULL (no cache fallback to prevent stale data)');
    print('[UserMealPlanService] [ActivePlan] 📡 Will continue streaming Firestore emissions...');
    yield null;
    lastEmittedPlanId = null;
  }
  ```
- **Lines 72, 77, 81-82, 138:** Added detailed logging:
  - `[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms`
  - `[ActivePlanCache] ✅ Firestore first emission received planId=...`
  - `[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)`

**Why This Maps to Bug #2:**
- Prevents stale cached plan from being emitted when Firestore is slow.
- UI will show loading/null instead of old plan, then update to new plan when Firestore emits.

**Evidence - Diff Snippet:**
```dart
// BEFORE (emitted stale cache on timeout)
const timeout = Duration(milliseconds: 1000);
try {
  firstRemotePlan = await firstEmissionCompleter.future.timeout(timeout);
  yield firstRemotePlan;
} catch (e) {
  if (e is TimeoutException) {
    // OLD: Emitted cached plan (STALE DATA RISK)
    final cached = await _cache.loadActivePlan(userId);
    yield cached; // ❌ BUG: Could emit old plan
  }
}

// AFTER (emits null on timeout)
const timeout = Duration(milliseconds: 3000); // ✅ Increased timeout
try {
  firstRemotePlan = await firstEmissionCompleter.future.timeout(timeout);
  yield firstRemotePlan;
} catch (e) {
  if (e is TimeoutException) {
    // CRITICAL FIX: Never yield stale cache here - emit null instead
    print('[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)');
    // ✅ No cache fallback
  }
}
// ...
} else {
  // CRITICAL FIX: Firestore timeout - emit null (NOT cache) to prevent stale data
  yield null; // ✅ Emit null, not cache
  lastEmittedPlanId = null;
}
```

**Verification Status:** ✅ VERIFIED - File exists, timeout increased, null emission logic present

---

### Phase 2 Evidence Pack

**Log Tags Added:**
- `[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms`
- `[ActivePlanCache] ✅ Firestore first emission received planId=...`
- `[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)`
- `[ActivePlanCache] 🔁 Will continue streaming Firestore emissions...`
- `[UserMealPlanService] [ActivePlan] 📦 Firestore timeout - emitting NULL (no cache fallback to prevent stale data)`
- `[UserMealPlanService] [ActivePlan] 📡 Will continue streaming Firestore emissions...`

**Example Log Sequence (Normal Flow):**
```
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
[ActivePlanCache] ✅ Firestore first emission received planId=user456_1699123456789
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore (first): planId=user456_1699123456789
```

**Example Log Sequence (Slow Network / Timeout):**
```
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)
[ActivePlanCache] 🔁 Will continue streaming Firestore emissions...
[UserMealPlanService] [ActivePlan] 📦 Firestore timeout - emitting NULL (no cache fallback to prevent stale data)
[ActivePlanCache] 🔁 Firestore subsequent emission planId=user456_1699123456789
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore: planId=user456_1699123456789
```

**Verification Status:**
- ✅ Timeout increased to 3000ms: VERIFIED
- ✅ Null emission on timeout: VERIFIED
- ✅ Logging added: VERIFIED

---

## Phase 3 Result + Evidence

### Bug #3: Provider Invalidation Timing Race

**Problem:** Provider was invalidated immediately after `applyExploreTemplateAsActivePlan()` returned, before cache/Firestore was ready. This caused the provider to re-subscribe and potentially read stale data or emit the wrong state.

**Root Cause:** Controller called `ref.invalidate()` immediately after service call returned, without waiting for cache or Firestore to be ready.

**Fix Strategy:**
1. Implement cache confirmation loop (max 5 attempts, 100ms delay each)
2. Fallback to 500ms delay if cache confirmation fails
3. Invalidate provider AFTER wait/verification
4. Add detailed logging

---

### File 6: `lib/features/meal_plans/state/applied_meal_plan_controller.dart`

**What Changed:**
- **Lines 143-165:** Added cache confirmation loop:
  ```dart
  final cache = ref.read(user_meal_plan_providers.userMealPlanCacheProvider);
  bool cacheConfirmed = false;
  const maxCacheAttempts = 5;
  const cacheCheckDelay = Duration(milliseconds: 100);
  
  for (int attempt = 1; attempt <= maxCacheAttempts; attempt++) {
    final cached = await cache.loadActivePlan(userId);
    final cachedPlanId = cached?.id;
    print('[ApplyExplore] ⏳ wait cache reflect newPlan attempt=$attempt cachedPlanId=$cachedPlanId');
    
    if (cached?.id == newPlan.id) {
      cacheConfirmed = true;
      print('[ApplyExplore] ✅ Cache confirmed new plan after $attempt attempt(s)');
      break;
    }
    
    if (attempt < maxCacheAttempts) {
      await Future.delayed(cacheCheckDelay);
    }
  }
  ```
- **Lines 167-172:** Added fallback delay if cache confirmation fails:
  ```dart
  if (!cacheConfirmed) {
    print('[ApplyExplore] ⚠️ Cache confirmation failed after $maxCacheAttempts attempts, delaying 500ms before invalidation');
    await Future.delayed(const Duration(milliseconds: 500));
  }
  ```
- **Line 141:** Added log when apply returns:
  - `print('[ApplyExplore] ✅ apply returned planId=${newPlan.id}');`
- **Line 154:** Added log for each cache check attempt:
  - `print('[ApplyExplore] ⏳ wait cache reflect newPlan attempt=$attempt cachedPlanId=$cachedPlanId');`
- **Line 158:** Added log when cache confirmed:
  - `print('[ApplyExplore] ✅ Cache confirmed new plan after $attempt attempt(s)');`
- **Line 170:** Added log for fallback delay:
  - `print('[ApplyExplore] ⚠️ Cache confirmation failed after $maxCacheAttempts attempts, delaying 500ms before invalidation');`
- **Line 175:** Added log before invalidation:
  - `print('[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=${newPlan.id}');`
- **Line 176:** Moved invalidation to AFTER wait/verification (was immediately after service call)

**Why This Maps to Bug #3:**
- Prevents provider from invalidating before cache/Firestore is ready.
- Ensures provider re-subscription happens when data is consistent.

**Evidence - Diff Snippet:**
```dart
// BEFORE (immediate invalidation - RACE CONDITION)
final newPlan = await service.applyExploreTemplateAsActivePlan(...);
debugPrint('[AppliedMealPlanController] [Explore] ✅ New active plan: planId=${newPlan.id}');
ref.invalidate(user_meal_plan_providers.activeMealPlanProvider); // ❌ IMMEDIATE - RACED

// AFTER (wait then invalidate - NO RACE)
final newPlan = await service.applyExploreTemplateAsActivePlan(...);
print('[ApplyExplore] ✅ apply returned planId=${newPlan.id}');

// Cache confirmation loop
final cache = ref.read(user_meal_plan_providers.userMealPlanCacheProvider);
bool cacheConfirmed = false;
for (int attempt = 1; attempt <= 5; attempt++) {
  final cached = await cache.loadActivePlan(userId);
  print('[ApplyExplore] ⏳ wait cache reflect newPlan attempt=$attempt cachedPlanId=${cached?.id}');
  if (cached?.id == newPlan.id) {
    cacheConfirmed = true;
    break;
  }
  if (attempt < 5) await Future.delayed(const Duration(milliseconds: 100));
}

// Fallback delay
if (!cacheConfirmed) {
  print('[ApplyExplore] ⚠️ Cache confirmation failed, delaying 500ms before invalidation');
  await Future.delayed(const Duration(milliseconds: 500));
}

print('[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=${newPlan.id}');
ref.invalidate(user_meal_plan_providers.activeMealPlanProvider); // ✅ AFTER WAIT - NO RACE
```

**Verification Status:** ✅ VERIFIED - File exists, cache loop present, invalidation after wait

---

### Phase 3 Evidence Pack

**Log Tags Added:**
- `[ApplyExplore] ✅ apply returned planId=...`
- `[ApplyExplore] ⏳ wait cache reflect newPlan attempt=X cachedPlanId=...`
- `[ApplyExplore] ✅ Cache confirmed new plan after X attempt(s)`
- `[ApplyExplore] ⚠️ Cache confirmation failed after 5 attempts, delaying 500ms before invalidation`
- `[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=...`

**Example Log Sequence (Cache Confirmation Succeeds):**
```
[ApplyExplore] ✅ apply returned planId=user456_1699123456789
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=1 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=2 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=3 cachedPlanId=user456_1699123456789
[ApplyExplore] ✅ Cache confirmed new plan after 3 attempt(s)
[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=user456_1699123456789
```

**Example Log Sequence (Cache Confirmation Fails → Delay):**
```
[ApplyExplore] ✅ apply returned planId=user456_1699123456789
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=1 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=2 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=3 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=4 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=5 cachedPlanId=null
[ApplyExplore] ⚠️ Cache confirmation failed after 5 attempts, delaying 500ms before invalidation
[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=user456_1699123456789
```

**Verification Status:**
- ✅ Cache confirmation loop: VERIFIED
- ✅ Fallback delay: VERIFIED
- ✅ Invalidation after wait: VERIFIED
- ✅ Logging added: VERIFIED

---

## Phase 4 Verification Steps + Expected Logs

### Verification Scenario 1: Normal Apply Flow

**Steps:**
1. Create explore template with metadata (description, tags, difficulty)
2. Apply template as user
3. Immediately navigate to "Your meal plan" tab

**Expected Log Sequence:**
```
[ApplyExplore] ✅ apply returned planId=user456_1699123456789
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=1 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=2 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=3 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=4 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=5 cachedPlanId=null
[ApplyExplore] ⚠️ Cache confirmation failed after 5 attempts, delaying 500ms before invalidation
[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=user456_1699123456789

[ActiveMealPlanProvider] 🔵 Setting up active plan stream for uid=user456
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
[ActivePlanCache] ✅ Firestore first emission received planId=user456_1699123456789
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore (first): planId=user456_1699123456789
```

**Expected UI Behavior:**
- Shows new plan immediately
- NEVER shows old plan
- Metadata visible (if UI supports it)

**Verification Status:** ⚠️ NOT VERIFIED - Manual testing required

---

### Verification Scenario 2: Slow Network

**Steps:**
1. Enable network throttling (Chrome DevTools → Slow 3G)
2. Apply template
3. Navigate to "Your meal plan" tab

**Expected Log Sequence:**
```
[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=user456_1699123456789
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)
[ActivePlanCache] 🔁 Will continue streaming Firestore emissions...
[UserMealPlanService] [ActivePlan] 📦 Firestore timeout - emitting NULL
[ActivePlanCache] 🔁 Firestore subsequent emission planId=user456_1699123456789
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore: planId=user456_1699123456789
```

**Expected UI Behavior:**
- May show loading/null briefly
- MUST NOT show old plan
- Then shows new plan when Firestore emits

**Verification Status:** ⚠️ NOT VERIFIED - Manual testing required

---

### Verification Scenario 3: Consecutive Apply

**Steps:**
1. Apply Template A
2. Immediately apply Template B
3. Navigate to "Your meal plan" tab

**Expected Result:**
- Only Template B is visible
- Template A has `isActive=false` in Firestore
- Exactly ONE active plan exists

**Verification Status:** ⚠️ NOT VERIFIED - Manual testing required

---

### Firestore Document Verification

**Expected User Plan Document Structure:**
```json
{
  "userId": "user456",
  "planTemplateId": "template123",
  "name": "Test Plan - Phase 4",
  "description": "Test Description",          // ✅ MUST EXIST (Phase 1)
  "tags": ["Tag1", "Tag2"],                   // ✅ MUST EXIST (Phase 1)
  "difficulty": "easy",                        // ✅ MUST EXIST (Phase 1)
  "goalType": "lose_fat",
  "type": "template",
  "startDate": "2024-12-XXT00:00:00Z",
  "currentDayIndex": 1,
  "status": "active",
  "dailyCalories": 1800,
  "durationDays": 7,
  "isActive": true,
  "createdAt": "2024-12-XXT00:00:00Z",
  "updatedAt": "2024-12-XXT00:00:00Z"
}
```

**Verification Status:** ⚠️ NOT VERIFIED - Firestore inspection required

---

## Phase 5 Audit Report

### Summary

**Total Files Changed:** 6 code files, 6 documentation files  
**Bugs Fixed:** 3 (Metadata, Cache Stale Plan, Provider Invalidation)  
**Lines Changed (estimated):** ~150 lines across all files

### Verification Coverage

| Component | Status | Notes |
|-----------|--------|-------|
| Domain Model (UserMealPlan) | ✅ VERIFIED | Fields present in file |
| DTO Mapping (UserMealPlanDto) | ✅ VERIFIED | Fields present in file |
| Apply Service | ✅ VERIFIED | Metadata copy present at lines 64-66 |
| Repository DTO Conversion | ✅ VERIFIED | Metadata included at lines 69-71 |
| Cache Timeout Fix | ✅ VERIFIED | Timeout and null emission present |
| Provider Invalidation Fix | ✅ VERIFIED | Cache loop and delay present |
| Firestore Payload | ⚠️ NOT VERIFIED | Requires manual inspection |
| UI Behavior | ⚠️ NOT VERIFIED | Requires manual testing |
| Slow Network Behavior | ⚠️ NOT VERIFIED | Requires manual testing |

### Unverified Claims

1. ~~**Apply Service Metadata Copy:** Claimed to copy `description`, `tags`, `difficulty` from template to user plan, but file was not read in this audit. Status: ⚠️ NOT VERIFIED~~ ✅ **NOW VERIFIED** - File read, metadata copy confirmed at lines 64-66

2. ~~**Repository DTO Conversion:** Claimed to include metadata in `_domainToDto()`, but only verified via grep. Status: ⚠️ NOT VERIFIED (low confidence)~~ ✅ **NOW VERIFIED** - File read, metadata conversion confirmed at lines 69-71

3. **Firestore Payload:** Claimed metadata fields are persisted, but requires manual Firestore inspection. Status: ⚠️ NOT VERIFIED

4. **UI Behavior:** Claimed UI shows new plan immediately without old plan flash, but requires manual testing. Status: ⚠️ NOT VERIFIED

5. **Slow Network Behavior:** Claimed UI shows loading/null then new plan (not old plan), but requires manual testing with throttled network. Status: ⚠️ NOT VERIFIED

### Code Quality

- ✅ All changes are backward compatible (optional fields with defaults)
- ✅ Logging is comprehensive and traceable
- ✅ Error handling is present (timeouts, fallbacks)
- ✅ No breaking changes to existing APIs

### Risk Assessment

**Low Risk:**
- Domain model changes (backward compatible)
- Cache timeout fix (defensive programming)
- Provider invalidation fix (adds delay, no removal of safety checks)

**Medium Risk:**
- DTO mapping changes (could affect existing data if not handled correctly, but fields are optional)

**High Risk:**
- None identified

### Recommendations

1. ~~**Immediate:** Verify apply service metadata copy by reading `apply_explore_template_service.dart`~~ ✅ **COMPLETED**
2. **Before Release:** Manual testing of all three verification scenarios
3. **Before Release:** Firestore inspection to confirm metadata fields in user plan documents
4. **Optional:** Add unit tests for metadata copy logic
5. **Optional:** Add integration tests for cache timeout behavior

---

## Conclusion

**Phase 1-3 Implementation:** ✅ COMPLETE  
**Phase 4 Documentation:** ✅ COMPLETE  
**Phase 5 Audit:** ✅ COMPLETE  
**Manual Verification:** ⚠️ PENDING

All code changes have been implemented and documented. Manual verification is required to confirm end-to-end behavior and Firestore persistence.

