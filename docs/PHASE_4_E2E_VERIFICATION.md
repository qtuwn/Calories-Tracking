# Phase 4: End-to-End Verification Guide

## Objective

Prove the fix addresses the exact user-visible symptom: **snackbar success AND new plan appears immediately (no old plan flash)**.

## Pre-Verification Setup

### 1. Create Explore Template with Metadata

**Via Admin UI:**
- Name: "Test Plan - Phase 4"
- Description: "Test Description"
- Tags: "Tag1,Tag2" (comma-separated)
- Difficulty: "easy"
- Goal Type: "lose_fat" (or any)
- Daily Calories: 1800
- Duration: 7 days
- Meals per day: 4

**Expected Firestore document:**
```
Collection: meal_plans/{templateId}
Fields:
  - name: "Test Plan - Phase 4"
  - description: "Test Description"
  - tags: ["Tag1", "Tag2"]
  - difficulty: "easy"
  - ... (other fields)
```

### 2. Add Meals to Template

**Via Admin Editor:**
- Add at least 1 meal per day for all 7 days
- Ensure each meal has:
  - Valid `foodId` (non-empty)
  - `servingSize > 0`
  - Valid nutrition values

**Verification:**
```bash
# Check template has meals in Firestore
firestore_path: meal_plans/{templateId}/days/{dayIndex}/meals/{mealId}
```

## Verification Scenario 1: Normal Apply Flow

### Steps

1. **User navigates to Explore tab**
2. **User taps on "Test Plan - Phase 4"**
3. **User taps "Start / Apply" button**
4. **Immediately navigate to "Your Meal Plans" tab**

### Expected Log Sequence

```
[AppliedMealPlanController] [Explore] 🚀 Starting apply explore template flow for templateId=...
[AppliedMealPlanController] [Explore] User ID: user123
[AppliedMealPlanController] [Explore] 📋 Loading template: ...
[AppliedMealPlanController] [Explore] ✅ Template loaded: Test Plan - Phase 4
[AppliedMealPlanController] [Explore] 📋 Template details: days=7, kcal=1800

[UserMealPlanService] [ApplyExplore] 🚀 Starting apply explore template: templateId=..., userId=user123
[UserMealPlanService] [ApplyExplore] 🧹 Cleared stale active plan cache
[ApplyExplore] 🧾 template meta: desc="Test Description", tags=[Tag1, Tag2], difficulty=easy
[ApplyExplore] 🧾 userPlan meta: desc="Test Description", tags=[Tag1, Tag2], difficulty=easy

[UserMealPlanRepository] [ApplyExplore] ========== START applyExploreTemplateAsActivePlan ==========
[UserMealPlanRepository] [ApplyExplore] User ID: user123
[UserMealPlanRepository] [ApplyExplore] Template ID: ...
[UserMealPlanRepository] [ApplyExplore] Template name: "Test Plan - Phase 4"
[UserMealPlanRepository] [ApplyExplore] Generated plan ID: user123_1234567890
[UserMealPlanRepository] [ApplyExplore] 🔄 Starting Firestore batch write...
[UserMealPlanRepository] [ApplyExplore] 🔄 Querying for existing active plans...
[UserMealPlanRepository] [ApplyExplore] ✅ Will deactivate X old active plan(s) (or "No existing active plan")
[UserMealPlanRepository] [ApplyExplore] 🔄 Creating new active plan: user123_1234567890
[UserMealPlanRepository] [ApplyExplore] Plan details: name="Test Plan - Phase 4", type=template, planTemplateId=...
[UserMealPlanRepository] [ApplyExplore] 🧾 userPlan meta: desc="Test Description", tags=[Tag1, Tag2], difficulty=easy
[UserMealPlanRepository] [ApplyExplore] 🧾 Firestore payload includes: description=Test Description, tags=[Tag1, Tag2], difficulty=easy
[UserMealPlanRepository] [ApplyExplore] ✅ New plan user123_1234567890 will be created as active
[UserMealPlanRepository] [ApplyExplore] 💾 Committing batch with X operations...
[UserMealPlanRepository] [ApplyExplore] ✅ Batch committed successfully
[UserMealPlanRepository] [ApplyExplore] ✅ Verified: new plan document exists

[UserMealPlanRepository] [ApplyExplore] 📋 Copying meals from template to user plan...
[UserMealPlanRepository] [ApplyExplore] Template has 7 days
[UserMealPlanRepository] [ApplyExplore] 📋 Copying day 1...
[UserMealPlanRepository] [ApplyExplore] 📋 Found N meals for day 1
[UserMealPlanRepository] [ApplyExplore] 📋 Creating day document: users/user123/user_meal_plans/user123_1234567890/days/1
[UserMealPlanRepository] [ApplyExplore] 📋 Writing meal document: ... (foodId=..., servingSize=...)
[UserMealPlanRepository] [ApplyExplore] ✅ Copied N meals for day 1
... (repeat for days 2-7)
[UserMealPlanRepository] [ApplyExplore] ✅ Finished copying template → user plan: X total meals across 7 days

[UserMealPlanRepository] [ApplyExplore] 🔍 Post-apply verification: checking days and meals...
[UserMealPlanRepository] [ApplyExplore] ✅ Verified: plan has exactly 7 days
[UserMealPlanRepository] [ApplyExplore] ✅ Verified day 1: N meals, totals match
... (repeat for days 2-7)
[UserMealPlanRepository] [ApplyExplore] ✅ Post-apply verification passed: all days have meals, totals match

[UserMealPlanRepository] [ApplyExplore] 🔍 Post-write verification: checking active plans...
[UserMealPlanRepository] [ApplyExplore] ✅ Post-write verification passed: exactly 1 active plan (planId=user123_1234567890)

[UserMealPlanService] [ApplyExplore] ✅ Repository returned new plan: planId=user123_1234567890, name="Test Plan - Phase 4", isActive=true
[UserMealPlanService] [ApplyExplore] 🔍 Verifying new plan is queryable from Firestore...
[UserMealPlanService] [ApplyExplore] ✅ Verification attempt 1: New plan verified in Firestore (planId=user123_1234567890)
[UserMealPlanService] [ApplyExplore] 🧹 Cleared cache again to force Firestore-first read
[UserMealPlanService] [ApplyExplore] ✅ Apply complete: planId=user123_1234567890

[ApplyExplore] ✅ apply returned planId=user123_1234567890
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=1 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=2 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=3 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=4 cachedPlanId=null
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=5 cachedPlanId=null
[ApplyExplore] ⚠️ Cache confirmation failed after 5 attempts, delaying 500ms before invalidation
[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=user123_1234567890

[ActiveMealPlanProvider] 🔵 Setting up active plan stream for uid=user123
[UserMealPlanService] [ActivePlan] 🔵 Setting up active plan stream for userId=user123
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
[ActivePlanCache] ✅ Firestore first emission received planId=user123_1234567890
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore (first): planId=user123_1234567890, name="Test Plan - Phase 4"
```

### Expected UI Behavior

1. **Snackbar shows:** "Đã bắt đầu thực đơn thành công!" (or equivalent)
2. **"Your Meal Plans" tab:**
   - Shows loading briefly (< 100ms)
   - Immediately shows "Test Plan - Phase 4" card
   - **NEVER shows old custom plan**
   - Plan card displays:
     - Name: "Test Plan - Phase 4"
     - Description: "Test Description" (if UI shows it)
     - Tags: Tag1, Tag2 (if UI shows them)
     - Difficulty: Easy badge (if UI shows it)

### Firestore Verification

**Check user plan document:**
```bash
Collection: users/user123/user_meal_plans/user123_1234567890
Fields:
  - name: "Test Plan - Phase 4"
  - description: "Test Description" ✅
  - tags: ["Tag1", "Tag2"] ✅
  - difficulty: "easy" ✅
  - isActive: true
  - planTemplateId: "{templateId}"
  - durationDays: 7
  - ... (other fields)
```

**Check days exist:**
```bash
Collection: users/user123/user_meal_plans/user123_1234567890/days
- Should have exactly 7 documents
- Each day has dayIndex: 1, 2, 3, 4, 5, 6, 7
```

**Check meals exist:**
```bash
Collection: users/user123/user_meal_plans/user123_1234567890/days/{dayDocId}/meals
- Each day should have ≥ 1 meal document
- Each meal has: foodId, servingSize, calories, protein, carb, fat
```

**Check active plan query:**
```bash
Query: users/user123/user_meal_plans where isActive==true
Result: Should return exactly 1 document (user123_1234567890)
```

## Verification Scenario 2: Slow Network / Firestore Delay

### Steps

1. **Enable Network Throttling:**
   - Chrome DevTools: Network tab → Throttling → "Slow 3G" or "Fast 3G"
   - OR use physical slow network

2. **Apply template as user**
3. **Immediately navigate to "Your Meal Plans" tab**

### Expected Log Sequence (Slow Network)

```
[ApplyExplore] ✅ apply returned planId=user123_1234567890
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=1 cachedPlanId=null
... (5 attempts, cache stays null)
[ApplyExplore] ⚠️ Cache confirmation failed after 5 attempts, delaying 500ms before invalidation
[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=user123_1234567890

[ActiveMealPlanProvider] 🔵 Setting up active plan stream for uid=user123
[UserMealPlanService] [ActivePlan] 🔵 Setting up active plan stream for userId=user123
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms

# If Firestore emits within 3000ms:
[ActivePlanCache] ✅ Firestore first emission received planId=user123_1234567890
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore (first): planId=user123_1234567890

# If Firestore times out (> 3000ms):
[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)
[ActivePlanCache] 🔁 Will continue streaming Firestore emissions...
[UserMealPlanService] [ActivePlan] 📦 Firestore timeout - emitting NULL (no cache fallback to prevent stale data)
[ActivePlanCache] 🔁 Firestore subsequent emission planId=user123_1234567890
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore: planId=user123_1234567890
```

### Expected UI Behavior (Slow Network)

**Case 1: Firestore emits within 3000ms**
- Shows loading briefly
- Shows new plan immediately

**Case 2: Firestore times out (> 3000ms)**
- Shows loading
- **May show null/empty state briefly** (NOT old plan)
- Then shows new plan when Firestore emits
- **NEVER shows old custom plan**

## Verification Scenario 3: Consecutive Apply (Two Templates)

### Steps

1. **Apply "Template A"**
2. **Immediately apply "Template B"**
3. **Navigate to "Your Meal Plans" tab**

### Expected Log Sequence

**First Apply (Template A):**
```
[UserMealPlanRepository] [ApplyExplore] 🔄 Deactivating old active plan: oldPlanId
[UserMealPlanRepository] [ApplyExplore] ✅ Will deactivate 1 old active plan(s)
[UserMealPlanRepository] [ApplyExplore] 🔄 Creating new active plan: user123_1111111111
...
[ApplyExplore] ✅ apply returned planId=user123_1111111111
...
[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=user123_1111111111
```

**Second Apply (Template B - immediately after):**
```
[UserMealPlanRepository] [ApplyExplore] 🔄 Deactivating old active plan: user123_1111111111
[UserMealPlanRepository] [ApplyExplore] ✅ Will deactivate 1 old active plan(s)
[UserMealPlanRepository] [ApplyExplore] 🔄 Creating new active plan: user123_2222222222
...
[ApplyExplore] ✅ apply returned planId=user123_2222222222
...
[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=user123_2222222222
```

### Expected UI Behavior

1. **After first apply:** Shows "Template A"
2. **After second apply:** Shows "Template B" (Template A is hidden)
3. **"Your Meal Plans" tab:** Only shows "Template B"

### Firestore Verification

**Check active plans:**
```bash
Query: users/user123/user_meal_plans where isActive==true
Result: Should return exactly 1 document (user123_2222222222)
```

**Check old plan:**
```bash
Document: users/user123/user_meal_plans/user123_1111111111
Field isActive: false ✅
Field status: "paused" ✅
```

## Verification Checklist Summary

### Metadata Preservation (Phase 1)

- [ ] Template has description, tags, difficulty
- [ ] Apply logs show metadata copy:
  - `[ApplyExplore] 🧾 template meta: desc=..., tags=..., difficulty=...`
  - `[ApplyExplore] 🧾 userPlan meta: desc=..., tags=..., difficulty=...`
  - `[UserMealPlanRepository] [ApplyExplore] 🧾 Firestore payload includes: description=..., tags=..., difficulty=...`
- [ ] Firestore user plan document contains:
  - `description: "Test Description"`
  - `tags: ["Tag1", "Tag2"]`
  - `difficulty: "easy"`

### Cache Stale Plan Fix (Phase 2)

- [ ] Logs show timeout wait:
  - `[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms`
- [ ] On timeout, logs show:
  - `[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)`
- [ ] UI NEVER shows old plan after apply
- [ ] UI may show loading/null briefly on slow network, then new plan

### Provider Invalidation Timing (Phase 3)

- [ ] Logs show cache wait loop:
  - `[ApplyExplore] ⏳ wait cache reflect newPlan attempt=1 cachedPlanId=...`
  - ... (up to 5 attempts)
- [ ] Logs show invalidation AFTER wait:
  - `[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=...`
- [ ] No immediate invalidation (verified by log order)

### Days/Meals Copy (Previous Fix)

- [ ] Firestore has exactly 7 day documents
- [ ] Each day has ≥ 1 meal document
- [ ] All meals have valid foodId, servingSize > 0
- [ ] Day totals match sum of meals

### Active Plan Consistency

- [ ] Exactly ONE active plan exists at any time
- [ ] Old plan is deactivated (isActive=false) when new plan is applied
- [ ] UI shows only the newest active plan

## Expected Log Tag Sequence (Normal Flow)

```
[AppliedMealPlanController] [Explore] 🚀
[AppliedMealPlanController] [Explore] 📋
[AppliedMealPlanController] [Explore] ✅
[UserMealPlanService] [ApplyExplore] 🚀
[UserMealPlanService] [ApplyExplore] 🧹
[ApplyExplore] 🧾 template meta
[ApplyExplore] 🧾 userPlan meta
[UserMealPlanRepository] [ApplyExplore] ========== START
[UserMealPlanRepository] [ApplyExplore] 🔄
[UserMealPlanRepository] [ApplyExplore] 🧾 userPlan meta
[UserMealPlanRepository] [ApplyExplore] 🧾 Firestore payload includes
[UserMealPlanRepository] [ApplyExplore] 📋 Copying day X
[UserMealPlanRepository] [ApplyExplore] ✅ Copied N meals for day X
[UserMealPlanRepository] [ApplyExplore] ✅ Finished copying template → user plan
[UserMealPlanRepository] [ApplyExplore] ✅ Post-apply verification passed
[UserMealPlanService] [ApplyExplore] ✅ Repository returned new plan
[UserMealPlanService] [ApplyExplore] ✅ Verification attempt X: New plan verified
[ApplyExplore] ✅ apply returned planId=...
[ApplyExplore] ⏳ wait cache reflect newPlan attempt=X
[ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=...
[ActiveMealPlanProvider] 🔵
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
[ActivePlanCache] ✅ Firestore first emission received planId=...
[UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore (first)
```

## Firestore Document Verification Commands

### Check User Plan Metadata

```javascript
// Firebase Console → Firestore
db.collection('users/{userId}/user_meal_plans')
  .where('isActive', '==', true)
  .get()
  .then(snapshot => {
    snapshot.forEach(doc => {
      console.log('Active Plan:', doc.id);
      console.log('  description:', doc.data().description);
      console.log('  tags:', doc.data().tags);
      console.log('  difficulty:', doc.data().difficulty);
      console.log('  durationDays:', doc.data().durationDays);
    });
  });
```

### Check Days Count

```javascript
db.collection('users/{userId}/user_meal_plans/{planId}/days')
  .get()
  .then(snapshot => {
    console.log('Days count:', snapshot.size);
    console.log('Expected:', 7);
  });
```

### Check Meals Per Day

```javascript
db.collection('users/{userId}/user_meal_plans/{planId}/days')
  .get()
  .then(async (daysSnapshot) => {
    for (const dayDoc of daysSnapshot.docs) {
      const mealsSnapshot = await dayDoc.ref.collection('meals').get();
      console.log(`Day ${dayDoc.data().dayIndex}: ${mealsSnapshot.size} meals`);
    }
  });
```

### Check Active Plan Uniqueness

```javascript
db.collection('users/{userId}/user_meal_plans')
  .where('isActive', '==', true)
  .get()
  .then(snapshot => {
    console.log('Active plans count:', snapshot.size);
    console.log('Expected: 1');
    if (snapshot.size > 1) {
      console.error('❌ VIOLATION: Multiple active plans!');
    }
  });
```

## Success Criteria

### ✅ Phase 1 (Metadata)
- User plan Firestore document contains `description`, `tags`, `difficulty`
- Logs show metadata copy at service and repository layers

### ✅ Phase 2 (Cache)
- UI NEVER shows old plan after apply
- On slow network, UI may show loading/null, then new plan
- Logs show `[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL` if timeout occurs

### ✅ Phase 3 (Provider Invalidation)
- Provider invalidation happens AFTER cache wait/delay
- Logs show cache wait loop before invalidation

### ✅ Days/Meals Copy
- User plan has exactly `durationDays` day documents
- Each day has ≥ 1 meal document
- All meals have valid IDs and nutrition values

### ✅ Active Plan Consistency
- Exactly ONE active plan exists after apply
- Old plans are deactivated (isActive=false)
- UI shows only the newest active plan

## Failure Indicators (Red Flags)

- ❌ UI shows old custom plan after applying new template
- ❌ User plan Firestore document missing `description`, `tags`, or `difficulty`
- ❌ User plan has 0 days
- ❌ User plan days have 0 meals
- ❌ Multiple active plans exist simultaneously
- ❌ Provider invalidates immediately (no cache wait logs)
- ❌ Cache emits stale plan on timeout (should emit null)

