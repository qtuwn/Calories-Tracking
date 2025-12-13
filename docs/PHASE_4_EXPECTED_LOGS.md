# Phase 4: Expected Log Sequence (Reference)

## Normal Apply Flow (Fast Network)

### Complete Log Sequence

```
I/flutter: [AppliedMealPlanController] [Explore] 🚀 Starting apply explore template flow for templateId=template123
I/flutter: [AppliedMealPlanController] [Explore] User ID: user456
I/flutter: [AppliedMealPlanController] [Explore] 📋 Loading template: template123
I/flutter: [AppliedMealPlanController] [Explore] ✅ Template loaded: Test Plan - Phase 4
I/flutter: [AppliedMealPlanController] [Explore] 📋 Template details: days=7, kcal=1800
I/flutter: [AppliedMealPlanController] [Explore] 🔄 Calling service.applyExploreTemplateAsActivePlan()...

I/flutter: [UserMealPlanService] [ApplyExplore] 🚀 Starting apply explore template: templateId=template123, userId=user456
I/flutter: [UserMealPlanService] [ApplyExplore] 🧹 Cleared stale active plan cache
I/flutter: [ApplyExplore] 🧾 template meta: desc="Test Description", tags=[Tag1, Tag2], difficulty=easy
I/flutter: [ApplyExplore] 🧾 userPlan meta: desc="Test Description", tags=[Tag1, Tag2], difficulty=easy

I/flutter: [UserMealPlanRepository] [ApplyExplore] ========== START applyExploreTemplateAsActivePlan ==========
I/flutter: [UserMealPlanRepository] [ApplyExplore] User ID: user456
I/flutter: [UserMealPlanRepository] [ApplyExplore] Template ID: template123
I/flutter: [UserMealPlanRepository] [ApplyExplore] Template name: "Test Plan - Phase 4"
I/flutter: [UserMealPlanRepository] [ApplyExplore] Generated plan ID: user456_1699123456789
I/flutter: [UserMealPlanRepository] [ApplyExplore] 🔄 Starting Firestore batch write...
I/flutter: [UserMealPlanRepository] [ApplyExplore] 🔄 Querying for existing active plans...
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ Will deactivate 1 old active plan(s)
I/flutter: [UserMealPlanRepository] [ApplyExplore] 🔄 Creating new active plan: user456_1699123456789
I/flutter: [UserMealPlanRepository] [ApplyExplore] Plan details: name="Test Plan - Phase 4", type=template, planTemplateId=template123
I/flutter: [UserMealPlanRepository] [ApplyExplore] 🧾 userPlan meta: desc="Test Description", tags=[Tag1, Tag2], difficulty=easy
I/flutter: [UserMealPlanRepository] [ApplyExplore] 🧾 Firestore payload includes: description=Test Description, tags=[Tag1, Tag2], difficulty=easy
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ New plan user456_1699123456789 will be created as active
I/flutter: [UserMealPlanRepository] [ApplyExplore] 💾 Committing batch with 2 operations...
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ Batch committed successfully
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ Verified: new plan document exists

I/flutter: [UserMealPlanRepository] [ApplyExplore] 📋 Copying meals from template to user plan...
I/flutter: [UserMealPlanRepository] [ApplyExplore] Template has 7 days
I/flutter: [UserMealPlanRepository] [ApplyExplore] 📋 Copying day 1...
I/flutter: [UserMealPlanRepository] [ApplyExplore] 📋 Found 4 meals for day 1
I/flutter: [UserMealPlanRepository] [ApplyExplore] 📋 Creating day document: users/user456/user_meal_plans/user456_1699123456789/days/1
I/flutter: [UserMealPlanRepository] [ApplyExplore] 📋 Writing meal document: .../meals/meal1 (foodId=food123, servingSize=1.5)
I/flutter: [UserMealPlanRepository] [ApplyExplore] 📋 Writing meal document: .../meals/meal2 (foodId=food456, servingSize=2.0)
I/flutter: [UserMealPlanRepository] [ApplyExplore] 📋 Writing meal document: .../meals/meal3 (foodId=food789, servingSize=1.0)
I/flutter: [UserMealPlanRepository] [ApplyExplore] 📋 Writing meal document: .../meals/meal4 (foodId=food012, servingSize=1.2)
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ Copied 4 meals for day 1
I/flutter: [UserMealPlanRepository] [ApplyExplore] 📋 Copying day 2...
... (days 2-7)
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ Finished copying template → user plan: 28 total meals across 7 days

I/flutter: [UserMealPlanRepository] [ApplyExplore] 🔍 Post-apply verification: checking days and meals...
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ Verified: plan has exactly 7 days
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ Verified day 1: 4 meals, totals match
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ Verified day 2: 4 meals, totals match
... (days 3-7)
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ Post-apply verification passed: all days have meals, totals match
I/flutter: [UserMealPlanRepository] [ApplyExplore] 🔍 Post-write verification: checking active plans...
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ Post-write verification passed: exactly 1 active plan (planId=user456_1699123456789)
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ ========== END applyExploreTemplateAsActivePlan (SUCCESS) ==========

I/flutter: [UserMealPlanService] [ApplyExplore] ✅ Repository returned new plan: planId=user456_1699123456789, name="Test Plan - Phase 4", isActive=true
I/flutter: [UserMealPlanService] [ApplyExplore] 🔍 Verifying new plan is queryable from Firestore...
I/flutter: [UserMealPlanService] [ApplyExplore] ✅ Verification attempt 1: New plan verified in Firestore (planId=user456_1699123456789)
I/flutter: [UserMealPlanService] [ApplyExplore] 🧹 Cleared cache again to force Firestore-first read
I/flutter: [UserMealPlanService] [ApplyExplore] ✅ Apply complete: planId=user456_1699123456789

I/flutter: [AppliedMealPlanController] [Explore] ✅ Successfully applied explore template: template123
I/flutter: [ApplyExplore] ✅ apply returned planId=user456_1699123456789
I/flutter: [ApplyExplore] ⏳ wait cache reflect newPlan attempt=1 cachedPlanId=null
I/flutter: [ApplyExplore] ⏳ wait cache reflect newPlan attempt=2 cachedPlanId=null
I/flutter: [ApplyExplore] ⏳ wait cache reflect newPlan attempt=3 cachedPlanId=null
I/flutter: [ApplyExplore] ⏳ wait cache reflect newPlan attempt=4 cachedPlanId=null
I/flutter: [ApplyExplore] ⏳ wait cache reflect newPlan attempt=5 cachedPlanId=null
I/flutter: [ApplyExplore] ⚠️ Cache confirmation failed after 5 attempts, delaying 500ms before invalidation
I/flutter: [ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=user456_1699123456789
I/flutter: [AppliedMealPlanController] [Explore] ✅ Apply complete - activeMealPlanProvider will emit new plan from Firestore

I/flutter: [ActiveMealPlanProvider] 🔵 Setting up active plan stream for uid=user456
I/flutter: [UserMealPlanService] [ActivePlan] 🔵 Setting up active plan stream for userId=user456
I/flutter: [ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
I/flutter: [ActivePlanCache] ✅ Firestore first emission received planId=user456_1699123456789
I/flutter: [UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore (first): planId=user456_1699123456789, name="Test Plan - Phase 4"
I/flutter: [MealUserActivePage] [ActivePlan] UI received active plan: user456_1699123456789, name=Test Plan - Phase 4
```

## Slow Network Flow (Firestore Timeout)

### Expected Log Sequence When Firestore Delays

```
I/flutter: [ApplyExplore] ✅ apply returned planId=user456_1699123456789
I/flutter: [ApplyExplore] ⏳ wait cache reflect newPlan attempt=1 cachedPlanId=null
... (5 attempts)
I/flutter: [ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=user456_1699123456789

I/flutter: [ActiveMealPlanProvider] 🔵 Setting up active plan stream for uid=user456
I/flutter: [UserMealPlanService] [ActivePlan] 🔵 Setting up active plan stream for userId=user456
I/flutter: [ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
I/flutter: [ActivePlanCache] ⚠️ Firestore timeout → emitting NULL (no cache fallback)
I/flutter: [ActivePlanCache] 🔁 Will continue streaming Firestore emissions...
I/flutter: [UserMealPlanService] [ActivePlan] 📦 Firestore timeout - emitting NULL (no cache fallback to prevent stale data)
I/flutter: [UserMealPlanService] [ActivePlan] 📡 Will continue streaming Firestore emissions...
I/flutter: [ActivePlanCache] 🔁 Firestore subsequent emission planId=user456_1699123456789
I/flutter: [UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore: planId=user456_1699123456789, name="Test Plan - Phase 4", isActive=true
I/flutter: [MealUserActivePage] [ActivePlan] UI received active plan: user456_1699123456789, name=Test Plan - Phase 4
```

**Key difference:** On timeout, UI briefly shows null/empty state, then updates to new plan. **NEVER shows old plan.**

## Consecutive Apply Flow

### First Template Apply

```
I/flutter: [UserMealPlanRepository] [ApplyExplore] 🔄 Deactivating old active plan: oldPlanId_12345
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ Will deactivate 1 old active plan(s)
I/flutter: [UserMealPlanRepository] [ApplyExplore] 🔄 Creating new active plan: user456_1111111111
...
I/flutter: [ApplyExplore] ✅ apply returned planId=user456_1111111111
I/flutter: [ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=user456_1111111111
```

### Second Template Apply (Immediately After)

```
I/flutter: [UserMealPlanRepository] [ApplyExplore] 🔄 Deactivating old active plan: user456_1111111111
I/flutter: [UserMealPlanRepository] [ApplyExplore] ✅ Will deactivate 1 old active plan(s)
I/flutter: [UserMealPlanRepository] [ApplyExplore] 🔄 Creating new active plan: user456_2222222222
...
I/flutter: [ApplyExplore] ✅ apply returned planId=user456_2222222222
I/flutter: [ApplyExplore] 🔄 invalidate activeMealPlanProvider planId=user456_2222222222
...
I/flutter: [ActivePlanCache] ✅ Firestore first emission received planId=user456_2222222222
I/flutter: [UserMealPlanService] [ActivePlan] 🔥 Emitting from Firestore (first): planId=user456_2222222222
```

**Key verification:** Only `user456_2222222222` is active. `user456_1111111111` has `isActive=false`.

## Firestore Document Verification

### Expected User Plan Document Structure

```json
{
  "userId": "user456",
  "planTemplateId": "template123",
  "name": "Test Plan - Phase 4",
  "description": "Test Description",          // ✅ Phase 1
  "tags": ["Tag1", "Tag2"],                   // ✅ Phase 1
  "difficulty": "easy",                        // ✅ Phase 1
  "goalType": "lose_fat",
  "type": "template",
  "startDate": Timestamp(...),
  "currentDayIndex": 1,
  "status": "active",
  "dailyCalories": 1800,
  "durationDays": 7,
  "isActive": true,
  "createdAt": Timestamp(...),
  "updatedAt": Timestamp(...)
}
```

### Expected Days Collection

```
users/user456/user_meal_plans/user456_1699123456789/days/
  ├── {dayDocId1}
  │   ├── dayIndex: 1
  │   ├── totalCalories: 1800.0
  │   ├── protein: 150.0
  │   ├── carb: 200.0
  │   ├── fat: 60.0
  │   └── meals/
  │       ├── {mealId1}
  │       ├── {mealId2}
  │       ├── {mealId3}
  │       └── {mealId4}
  ├── {dayDocId2}
  │   └── ... (days 2-7)
  ...
```

**Verification:**
- Exactly 7 day documents exist
- Each day has `dayIndex`: 1, 2, 3, 4, 5, 6, 7
- Each day has ≥ 1 meal document
- Day totals match sum of meals (verified by post-apply check)

## Verification Commands (Firebase Console)

### 1. Check Active Plan Metadata

```javascript
// Run in Firebase Console → Firestore → Data
const userId = 'user456';
const activePlans = await db.collection(`users/${userId}/user_meal_plans`)
  .where('isActive', '==', true)
  .get();

activePlans.forEach(doc => {
  const data = doc.data();
  console.log('✅ Active Plan:', doc.id);
  console.log('  name:', data.name);
  console.log('  description:', data.description || '❌ MISSING');
  console.log('  tags:', data.tags || '❌ MISSING');
  console.log('  difficulty:', data.difficulty || '❌ MISSING');
  console.log('  durationDays:', data.durationDays);
  console.log('  planTemplateId:', data.planTemplateId);
});
```

### 2. Check Days Count

```javascript
const planId = 'user456_1699123456789';
const daysSnapshot = await db.collection(`users/${userId}/user_meal_plans/${planId}/days`).get();
console.log(`Days count: ${daysSnapshot.size} (expected: 7)`);
console.log(daysSnapshot.size === 7 ? '✅ PASS' : '❌ FAIL');
```

### 3. Check Meals Per Day

```javascript
const daysSnapshot = await db.collection(`users/${userId}/user_meal_plans/${planId}/days`).get();
for (const dayDoc of daysSnapshot.docs) {
  const mealsSnapshot = await dayDoc.ref.collection('meals').get();
  const dayIndex = dayDoc.data().dayIndex;
  const mealCount = mealsSnapshot.size;
  console.log(`Day ${dayIndex}: ${mealCount} meals ${mealCount >= 1 ? '✅' : '❌'}`);
}
```

### 4. Check Active Plan Uniqueness

```javascript
const activePlans = await db.collection(`users/${userId}/user_meal_plans`)
  .where('isActive', '==', true)
  .get();
console.log(`Active plans: ${activePlans.size} (expected: 1)`);
if (activePlans.size === 1) {
  console.log('✅ PASS: Exactly one active plan');
} else {
  console.error('❌ FAIL: Multiple active plans detected!');
  activePlans.forEach(doc => {
    console.error(`  - ${doc.id}`);
  });
}
```

## Success Indicators

### ✅ Metadata Preservation
- User plan document contains `description`, `tags`, `difficulty`
- Logs show metadata copy at service and repository layers
- UI displays metadata (if UI supports it)

### ✅ Cache Stale Plan Fix
- Logs show `[ActivePlanCache] ⚠️ Firestore timeout → emitting NULL` on slow network
- UI NEVER shows old plan after apply
- UI may show loading/null briefly, then new plan

### ✅ Provider Invalidation Timing
- Logs show cache wait loop (5 attempts) before invalidation
- Logs show `[ApplyExplore] 🔄 invalidate` AFTER wait/delay
- No immediate invalidation

### ✅ Days/Meals Copy
- User plan has exactly 7 days
- Each day has ≥ 1 meal
- All meals have valid IDs and nutrition values

### ✅ Active Plan Consistency
- Exactly ONE active plan exists
- Old plans are deactivated
- UI shows only newest active plan

