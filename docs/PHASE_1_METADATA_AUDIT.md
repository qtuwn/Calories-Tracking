# Phase 1: Metadata Fields Audit & Fix

## Audit Findings

### Step 1: Data Model & DTO Audit

**Domain Model** (`lib/domain/meal_plans/explore_meal_plan.dart`):
- ✅ `description` (required String)
- ✅ `tags` (required List<String>)
- ✅ `difficulty` (optional String?)
- ✅ `copyWith()` includes all fields
- ✅ `toJson()` / `fromJson()` includes all fields

**DTO** (`lib/data/meal_plans/explore_meal_plan_dto.dart`):
- ✅ `description` (required String)
- ✅ `tags` (required List<String>)
- ✅ `difficulty` (optional String?)
- ✅ `fromFirestore()` parses all fields correctly
- ✅ `toFirestore()` includes `description` and `tags` always
- ⚠️ `toFirestore()` only includes `difficulty` if not null (line 85) - **This is correct behavior for optional fields**

**Mapping Points:**
1. `ExploreMealPlanDto.fromFirestore()` → ✅ Includes all fields
2. `ExploreMealPlanDto.toFirestore()` → ✅ Includes all fields (difficulty conditionally)
3. `ExploreMealPlanDto.fromDomain()` → ✅ Includes all fields
4. `ExploreMealPlanDto.toDomain()` → ✅ Includes all fields

### Step 2: Firestore Write Paths Audit

**Create Path** (`firestore_explore_meal_plan_repository.dart:326-345`):
- ✅ Uses `docRef.set(dtoWithId.toFirestore())` - Full document write
- ✅ DTO includes all fields from form

**Update Path** (`firestore_explore_meal_plan_repository.dart:348-364`):
- ⚠️ Uses `docRef.update(dto.toFirestore())` - **PROBLEM**: `.update()` with full DTO map
- ❌ If DTO has `tags: []` or `difficulty: null`, it will overwrite existing values

**Editor Save Path** (`explore_meal_plan_admin_editor_page.dart:534-548`):
- ❌ **CRITICAL BUG**: Hardcodes `tags: []` (line 542)
- ❌ **CRITICAL BUG**: Doesn't set `difficulty` (defaults to null)
- ❌ **CRITICAL BUG**: Doesn't preserve `createdBy` from existing template

**Editor Load Path** (`explore_meal_plan_admin_editor_page.dart:66-103`):
- ✅ Loads `description` into controller
- ❌ **BUG**: Doesn't load `tags` into state
- ❌ **BUG**: Doesn't load `difficulty` into state

### Step 3: UI Rendering Audit

**Admin List** (`explore_meal_plan_list_page.dart:141-184`):
- ✅ Shows `name`, `goalType`, `templateKcal`, `durationDays`, `mealsPerDay`
- ✅ Shows `tags` (lines 155-165)
- ❌ **MISSING**: `description` (not shown)
- ❌ **MISSING**: `difficulty` (not shown)

**User Explore List** (`meal_explore_page.dart:174-196`):
- ✅ Uses `MealPlanSummaryCard` which shows `description` and `tags`
- ❌ **MISSING**: `difficulty` (not passed to card)

**Detail Page** (`meal_detail_page.dart:94-150`):
- ✅ Shows `name`, `description` (lines 121-127)
- ✅ Shows `tags` (lines 147-150)
- ❌ **MISSING**: `difficulty` (not shown)

**MealPlanSummaryCard** (`meal_plan_summary_card.dart`):
- ✅ Shows `subtitle` (description)
- ✅ Shows `tags`
- ❌ **MISSING**: No `difficulty` parameter

## Root Causes

1. **Editor Save Bug**: `_saveTemplate()` hardcodes `tags: []` and doesn't preserve `difficulty` or `createdBy`
2. **Editor Load Bug**: `_loadExistingTemplate()` doesn't load `tags` or `difficulty` into state variables
3. **UI Missing Fields**: `difficulty` is not displayed in any UI component

## Fix Plan

### Fix 1: Editor Load - Preserve Metadata
- Add state variables: `_existingTags`, `_existingDifficulty`, `_existingCreatedBy`
- Load these from template in `_loadExistingTemplate()`

### Fix 2: Editor Save - Preserve Metadata
- Use preserved values when creating `ExploreMealPlan` in `_saveTemplate()`
- Ensure `tags`, `difficulty`, and `createdBy` are preserved

### Fix 3: UI Display - Add Difficulty
- Add `difficulty` parameter to `MealPlanSummaryCard`
- Display difficulty badge in admin list, user list, and detail page
- Create helper function: `difficultyToLabel(String? difficulty)`

### Fix 4: Firestore Update - Use Merge or Targeted Updates
- Change `updatePlan()` to use targeted field updates OR ensure DTO always has all fields
- Actually, `.update()` is fine IF we ensure the DTO has all fields (which we'll fix in Fix 2)

## Verification Checklist

- [ ] Editor loads existing `tags` and `difficulty`
- [ ] Editor preserves `tags` and `difficulty` when saving
- [ ] Firestore documents contain `tags` and `difficulty` after save
- [ ] Admin list shows `difficulty` badge
- [ ] User explore list shows `difficulty` badge
- [ ] Detail page shows `difficulty` badge
- [ ] DTO roundtrip test passes
- [ ] Editor save regression test passes

