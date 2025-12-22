# Bug Report: Donut Chart Display Issues - Onboarding Module

**Date:** December 23, 2025  
**Module:** Onboarding - Macro Step Screen  
**Severity:** Medium  
**Status:** Pending Review

---

## Executive Summary

The donut chart in the Macro Step Screen displays incorrectly due to multiple calculation and synchronization issues. The chart visualization doesn't properly reflect the nutritional distribution percentages, particularly when users adjust macro values.

---

## Critical Runtime Error Found

### ⚠️ PROVIDER MODIFICATION IN initState (CRASHES APP)

**File:** `lib/features/onboarding/presentation/screens/weekly_delta_step_screen.dart` (Lines 25-32)

**Error Message:**

```
Tried to modify a provider while the widget tree was building.
If you are encountering this error, chances are you tried to modify a provider
in a widget life-cycle, such as but not limited to:
- build
- initState ❌ THIS IS HAPPENING HERE
- dispose
- didUpdateWidget
- didChangeDependencies
```

**Problematic Code:**

```dart
@override
void initState() {
  super.initState();
  final onboardingState = ref.read(onboardingControllerProvider);
  _weeklyDelta = onboardingState.weeklyDeltaKg ?? 0.5;
  // Save initial value
  ref
      .read(onboardingControllerProvider.notifier)
      .updateWeeklyDelta(_weeklyDelta);  // ❌ MODIFYING PROVIDER IN initState
}
```

**Why This Crashes:**

- Flutter's Riverpod doesn't allow modifying providers during widget lifecycle
- Calling `updateWeeklyDelta()` which internally calls `_updateState()` triggers provider mutation
- This violates Flutter's widget building contract
- The widget tree is still being built when the mutation happens
- Results in inconsistent UI state

**Stack Trace:**

```
#11    OnboardingController._updateState
#12    WeeklyDeltaStepScreenState.initState
#13    StatefulElement._firstBuild
```

---

## Issues Identified

### 1. **Donut Chart Normalization Issue** 🔴

**File:** `lib/features/onboarding/presentation/widgets/donut_chart_widget.dart` (Lines 45-48)

**Problem:**

```dart
final total = proteinPercent + carbPercent + fatPercent;
final proteinAngle = (proteinPercent / total) * 360;
final carbAngle = (carbPercent / total) * 360;
final fatAngle = (fatPercent / total) * 360;
```

**Description:**

- The code normalizes percentages by dividing by the actual `total` instead of assuming 100%
- If the total is not exactly 100% (e.g., 99.5% or 100.5%), the chart segments will be distorted
- The visual angle distribution won't match the intended percentage values shown in the legend
- This causes a mismatch between what the legend displays and what the chart shows

**Impact:**

- Chart segments appear disproportionate
- User confusion between displayed percentages and visual representation
- Data integrity issue when percentages don't sum to exactly 100%

**Example Scenario:**

- User sets: Protein 31%, Carb 23%, Fat 46% (Total = 100%)
- If due to rounding or calculation: Protein 31%, Carb 23%, Fat 45.9% (Total = 99.9%)
- Chart will render with slightly larger segments than percentage values suggest

---

### 2. **Progress Indicator Hardcoded Value** 🔴

**File:** `lib/features/onboarding/presentation/screens/macro_step_screen.dart` (Lines 64-67)

**Problem:**

```dart
ProgressIndicatorWidget(
  progress: 11 / OnboardingModel.totalSteps,
),
```

**Description:**

- The progress value is hardcoded to `11 / totalSteps`
- This assumes the Macro Step is always step 11, which may not be accurate
- If `OnboardingModel.totalSteps` changes, the progress percentage becomes incorrect
- In the screenshot, it displays 100%, but the code shows ~10% (11/12 if totalSteps=12)

**Impact:**

- Progress indicator shows incorrect completion percentage
- Users get false sense of progress through the onboarding flow
- Inconsistent UX if totalSteps is updated

**Current Value:**

- If `totalSteps = 12`: progress = 91.7% ❌
- If `totalSteps = 11`: progress = 100% ✓
- If `totalSteps = 13`: progress = 84.6% ❌

---

### 3. **Grams Calculation Not Real-Time** 🟡

**File:** `lib/features/onboarding/presentation/screens/macro_step_screen.dart` (Lines 25-31)

**Problem:**

```dart
// In build() - reads from state
final proteinPercent = state.proteinPercent ?? 20.0;
final carbPercent = state.carbPercent ?? 50.0;
final fatPercent = state.fatPercent ?? 30.0;

// Calculate grams
final proteinGrams = (proteinPercent * targetKcal / 100) / 4;
final carbGrams = (carbPercent * targetKcal / 100) / 4;
final fatGrams = (fatPercent * targetKcal / 100) / 9;
```

**Description:**

- Main screen reads percentages from `state` only
- When user opens the customize bottom sheet and adjusts sliders, local variables change
- But these local changes are NOT reflected on the main DonutChart widget until "Save" is pressed
- The grams displayed on the legend show old values while user is adjusting

**Impact:**

- User adjusts sliders but DonutChart doesn't update live
- Confusing UX - visual feedback is delayed
- Grams values shown don't match what user is currently adjusting
- User can't see real-time impact of their adjustments

**Flow:**

1. Macro Step shows: Protein 20% (200g), Carb 50% (500g), Fat 30% (300g)
2. User opens "Tuỳ chỉnh mục tiêu" button → Bottom sheet opens
3. User drags Protein slider to 31% → Local state updates in modal
4. DonutChart on main screen STILL shows 20% (doesn't update)
5. User clicks "Lưu" → Chart finally updates to 31%

---

### 4. **Missing Macro Percentage Validation** 🔴

**File:** `lib/features/onboarding/data/services/nutrition_calculator.dart` (Lines 86-96)

**Problem:**

```dart
static Map<String, double> calcMacros({
  required double targetKcal,
  double proteinPercent = defaultProteinPercent,
  double carbPercent = defaultCarbPercent,
  double fatPercent = defaultFatPercent,
}) {
  return {
    'protein': (proteinPercent / 100 * targetKcal) / calPerGramProtein,
    'carb': (carbPercent / 100 * targetKcal) / calPerGramCarb,
    'fat': (fatPercent / 100 * targetKcal) / calPerGramFat,
  };
}
```

**Description:**

- No validation that percentages sum to 100%
- No guard against invalid input values (negative, extremely high)
- Calculation proceeds even if data is inconsistent
- No error logging for debugging

**Impact:**

- Invalid nutrition data can be stored
- Difficult to trace issues in nutrition calculations
- No early warning system for bad data

---

### 5. **Macro Slider Adjustment Logic Issues** 🟡

**File:** `lib/features/onboarding/presentation/screens/macro_step_screen.dart` (Lines 233-248, 280-295, 327-342)

**Problem:**

```dart
onChanged: (value) {
  setModalState(() {
    final remaining = 100 - value;
    final otherTotal = carbPercent + fatPercent;

    if (otherTotal > 0 && remaining > 0) {
      final carbRatio = carbPercent / otherTotal;
      final fatRatio = fatPercent / otherTotal;
      carbPercent = remaining * carbRatio;  // ⚠️ Floating-point precision loss
      fatPercent = remaining * fatRatio;     // ⚠️ Floating-point precision loss
    } else {
      carbPercent = remaining / 2;
      fatPercent = remaining / 2;
    }
    proteinPercent = value;
  });
},
```

**Description:**

- Proportional distribution can cause floating-point rounding errors
- Example: 99.99999999% or 100.00000001% due to binary floating-point math
- The "Tổng" indicator shows 99.2% or 100.3% instead of exactly 100%
- Save button disabled when total not in range 99% - 101% (line 188-189)

**Impact:**

- User can't save their macro selection if rounding errors occur
- Confusing error state when user thinks they've balanced percentages correctly
- Poor UX - user must fine-tune sliders to exact decimal places

**Example:**

```
User adjusts:
- Protein: 31.0%
- Carb: 23.0%
- Fat: 46.0%
Total shown: 99.2% (due to rounding)
→ Save button DISABLED ❌
```

---

### 6. **Progress Indicator in Result Summary** 🟡

**File:** `lib/features/onboarding/presentation/screens/result_summary_step_screen.dart` (Lines 64-67)

**Problem:**

```dart
ProgressIndicatorWidget(
  progress: 11 / OnboardingModel.totalSteps,
),
```

**Description:**

- Same issue as in MacroStepScreen
- Hardcoded to step 11
- Should reflect the actual current step, not a hardcoded value

**Impact:**

- Progress bar shows same percentage on multiple screens
- Doesn't reflect user's actual progress through onboarding

---

## Root Causes

| Issue                    | Root Cause                                         | Category            |
| ------------------------ | -------------------------------------------------- | ------------------- |
| Donut Chart Distortion   | Normalizing by actual total instead of 100%        | Logic Error         |
| Progress Indicator Wrong | Hardcoded step number                              | Configuration Error |
| Grams Not Real-Time      | Modal state not synced to parent widget            | State Management    |
| No Validation            | Missing input validation in calculator             | Design Flaw         |
| Slider Rounding Errors   | Floating-point precision loss in proportional math | Calculation Error   |

---

## Code Flow Diagram

### Current Flow (Broken):

```
User opens Macro Step Screen
    ↓
Build renders DonutChart with state percentages
    ↓
User clicks "Tuỳ chỉnh mục tiêu" → Modal opens
    ↓
User adjusts sliders → LOCAL variables change
    ↓
DonutChart STILL shows old percentages ❌
    ↓
User clicks "Lưu" → updateMacros() called
    ↓
State updates → Build() called again
    ↓
DonutChart finally updates ✓
```

### Expected Flow:

```
User opens Macro Step Screen
    ↓
Build renders DonutChart with state percentages
    ↓
User clicks "Tuỳ chỉnh mục tiêu" → Modal opens
    ↓
User adjusts sliders → LOCAL variables change
    ↓
DonutChart updates in REAL-TIME ✓
    ↓
User clicks "Lưu" → updateMacros() called
    ↓
State updates → Persisted
```

---

## Files Affected

| File                              | Lines                                            | Issue                           |
| --------------------------------- | ------------------------------------------------ | ------------------------------- |
| `donut_chart_widget.dart`         | 45-48                                            | Normalization logic             |
| `macro_step_screen.dart`          | 25-31, 64-67, 188-189, 233-248, 280-295, 327-342 | Multiple issues                 |
| `result_summary_step_screen.dart` | 64-67                                            | Hardcoded progress              |
| `nutrition_calculator.dart`       | 86-96                                            | Missing validation              |
| `progress_indicator_widget.dart`  | -                                                | Works correctly (not the issue) |
| `onboarding_controller.dart`      | -                                                | No direct issues                |

---

## Recommended Fixes

### Priority 1 (Critical):

1. **Fix Donut Chart Normalization**

   - Always normalize to 100%, not to actual total
   - Add assertion to catch invalid percentages

2. **Implement Real-Time Chart Updates**
   - Pass mutable state to DonutChart
   - Use ValueNotifier or similar for modal state
   - Update chart immediately as sliders move

### Priority 2 (High):

3. **Add Macro Percentage Validation**

   - Validate total = 100% ± tolerance
   - Log invalid cases
   - Return error or apply auto-correction

4. **Fix Progress Indicators**
   - Use actual step index instead of hardcoded 11
   - Reference `OnboardingModel.currentStep` or similar

### Priority 3 (Medium):

5. **Improve Slider Rounding**
   - Use rounding functions to normalize percentages
   - Ensure total always equals 100% (round last value)
   - Extend tolerance range or use rounding strategy

---

## Visual Evidence

### Screenshot Analysis:

**Screenshot 1 - Red Error Screen:**

- Shows the exact error: "Tried to modify a provider while the widget tree was building"
- Stack shows it happens during `initState()` in `weekly_delta_step_screen.dart`
- App completely crashes and shows error overlay

**Screenshot 2 - Correct Chart (20/50/30):**

- Protein: 20% • 169g ✓
- Carb: 50% • 423g ✓
- Fat: 30% • 113g ✓
- Total = 100% (segments visually proportional)

**Screenshot 3 - Incorrect Chart (44/46/11):**

- Protein: 44% • 371g
- Carb: 46% • 386g
- Fat: 11% • 39g
- Total = 101% (segments visually DISPROPORTIONATE)
- ⚠️ Blue carb segment takes up more space than it should visually
- ⚠️ Green protein and orange fat segments appear compressed

---

## Testing Recommendations

### Test Cases:

1. **Donut Chart Accuracy**

   - Test with percentages that sum to exactly 100%
   - Test with percentages that sum to 99% and 101%
   - Verify visual angles match percentages

2. **Real-Time Updates**

   - Open macro customization
   - Adjust slider
   - Verify chart updates immediately (not on save)
   - Close without saving, verify chart reverts

3. **Validation**

   - Try to save with invalid percentages
   - Verify error handling
   - Verify appropriate user feedback

4. **Progress Indicator**
   - Verify progress matches actual step number
   - Test on different screens
   - Verify reaches 100% at final step only

---

## Additional Notes

- The `donut_chart_widget.dart` uses `CustomPaint` with arc drawing, which is generally correct
- The path drawing logic (`_drawArc` method) appears sound
- Main issues are in calculation and state management, not rendering
- No database or backend issues detected

---

## Screenshots Reference

The provided screenshot shows:

- DonutChart with 3 segments (Green 31%, Blue 23%, Orange 46%)
- Progress bar at 100%
- Legend showing macro values

However, based on code analysis, the progress should be ~91.7% (11/12), and there are synchronization issues when adjusting macros.

---

**Report Prepared By:** Code Analysis  
**Last Updated:** December 23, 2025
