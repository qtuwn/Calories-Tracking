# Double Trigger Fix + Error Logging Summary

## Problem Statement

- `applyExploreTemplate()` prints `[ApplyExplore] 🚀 START...` but does NOT print `[ApplyExplore] 🔄 calling service....`
- UI shows red snackbar "Không thể bắt đầu thực đơn…"
- Logs show `_startPlan()` is executed TWICE for a single click (duplicate lines)
- **Root cause:** Double-trigger + silent exception before service call

## Files Modified

### 1. `lib/features/meal_plans/presentation/pages/meal_detail_page.dart`

**Phase 1: Prevent Double-Trigger**
- **Line 49**: Added `bool _isStarting = false;` guard
- **Line 402**: Changed `onPressed: () => _startPlan()` to `onPressed: _isStarting ? null : () => _startPlan()`
- **Line 412**: Button text shows "Đang xử lý..." when `_isStarting == true`
- **Lines 838-842**: Early return if `_isStarting == true`
- **Lines 844-846**: Set `_isStarting = true` at start
- **Lines 1032-1036**: Reset `_isStarting = false` in `finally` block

**Phase 2: Print Real Error + Stack Trace**
- **Lines 1010-1018**: Enhanced error logging with full stack trace:
  ```dart
  debugPrint('[MealDetailPage] 🔥 ========== startPlan FAILED ==========');
  debugPrint('[MealDetailPage] 🔥 Error: $e');
  debugPrint('[MealDetailPage] 🔥 Error type: ${e.runtimeType}');
  debugPrint('[MealDetailPage] 🔥 Stack trace:');
  debugPrintStack(stackTrace: stackTrace);
  debugPrint('[MealDetailPage] 🔥 =======================================');
  ```

**Key Code Snippets:**

```dart
// BEFORE: No guard, button always enabled
ElevatedButton(
  onPressed: () => _startPlan(),
  child: Text('Áp dụng thực đơn'),
)

// AFTER: Guard prevents double-trigger
ElevatedButton(
  onPressed: _isStarting ? null : () => _startPlan(),
  child: Text(_isStarting ? 'Đang xử lý...' : 'Áp dụng thực đơn'),
)

// Guard implementation
Future<void> _startPlan() async {
  if (_isStarting) {
    debugPrint('[MealDetailPage] ⚠️ _startPlan() already in progress, ignoring duplicate call');
    return;
  }
  
  setState(() {
    _isStarting = true;
  });
  
  try {
    // ... apply logic ...
  } catch (e, stackTrace) {
    // Enhanced error logging
  } finally {
    if (mounted) {
      setState(() {
        _isStarting = false;
      });
    }
  }
}
```

### 2. `lib/features/meal_plans/state/applied_meal_plan_controller.dart`

**Phase 2: Print Real Error + Stack Trace**
- **Lines 96-102**: Entry logging with `[ApplyExplore]` tag
- **Lines 104-280**: Full try/catch wrapper with rethrow
- **Lines 272-280**: Enhanced error logging:
  ```dart
  print('[ApplyExplore] ❌ FAILED: $e');
  print('[ApplyExplore] ❌ Error type: ${e.runtimeType}');
  print('[ApplyExplore] ❌ Stack trace:');
  debugPrintStack(stackTrace: stackTrace);
  rethrow; // Always rethrow
  ```

**Phase 3: Add Step Markers**
- **Line 104**: `step: check widget mounted`
- **Line 110**: `step: read auth user`
- **Line 115**: `step: update state to loading`
- **Line 118**: `step: get service`
- **Line 123**: `step: load template from repository`
- **Line 135**: `step: template loaded`
- **Line 140**: `step: prepare profile data`
- **Line 144**: `step: call service.applyExploreTemplateAsActivePlan`
- **Line 150**: `step: service returned planId=...`
- **Line 153**: `step: check widget still mounted`
- **Line 157**: `step: verify active plan switched`
- **Line 188**: `step: verification passed`
- **Line 193**: `step: wait for cache confirmation`
- **Line 220**: `step: invalidate activeMealPlanProvider`
- **Line 225**: `step: update state to success`
- **Line 229**: `✅ DONE`

**Key Code Snippets:**

```dart
// BEFORE: No step markers, errors might be swallowed
try {
  final service = ...;
  final newPlan = await service.applyExploreTemplateAsActivePlan(...);
  // ...
} catch (e, stackTrace) {
  debugPrint('Error: $e');
  // Might not rethrow
}

// AFTER: Step markers + always rethrow
print('[ApplyExplore] 🚀 START applyExploreTemplate templateId=$templateId userId=$userId');
try {
  print('[ApplyExplore] step: check widget mounted');
  // ...
  print('[ApplyExplore] step: call service.applyExploreTemplateAsActivePlan');
  final newPlan = await service.applyExploreTemplateAsActivePlan(...);
  print('[ApplyExplore] step: service returned planId=${newPlan.id}');
  // ...
  print('[ApplyExplore] ✅ DONE');
} catch (e, stackTrace) {
  print('[ApplyExplore] ❌ FAILED: $e');
  print('[ApplyExplore] ❌ Stack trace:');
  debugPrintStack(stackTrace: stackTrace);
  rethrow; // Always rethrow
}
```

## Expected Runtime Log Sequence

### Successful Apply (Single Trigger)
```
[MealDetailPage] 🚀 _startPlan() called for template: template123
[ApplyExplore] 🚀 START applyExploreTemplate templateId=template123 userId=user456
[ApplyExplore] step: check widget mounted
[ApplyExplore] step: read auth user
[ApplyExplore] step: update state to loading
[ApplyExplore] step: get service
[ApplyExplore] step: load template from repository
[ApplyExplore] step: template loaded - name="Test Plan", days=7
[ApplyExplore] step: prepare profile data
[ApplyExplore] step: call service.applyExploreTemplateAsActivePlan
[UserMealPlanService] [ApplyExplore] 🚀 Starting apply explore template...
[UserMealPlanRepository] [ApplyExplore] ========== START applyExploreTemplateAsActivePlan ==========
[UserMealPlanRepository] [ApplyExplore] ✅ Batch committed successfully
[UserMealPlanService] [ApplyExplore] ✅ verification passed: New plan verified in Firestore
[ApplyExplore] step: service returned planId=user456_1234567890
[ApplyExplore] step: verify active plan switched
[ApplyExplore] step: verification passed - active plan switched to planId=user456_1234567890
[ApplyExplore] step: wait for cache confirmation
[ApplyExplore] step: invalidate activeMealPlanProvider
[ApplyExplore] step: update state to success
[ApplyExplore] ✅ DONE
[MealDetailPage] ✅ Verification passed: active plan switched to planId=user456_1234567890
```

### Failed Apply (Exception Before Service Call)
```
[MealDetailPage] 🚀 _startPlan() called for template: template123
[ApplyExplore] 🚀 START applyExploreTemplate templateId=template123 userId=user456
[ApplyExplore] step: check widget mounted
[ApplyExplore] step: read auth user
[ApplyExplore] step: update state to loading
[ApplyExplore] step: get service
[ApplyExplore] step: load template from repository
[ApplyExplore] ❌ FAILED: Exception: Template not found: template123
[ApplyExplore] ❌ Error type: Exception
[ApplyExplore] ❌ Stack trace:
#0 AppliedMealPlanController.applyExploreTemplate (applied_meal_plan_controller.dart:122)
#1 MealDetailPage._startPlan (meal_detail_page.dart:952)
...
[MealDetailPage] 🔥 ========== startPlan FAILED ==========
[MealDetailPage] 🔥 Error: Exception: Template not found: template123
[MealDetailPage] 🔥 Error type: Exception
[MealDetailPage] 🔥 Stack trace:
#0 AppliedMealPlanController.applyExploreTemplate (applied_meal_plan_controller.dart:122)
#1 MealDetailPage._startPlan (meal_detail_page.dart:952)
...
[MealDetailPage] Shows error snackbar
```

### Double-Trigger Prevention
```
[MealDetailPage] 🚀 _startPlan() called for template: template123
[ApplyExplore] 🚀 START applyExploreTemplate templateId=template123 userId=user456
[ApplyExplore] step: check widget mounted
...
[MealDetailPage] 🚀 _startPlan() called for template: template123 (DUPLICATE)
[MealDetailPage] ⚠️ _startPlan() already in progress, ignoring duplicate call
```

## Acceptance Test

**When user clicks "Bắt đầu" button:**
- ✅ Button is disabled immediately (`_isStarting = true`)
- ✅ Button text changes to "Đang xử lý..."
- ✅ `_startPlan()` executes only ONCE per click
- ✅ Logs show `[ApplyExplore] 🚀 START` → step markers → `✅ DONE` or `❌ FAILED`
- ✅ If exception occurs, full stack trace is printed
- ✅ Button is re-enabled after completion (`_isStarting = false`)

**Verification:**
- If logs show `_startPlan()` twice → guard failed (should not happen)
- If logs show `[ApplyExplore] 🚀 START` but no step markers → exception before step markers (now logged)
- If logs show step markers but stop at a specific step → we can pinpoint exact failure point

## Files Changed Summary

| File | Lines Changed | Purpose |
|------|---------------|---------|
| `meal_detail_page.dart` | ~30 lines | Double-trigger guard, enhanced error logging |
| `applied_meal_plan_controller.dart` | ~180 lines | Step markers, enhanced error logging, always rethrow |

**Total:** 2 files, ~210 lines changed

