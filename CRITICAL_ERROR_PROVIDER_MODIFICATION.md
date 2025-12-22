# Critical Error Analysis: Provider Modification in Widget Lifecycle

**Date:** December 23, 2025  
**Status:** 🔴 CRITICAL - App Crashing  
**Severity:** P0 - Blocks Usage

---

## Issue Summary

The app crashes when navigating to the **Weekly Delta Step Screen** due to provider modification in `initState()`. This violates Flutter/Riverpod's widget lifecycle rules.

---

## Error Details

### Error Message

```
Tried to modify a provider while the widget tree was building.
If you are encountering this error, chances are you tried to modify a provider
in a widget life-cycle, such as but not limited to:
- build
- initState ⚠️ THIS IS THE PROBLEM
- dispose
- didUpdateWidget
- didChangeDependencies

Modifying a provider inside those life-cycles is not allowed, as it could
lead to an inconsistent UI state.
```

### Location

**File:** `lib/features/onboarding/presentation/screens/weekly_delta_step_screen.dart`  
**Lines:** 25-32  
**Method:** `initState()`

### Root Cause Code

```dart
class _WeeklyDeltaStepScreenState extends ConsumerState<WeeklyDeltaStepScreen> {
  double _weeklyDelta = 0.5;

  @override
  void initState() {
    super.initState();
    final onboardingState = ref.read(onboardingControllerProvider);
    _weeklyDelta = onboardingState.weeklyDeltaKg ?? 0.5;

    // ❌ THIS LINE CRASHES THE APP ❌
    ref
        .read(onboardingControllerProvider.notifier)
        .updateWeeklyDelta(_weeklyDelta);  // ← Provider mutation in initState!
  }
  // ...
}
```

---

## Why This Happens

### The Problem Chain

1. **initState() is called during widget building**

   - When the widget tree is constructing
   - Flutter is in "building state" mode
   - Riverpod locks provider modifications

2. **updateWeeklyDelta() modifies the provider**

   ```dart
   void updateWeeklyDelta(double weeklyDeltaKg) {
     _updateState(state.copyWith(weeklyDeltaKg: weeklyDeltaKg));
   }

   void _updateState(OnboardingModel newState) {
     state = newState;  // ← This triggers provider notification
     _saveDraft();
   }
   ```

3. **Riverpod detects the mutation**

   - Checks if widget tree is currently building
   - YES - Building state active
   - Throws error to prevent inconsistent state

4. **App crashes immediately**
   - User sees red error screen
   - Navigation to this screen blocks the flow

### Why Riverpod Prevents This

**Without the check:**

- Widget A reads provider state X
- Widget B reads provider state Y (different from X because mutation happened)
- Inconsistent UI - two widgets see different states
- Race conditions and bugs

**With the check (current):**

- Error thrown immediately
- Developer knows the issue

---

## Stack Trace Analysis

```
#10  OnboardingController._updateState
      └─ Tries to set state = newState

#11  OnboardingController.updateWeeklyDelta
      └─ Calls _updateState()

#12  _WeeklyDeltaStepScreenState.initState
      └─ Calls updateWeeklyDelta() during widget initialization

#13  StatefulElement._firstBuild
      └─ Flutter building widget tree
      └─ THIS IS THE PROBLEM: initState called during build phase
```

---

## Solutions

### Solution 1: Remove the Update (Recommended)

**Why:** Simplest and cleanest approach

```dart
@override
void initState() {
  super.initState();
  final onboardingState = ref.read(onboardingControllerProvider);
  _weeklyDelta = onboardingState.weeklyDeltaKg ?? 0.5;
  // ✅ Don't modify provider here - just read and set local state
  // The value will be saved when user interacts with slider or presses continue
}
```

**Pros:**

- No side effects in initState
- Clean and simple
- Value loads correctly

**Cons:**

- If value doesn't match state on first load, need to handle it

---

### Solution 2: Delay the Update (Alternative)

**Why:** If you absolutely need to update provider on load

```dart
@override
void initState() {
  super.initState();
  final onboardingState = ref.read(onboardingControllerProvider);
  _weeklyDelta = onboardingState.weeklyDeltaKg ?? 0.5;

  // ✅ Delay update until widget tree is built
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref
        .read(onboardingControllerProvider.notifier)
        .updateWeeklyDelta(_weeklyDelta);
  });
}
```

**Pros:**

- Can still update provider if needed
- Runs after widget tree is built
- Safe and correct

**Cons:**

- Update is asynchronous
- Slightly more complex

---

## Similar Issues to Check

This pattern might exist in other screens. Check these files:

- [ ] `height_step_screen.dart` - Check initState
- [ ] `weight_step_screen.dart` - Check initState
- [ ] `dob_step_screen.dart` - Check initState
- [ ] `current_weight_step_screen.dart` - Check initState
- [ ] `target_weight_step_screen.dart` - Check initState
- [ ] `activity_level_step_screen.dart` - Check initState
- [ ] `macro_step_screen.dart` - Check initState

All ConsumerStatefulWidget screens should be reviewed.

---

## Impact Assessment

### Severity: 🔴 CRITICAL

| Aspect          | Impact                                           |
| --------------- | ------------------------------------------------ |
| User Experience | ❌ Complete - App crashes on weekly delta screen |
| Onboarding Flow | ❌ Blocked - Can't progress past this step       |
| Data Loss       | ⚠️ Possible - App state becomes inconsistent     |
| Testing         | ❌ Cannot reach screens beyond this point        |

---

## Related Issues

This error interacts with the previously documented donut chart issues:

1. **Widget Lifecycle Error** (Current) - Prevents any chart display
2. **Chart Normalization** (Previous) - Causes incorrect visual display
3. **Real-time Updates** (Previous) - No live feedback to user

**Resolution Order:**

1. Fix the initState crash (MUST do first)
2. Fix donut chart normalization
3. Implement real-time chart updates

---

## Code Quality Notes

### Why This Happened

1. **Misunderstanding of initState in Riverpod**

   - In plain Riverpod, accessing ref in initState is fine
   - But MODIFYING providers is not allowed
   - Common confusion point

2. **Copy-paste pattern**

   - Same pattern might be repeated in other screens
   - Need systematic review

3. **Missing code review**
   - Pattern: read value, then immediately update
   - Should raise red flags in review

---

## Testing Checklist

After fix, verify:

- [ ] Can navigate to Weekly Delta step without crash
- [ ] Initial value loads from state correctly
- [ ] Slider works and updates value
- [ ] Value persists when navigating back and forth
- [ ] Check other screens for same pattern
- [ ] Full onboarding flow completes without crashes

---

**Priority:** Complete this fix before any other changes  
**Estimated Effort:** 5 minutes  
**Blocking:** Full onboarding flow
