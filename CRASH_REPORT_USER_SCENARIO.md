# Bug Report: Weekly Delta Step Screen Crash - Confirmed Scenario

**Date:** December 23, 2025  
**Status:** 🔴 CRITICAL - Reproducible Crash  
**Severity:** P0 - Blocks Usage Flow  
**Report Type:** User Scenario Verification

---

## Scenario That Triggers the Crash

### User Input:

- **Height:** 1m65 (165cm)
- **Current Weight:** 88kg
- **Goal:** Giảm cân (Lose Weight)
- **Target Weight:** 65kg
- **Weight Loss Rate:** Being set when crash occurs

### Error Triggered:

When user tries to set the weekly weight loss rate, the app crashes with:

```
Tried to modify a provider while the widget tree was building.
```

### Screenshot Evidence:

- Red error screen showing provider modification during widget lifecycle
- Error occurs at `_WeeklyDeltaStepScreenState.initState()` (line 32)
- Stack trace shows 188 frames of normal element mounting followed by crash

---

## Reproduction Steps

1. **Complete onboarding to Weekly Delta Step:**

   - Enter nickname
   - Select gender and age
   - Enter height: **1m65** (165cm)
   - Enter current weight: **88kg**
   - Select goal type: **Lose Weight**
   - Enter target weight: **65kg**
   - Proceed to Activity Level step
   - Proceed to Macro step
   - Complete Result Summary
   - Proceed to next steps...

2. **Reach Weekly Delta Step Screen:**

   - App navigates to: `WeeklyDeltaStepScreen`
   - Widget tree begins building
   - `initState()` is called

3. **Crash Occurs:**
   - In `initState()`, code calls:
     ```dart
     ref.read(onboardingControllerProvider.notifier).updateWeeklyDelta(_weeklyDelta);
     ```
   - Riverpod detects provider mutation during widget build
   - Error thrown immediately
   - Red error screen displayed

---

## Root Cause Analysis

### The Problem:

File: `weekly_delta_step_screen.dart` (Lines 25-32)

```dart
class _WeeklyDeltaStepScreenState extends ConsumerState<WeeklyDeltaStepScreen> {
  double _weeklyDelta = 0.5;

  @override
  void initState() {
    super.initState();
    final onboardingState = ref.read(onboardingControllerProvider);
    _weeklyDelta = onboardingState.weeklyDeltaKg ?? 0.5;

    // ❌ VIOLATES RIVERPOD RULES - Modifying provider in initState
    ref
        .read(onboardingControllerProvider.notifier)
        .updateWeeklyDelta(_weeklyDelta);
  }
  // ...
}
```

### Why It Crashes:

1. **Widget Lifecycle Violation**

   - `initState()` is called during widget tree construction
   - Flutter's widget framework is in "building" state
   - Riverpod FORBIDS provider modifications during build phase

2. **Provider Mutation Chain**

   - `updateWeeklyDelta()` → `_updateState()`
   - `_updateState()` → `state = newState` (triggers provider notification)
   - Riverpod detects the mutation
   - Check fails: `_debugCanModifyProviders()` throws error

3. **Stack Trace Confirmation**
   ```
   #12  _WeeklyDeltaStepScreenState.initState
   #13  StatefulElement._firstBuild (Flutter is building!)
   #10  OnboardingController._updateState (Provider mutation detected)
   ```

---

## Why This Specific Scenario Triggers It

The crash occurs **specifically** when navigating to Weekly Delta Step because:

1. **Weight data triggers the flow:**

   - User enters: 88kg (current) → 65kg (target)
   - Difference: 23kg to lose
   - This is a significant loss goal

2. **Navigation sequence activates the widget:**

   - Flow: Goal Type → Activity Level → Macro → Result → Weekly Delta
   - Weekly Delta Step is reached
   - Widget instantiation starts
   - `initState()` fires immediately during build
   - Crash triggered

3. **The profile data is complete:**
   - All previous steps filled in
   - Provider state has accumulated data
   - `onboardingState.weeklyDeltaKg` might be null or have old value
   - Code tries to sync it: **provider mutation in initState** ❌

---

## Technical Details

### File Location:

```
lib/features/onboarding/presentation/screens/weekly_delta_step_screen.dart
```

### Problem Lines:

```dart
Lines 25-32: initState() method with provider modification
```

### Affected Class:

```dart
class _WeeklyDeltaStepScreenState extends ConsumerState<WeeklyDeltaStepScreen>
```

### Method Chain That Crashes:

```
initState()
  ↓
ref.read(onboardingControllerProvider.notifier).updateWeeklyDelta()
  ↓
OnboardingController.updateWeeklyDelta()
  ↓
OnboardingController._updateState()
  ↓
state = newState  ← Riverpod detects mutation during build
  ↓
🔴 ERROR THROWN
```

---

## Impact

### Severity: 🔴 CRITICAL

| Aspect              | Impact                                                          |
| ------------------- | --------------------------------------------------------------- |
| **User Experience** | App completely crashes, red error screen                        |
| **Onboarding Flow** | Blocks progression - can't reach target weight goals            |
| **Data Loss**       | User loses onboarding progress if they don't know to go back    |
| **Testing**         | Cannot test weekly delta functionality or weight loss scenarios |
| **Reproducibility** | 100% reproducible with weight loss goal setup                   |

### Users Affected:

- ✅ Anyone selecting "Giảm cân" (Lose Weight) goal
- ✅ Anyone setting realistic weight loss targets
- ✅ Anyone with current weight > target weight

---

## Related Error Pattern

This is the SAME error pattern documented in `CRITICAL_ERROR_PROVIDER_MODIFICATION.md` but with confirmed user data that reproduces it:

### Confirmed Reproduction Data:

```
Height:       1m65 (165cm)
Current:      88kg
Goal:         Lose Weight
Target:       65kg
Delta:        23kg loss
Trigger:      Navigation to Weekly Delta Step
```

### Why This Data Triggers It:

- The weight loss goal is reasonable and triggers onboarding flow
- All previous steps complete successfully
- Weekly Delta screen is reached
- initState() modifies provider
- **Crash confirmed**

---

## Error Message Output

### Console Error:

```
════════════════════════════════════════════════════════════════════════════════════════════════════

══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═══════════════════════════════════════════════════════════
The following assertion was thrown building Builder:
Tried to modify a provider while the widget tree was building.

...

The relevant error-causing widget was:
  MaterialApp
  MaterialApp:file:///C:/Users/tuquo/Desktop/DOANCHUYENNGHANH/Calories-App/lib/main.dart:77:12

When the exception was thrown, this was the stack:
#0      _UncontrolledProviderScopeState._debugCanModifyProviders
#10     OnboardingController._updateState
#11     OnboardingController.updateWeeklyDelta
#12     _WeeklyDeltaStepScreenState.initState  ← CRASH HERE
#13     StatefulElement._firstBuild

════════════════════════════════════════════════════════════════════════════════════════════════════
```

---

## Device Info

- **Device:** SM A107F (MIUI)
- **OS:** Android
- **Flutter Version:** (appears to be recent)
- **App:** Calories-App (calories_app package)

---

## Verification Checklist

- [x] Error reproduced with specific user data
- [x] Stack trace confirms initState() as crash point
- [x] Provider modification detected in call chain
- [x] Riverpod's widget lifecycle protection triggered
- [x] Consistent with documented pattern
- [x] Blocks onboarding flow for weight loss users
- [x] 100% reproducible scenario confirmed

---

## Next Steps (Do Not Implement)

This report documents the crash scenario. To fix it (future work):

1. **Remove provider mutation from initState()**

   - Simply read the value and set local state
   - Remove the `updateWeeklyDelta()` call

2. **Alternative: Delay the update**

   - Use `WidgetsBinding.instance.addPostFrameCallback()`
   - Run after widget tree is built

3. **Check for similar patterns**
   - Review other step screens for same issue
   - All ConsumerStatefulWidget screens should be checked

---

## Files Referenced

- [CRITICAL_ERROR_PROVIDER_MODIFICATION.md](CRITICAL_ERROR_PROVIDER_MODIFICATION.md) - General pattern
- [weekly_delta_step_screen.dart](lib/features/onboarding/presentation/screens/weekly_delta_step_screen.dart) - Problem file

---

**Report Created:** December 23, 2025  
**Verified By:** User scenario reproduction  
**Status:** Confirmed Critical Issue  
**Action:** Awaiting fix implementation
