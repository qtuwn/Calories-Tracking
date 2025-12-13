# Phase 1: Metadata Fields Fix Summary

## Problem Statement

In "Create Explore Meal Plan" form, user inputs:
- `description`
- `tags` (comma separated)
- `difficulty` (easy/medium/hard)

But after creation:
- These fields were missing in admin list UI
- These fields were missing in user explore list UI
- Sometimes they appeared in Firestore inconsistently (suggests overwriting / mapping loss)

## Root Causes Identified

### 1. Editor Save Path Bug (CRITICAL)
**File**: `lib/features/meal_plans/presentation/pages/explore_meal_plan_admin_editor_page.dart`

**Location**: `_saveTemplate()` method, lines 534-548

**Issue**: When saving template metadata, the code hardcoded:
- `tags: []` (empty list - **BUG**)
- `difficulty: null` (not set - **BUG**)
- `createdBy: null` (not preserved - **BUG**)

**Impact**: When admin saves meals in the editor, it overwrote existing metadata with empty/null values.

### 2. Editor Load Path Bug
**File**: `lib/features/meal_plans/presentation/pages/explore_meal_plan_admin_editor_page.dart`

**Location**: `_loadExistingTemplate()` method, lines 66-103

**Issue**: When loading existing template, the code only loaded:
- `description` ✅
- But NOT `tags` ❌
- But NOT `difficulty` ❌
- But NOT `createdBy` ❌

**Impact**: Editor couldn't preserve metadata because it never loaded it into state.

### 3. UI Missing Fields
**Files**:
- `lib/features/admin_explore_meal_plans/presentation/pages/explore_meal_plan_list_page.dart`
- `lib/features/meal_plans/presentation/pages/meal_explore_page.dart`
- `lib/features/meal_plans/presentation/pages/meal_detail_page.dart`

**Issue**: `difficulty` field was not displayed in any UI component.

**Impact**: Even if data was stored correctly, users couldn't see it.

## Fixes Applied

### Fix 1: Editor Load - Preserve Metadata
**File**: `lib/features/meal_plans/presentation/pages/explore_meal_plan_admin_editor_page.dart`

**Changes**:
1. Added state variables:
   ```dart
   List<String> _existingTags = [];
   String? _existingDifficulty;
   String? _existingCreatedBy;
   ```

2. Load metadata when loading existing template:
   ```dart
   _existingTags = List<String>.from(template.tags);
   _existingDifficulty = template.difficulty;
   _existingCreatedBy = template.createdBy;
   ```

### Fix 2: Editor Save - Preserve Metadata
**File**: `lib/features/meal_plans/presentation/pages/explore_meal_plan_admin_editor_page.dart`

**Changes**:
1. Use preserved values when creating `ExploreMealPlan`:
   ```dart
   tags: _existingTags, // Preserve existing tags (loaded from template)
   createdBy: _existingCreatedBy, // Preserve createdBy from existing template
   difficulty: _existingDifficulty, // Preserve difficulty from existing template
   ```

**Before**:
```dart
tags: [], // BUG: Hardcoded empty
// difficulty: null (not set)
// createdBy: null (not set)
```

**After**:
```dart
tags: _existingTags, // Preserve from loaded template
createdBy: _existingCreatedBy, // Preserve from loaded template
difficulty: _existingDifficulty, // Preserve from loaded template
```

### Fix 3: UI Display - Add Difficulty
**Files Modified**:
1. `lib/features/meal_plans/presentation/widgets/difficulty_helper.dart` (NEW)
   - Helper functions for difficulty display
   - `difficultyToLabel()`: Converts "easy" → "Dễ", "medium" → "Trung bình", "hard" → "Khó"
   - `difficultyToColor()`: Returns color for badge
   - `difficultyToIcon()`: Returns icon for badge

2. `lib/features/meal_plans/presentation/widgets/meal_plan_summary_card.dart`
   - Added `difficulty` parameter
   - Added difficulty badge display alongside tags

3. `lib/features/meal_plans/presentation/pages/meal_explore_page.dart`
   - Pass `difficulty: plan.difficulty` to `MealPlanSummaryCard`

4. `lib/features/admin_explore_meal_plans/presentation/pages/explore_meal_plan_list_page.dart`
   - Added `description` display (snippet with maxLines: 2)
   - Added difficulty badge in tags section

5. `lib/features/meal_plans/presentation/pages/meal_detail_page.dart`
   - Added difficulty badge alongside tags

### Fix 4: Tests
**File**: `test/data/meal_plans/explore_meal_plan_dto_metadata_test.dart` (NEW)

**Test Coverage**:
- ✅ `toFirestore()` includes description, tags, and difficulty
- ✅ `fromDomain()` preserves all metadata fields
- ✅ Roundtrip: domain → DTO → Firestore map preserves metadata
- ✅ Handles null/empty metadata fields correctly
- ✅ `toFirestore()` omits null optional fields (correct behavior)

**Test Results**: All 5 tests pass ✅

## Verification Checklist

### Data Persistence
- [x] Creating an explore plan persists `description`/`tags`/`difficulty` in Firestore
- [x] Editing meals and saving does NOT wipe these fields
- [x] DTO roundtrip tests pass

### UI Display
- [x] Admin list shows `description` snippet
- [x] Admin list shows `tags` chips
- [x] Admin list shows `difficulty` badge
- [x] User explore list shows `description` (via MealPlanSummaryCard)
- [x] User explore list shows `tags` (via MealPlanSummaryCard)
- [x] User explore list shows `difficulty` badge (via MealPlanSummaryCard)
- [x] Detail page shows `description`
- [x] Detail page shows `tags`
- [x] Detail page shows `difficulty` badge

### Code Quality
- [x] `flutter analyze` passes with no errors
- [x] All tests pass
- [x] No forbidden patterns reintroduced

## Files Changed

### Modified Files:
1. `lib/features/meal_plans/presentation/pages/explore_meal_plan_admin_editor_page.dart`
   - Added state variables for `_existingTags`, `_existingDifficulty`, `_existingCreatedBy`
   - Load metadata in `_loadExistingTemplate()`
   - Preserve metadata in `_saveTemplate()`

2. `lib/features/meal_plans/presentation/widgets/meal_plan_summary_card.dart`
   - Added `difficulty` parameter
   - Added difficulty badge display

3. `lib/features/meal_plans/presentation/pages/meal_explore_page.dart`
   - Pass `difficulty` to `MealPlanSummaryCard`

4. `lib/features/admin_explore_meal_plans/presentation/pages/explore_meal_plan_list_page.dart`
   - Added `description` display
   - Added difficulty badge

5. `lib/features/meal_plans/presentation/pages/meal_detail_page.dart`
   - Added difficulty badge alongside tags

### Created Files:
1. `lib/features/meal_plans/presentation/widgets/difficulty_helper.dart`
   - Helper functions for difficulty display

2. `test/data/meal_plans/explore_meal_plan_dto_metadata_test.dart`
   - Unit tests for DTO metadata preservation

3. `docs/PHASE_1_METADATA_AUDIT.md`
   - Complete audit findings

4. `docs/PHASE_1_METADATA_FIX_SUMMARY.md`
   - This summary document

## Code Changes (Patch-Style Snippets)

### Patch 1: Editor State Variables
```dart
// lib/features/meal_plans/presentation/pages/explore_meal_plan_admin_editor_page.dart

  String? _existingPlanId;
  bool? _existingIsPublished;
  bool? _existingIsEnabled;
  DateTime? _existingCreatedAt;
+ List<String> _existingTags = [];
+ String? _existingDifficulty;
+ String? _existingCreatedBy;
```

### Patch 2: Load Metadata
```dart
// lib/features/meal_plans/presentation/pages/explore_meal_plan_admin_editor_page.dart

        _existingPlanId = widget.planId;
        // Preserve publish flags and createdAt when updating (don't overwrite form's settings)
        _existingIsPublished = template.isPublished;
        _existingIsEnabled = template.isEnabled;
        _existingCreatedAt = template.createdAt;
+       _existingTags = List<String>.from(template.tags); // Preserve tags
+       _existingDifficulty = template.difficulty; // Preserve difficulty
+       _existingCreatedBy = template.createdBy; // Preserve createdBy
```

### Patch 3: Preserve Metadata on Save
```dart
// lib/features/meal_plans/presentation/pages/explore_meal_plan_admin_editor_page.dart

        mealsPerDay: 4, // Default
-       tags: [],
+       tags: _existingTags, // Preserve existing tags (loaded from template)
        isFeatured: false,
        isPublished: _existingIsPublished ?? false, // Preserve existing or default to false for new
        isEnabled: _existingIsEnabled ?? true, // Preserve existing or default to true
        createdAt: _existingCreatedAt ?? DateTime.now(), // Preserve original createdAt when updating
        updatedAt: DateTime.now(), // Always update timestamp
+       createdBy: _existingCreatedBy, // Preserve createdBy from existing template
+       difficulty: _existingDifficulty, // Preserve difficulty from existing template
```

### Patch 4: Difficulty Helper (New File)
```dart
// lib/features/meal_plans/presentation/widgets/difficulty_helper.dart

import 'package:flutter/material.dart';

/// Helper functions for difficulty display
class DifficultyHelper {
  /// Convert difficulty string to localized label
  static String? difficultyToLabel(String? difficulty) {
    if (difficulty == null || difficulty.isEmpty) return null;
    switch (difficulty.toLowerCase()) {
      case 'easy': return 'Dễ';
      case 'medium': return 'Trung bình';
      case 'hard': return 'Khó';
      default: return difficulty;
    }
  }
  
  /// Get color for difficulty badge
  static Color? difficultyToColor(String? difficulty) {
    if (difficulty == null || difficulty.isEmpty) return null;
    switch (difficulty.toLowerCase()) {
      case 'easy': return const Color(0xFF4CAF50); // Green
      case 'medium': return const Color(0xFFFF9800); // Orange
      case 'hard': return const Color(0xFFF44336); // Red
      default: return null;
    }
  }
  
  /// Get icon for difficulty badge
  static IconData? difficultyToIcon(String? difficulty) {
    if (difficulty == null || difficulty.isEmpty) return null;
    switch (difficulty.toLowerCase()) {
      case 'easy': return Icons.sentiment_satisfied;
      case 'medium': return Icons.sentiment_neutral;
      case 'hard': return Icons.sentiment_very_dissatisfied;
      default: return null;
    }
  }
}
```

### Patch 5: UI - MealPlanSummaryCard
```dart
// lib/features/meal_plans/presentation/widgets/meal_plan_summary_card.dart

    this.tags = const [],
+   this.difficulty,
    this.isActive = false,
    this.currentDayIndex,
    this.onTap,
  });

  final List<String> tags;
+ final String? difficulty;
  final bool isActive;
```

```dart
// In build method:
-           if (tags.isNotEmpty) ...[
+           if (tags.isNotEmpty || difficulty != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  // Tags
                  ...tags.map((tag) => Chip(...)),
+                 // Difficulty badge
+                 if (difficulty != null)
+                   Chip(
+                     avatar: Icon(
+                       DifficultyHelper.difficultyToIcon(difficulty),
+                       size: 16,
+                       color: DifficultyHelper.difficultyToColor(difficulty),
+                     ),
+                     label: Text(
+                       DifficultyHelper.difficultyToLabel(difficulty) ?? difficulty!,
+                       style: Theme.of(context).textTheme.labelMedium?.copyWith(
+                         color: DifficultyHelper.difficultyToColor(difficulty) ?? AppColors.nearBlack,
+                         fontWeight: FontWeight.w600,
+                       ),
+                     ),
+                     backgroundColor: (DifficultyHelper.difficultyToColor(difficulty) ?? AppColors.mediumGray)
+                         .withValues(alpha: 0.18),
+                     materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
+                   ),
                ],
              ),
            ],
```

## Acceptance Criteria (All Met)

✅ Creating an explore plan persists `description`/`tags`/`difficulty` in Firestore consistently  
✅ Editing meals and saving does NOT wipe these fields  
✅ Admin and user UIs show these fields (where designed)  
✅ DTO roundtrip tests pass

## Impact

### Before Phase 1:
- ❌ Editor overwrote `tags` with empty list
- ❌ Editor didn't preserve `difficulty`
- ❌ Editor didn't preserve `createdBy`
- ❌ UI didn't display `difficulty` anywhere
- ❌ Admin list didn't show `description`

### After Phase 1:
- ✅ Editor preserves all metadata when saving
- ✅ Editor loads all metadata when editing
- ✅ UI displays `difficulty` badge in all relevant places
- ✅ Admin list shows `description` snippet
- ✅ All metadata fields persist correctly in Firestore
- ✅ Tests verify DTO roundtrip preservation

## Conclusion

Phase 1 successfully fixes the metadata persistence and display issues:

- ✅ **Root cause fixed**: Editor now preserves `tags`, `difficulty`, and `createdBy`
- ✅ **UI enhanced**: All metadata fields are now displayed in admin list, user list, and detail page
- ✅ **Tests added**: DTO roundtrip tests verify metadata preservation
- ✅ **No regressions**: All existing functionality preserved

The Explore Meal Plans feature now correctly persists and displays all metadata fields end-to-end.

