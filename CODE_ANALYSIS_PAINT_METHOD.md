# Code Analysis: DonutChartWidget paint() Method

**File:** `lib/features/onboarding/presentation/widgets/donut_chart_widget.dart`  
**Lines:** 40-85  
**Method:** `paint(Canvas canvas, Size size)`  
**Status:** Analysis Only (No Code Changes)

---

## Current Implementation

### Method Signature (Lines 49-50)

```dart
@override
void paint(Canvas canvas, Size size) {
```

### Setup Phase (Lines 51-57)

```dart
final center = Offset(size.width / 2, size.height / 2);
final radius = size.width / 2;
final innerRadius = radius * 0.6; // Donut hole

// Colors for each macro
const proteinColor = Color(0xFF4CAF50); // Green
const carbColor = Color(0xFF2196F3); // Blue
const fatColor = Color(0xFFFF9800); // Orange
```

**Analysis:**

- ✅ Center calculation is correct (width/2, height/2)
- ✅ Radius correctly set to half the width
- ✅ Inner radius at 60% creates donut hole effect
- ✅ Colors are hardcoded consistently:
  - Green (0xFF4CAF50) = Protein
  - Blue (0xFF2196F3) = Carb
  - Orange (0xFFFF9800) = Fat

---

### Validation Phase (Lines 59-70)

```dart
// Guard against non-finite or invalid values
final safeProtein = proteinPercent.isFinite && proteinPercent > 0
    ? proteinPercent
    : 0.0;
final safeCarb = carbPercent.isFinite && carbPercent > 0
    ? carbPercent
    : 0.0;
final safeFat = fatPercent.isFinite && fatPercent > 0
    ? fatPercent
    : 0.0;
```

**Analysis:**

- ✅ Good defensive programming
- ✅ Checks for NaN, infinity values
- ✅ Filters negative percentages
- ✅ Uses safe values for calculation
- ✅ Prevents crashes from invalid input

---

### Angle Calculation Phase (Lines 72-76)

```dart
// Compute sweep angles using percent/100 * 2π (radians directly)
// This avoids precision issues from degree-to-radian conversion
final proteinSweep = (safeProtein / 100.0) * (2 * math.pi);
final carbSweep = (safeCarb / 100.0) * (2 * math.pi);
final fatSweep = (safeFat / 100.0) * (2 * math.pi);
```

**Analysis:**

| Aspect          | Status     | Note                                           |
| --------------- | ---------- | ---------------------------------------------- |
| **Formula**     | ✅ Correct | `percent/100 * 2π` is standard                 |
| **Radians**     | ✅ Correct | Uses radians directly (not degrees)            |
| **Precision**   | ✅ Good    | Avoids degree→radian conversion                |
| **Issue Found** | ⚠️ **BUG** | **Uses safe values, but assumes total = 100%** |

**The Problem:**

```dart
// Assume protein=31, carb=23, fat=46 (total=100)
proteinSweep = (31/100) * 2π = 0.31 * 6.283 = 1.948 radians ✅

// But if total=101 due to rounding
// Code still calculates:
proteinSweep = (31/101) * 2π = 0.307 * 6.283 = 1.931 radians ❌
// This changes the angle!
```

**Why It's Wrong:**

- Code divides by 100, not by the actual total
- If percentages don't sum to 100%, angles become incorrect
- Safe values are individual, but their total might not be 100%
- **Example scenario shown in screenshots:**
  - Protein: 44%, Carb: 46%, Fat: 11% (total = 101%)
  - Chart segments appear disproportionate
  - Blue carb segment too large

---

### Debug Assertion Phase (Lines 78-85)

```dart
// Debug assertion to ensure macro total is ~100% in debug mode
assert(() {
  final total = proteinPercent + carbPercent + fatPercent;
  if ((total - 100.0).abs() > 1.0) {
    debugPrint(
      '⚠️ DonutChart: Macro total is ${total.toStringAsFixed(1)}% (expected ~100%)',
    );
  }
  return true;
}());
```

**Analysis:**

- ✅ Checks if total deviates > 1.0% from 100
- ✅ Only logs warning, doesn't prevent crash
- ✅ Debug-only (doesn't run in release)
- ⚠️ Warns about problem but doesn't fix it
- ⚠️ Assertion is developer tool, not user protection

**Example Output:**

```
⚠️ DonutChart: Macro total is 101.0% (expected ~100%)
⚠️ DonutChart: Macro total is 99.2% (expected ~100%)
```

---

## Issues Found in This Code Section

### Issue 1: Percentage Normalization Bug 🔴

**Lines:** 72-76  
**Severity:** HIGH

```dart
final proteinSweep = (safeProtein / 100.0) * (2 * math.pi);
```

**Problem:**

- Assumes percentages always sum to 100%
- If sum ≠ 100%, angles become incorrect
- Safe values are checked individually, not collectively

**What Should Happen:**

- If total ≠ 100%, should normalize to actual total
- OR ensure percentages always sum to exactly 100%

**Impact:**

- Chart segments appear visually wrong
- 44% doesn't look like 44% when total is 101%
- User sees discrepancy between legend (44%) and visual

---

### Issue 2: Debug Assertion Only 🟡

**Lines:** 78-85  
**Severity:** MEDIUM

```dart
assert(() {
  final total = proteinPercent + carbPercent + fatPercent;
  if ((total - 100.0).abs() > 1.0) {
    debugPrint(...);
  }
  return true;
}());
```

**Problems:**

1. Assertion is debug-only (removed in production)
2. Only logs warning, doesn't fix the issue
3. Users in production won't see the warning
4. Chart will still be wrong in production

**What Happens:**

- Debug: Warning logged, user sees console message
- Release: No warning, chart silently wrong

---

## Code Flow Diagram

```
paint(canvas, size)
  │
  ├─ Setup geometry (center, radius)
  │
  ├─ Define colors
  │
  ├─ Validate inputs
  │  ├─ Check finite?
  │  ├─ Check positive?
  │  └─ Use safe values
  │
  ├─ Calculate sweep angles  ❌ ISSUE HERE
  │  ├─ divide by 100.0 (not actual total)
  │  └─ multiply by 2π
  │
  └─ Debug assertion (checks but doesn't fix)  ⚠️ ISSUE HERE
     └─ Logs warning only
```

---

## Comparison: Current vs Expected

### Current Implementation

```dart
final total = safeProtein + safeCarb + safeFat;
// Example: 31 + 23 + 46 = 100

final proteinSweep = (safeProtein / 100.0) * (2 * math.pi);
// Divides by hardcoded 100.0
// Works IF total is 100
// FAILS if total is 99.2 or 101.0
```

### What Should Happen

```dart
final total = safeProtein + safeCarb + safeFat;
// Example: 31 + 23 + 45.9 = 99.9

// Option A: Normalize to actual total
final proteinSweep = (safeProtein / total) * (2 * math.pi);

// Option B: Ensure total is always 100 before calculating
final normalizedTotal = max(total, 0.01); // Avoid division by zero
final proteinSweep = (safeProtein / normalizedTotal) * (2 * math.pi);

// Option C: Add validation to ensure total = 100
if ((total - 100.0).abs() > 0.5) {
  // Handle error
  return; // Don't draw
}
```

---

## Detailed Breakdown: Lines 40-85

| Line  | Code                | Type            | Status               |
| ----- | ------------------- | --------------- | -------------------- |
| 40-42 | Field declarations  | Setup           | ✅ OK                |
| 43-48 | Constructor         | Setup           | ✅ OK                |
| 49-50 | paint() signature   | Method          | ✅ OK                |
| 51-52 | center, radius calc | Setup           | ✅ OK                |
| 53    | innerRadius = 0.6   | Setup           | ✅ OK                |
| 55-58 | Color definitions   | Setup           | ✅ OK                |
| 60-70 | Validation (safe\*) | Validation      | ✅ OK but incomplete |
| 72-76 | Sweep angles        | **CALCULATION** | ❌ **BUG**           |
| 78-85 | Debug assertion     | Debug           | ⚠️ Insufficient      |

---

## The Root Cause

### Why Segments Look Wrong (Like in Screenshot 3)

User input: Protein 44%, Carb 46%, Fat 11% (total = 101%)

**Current code does:**

```dart
proteinSweep = (44 / 100.0) * 2π = 2.764 rad = 158.4°
carbSweep = (46 / 100.0) * 2π = 2.891 rad = 165.6°
fatSweep = (11 / 100.0) * 2π = 0.691 rad = 39.6°
Total = 363.6° ❌ Over 360°!
```

**What should happen:**

```dart
total = 101.0
proteinSweep = (44 / 101.0) * 2π = 2.737 rad = 156.8°
carbSweep = (46 / 101.0) * 2π = 2.864 rad = 164.0°
fatSweep = (11 / 101.0) * 2π = 0.683 rad = 39.1°
Total = 360° ✅ Correct!
```

**Visual Result:**

- Current: Carb segment appears too large (calculates with 46%)
- Correct: Carb segment smaller (calculates with 46/101%)

---

## Summary of Findings

### Safe Code (Defensive)

- ✅ Input validation for NaN/infinity
- ✅ Filter negative values
- ✅ Debug assertion for total percentage

### Problematic Code (Logic Error)

- ❌ Hardcoded division by 100.0
- ❌ Assumes percentages sum to 100%
- ❌ No runtime correction if total ≠ 100%
- ⚠️ Debug-only assertion insufficient

### Impact

- **Visual:** Segments appear disproportionate when total ≠ 100%
- **User:** Confusion between legend percentages and visual representation
- **Data:** Chart doesn't reflect actual nutritional distribution

---

**Report Type:** Code Analysis Only  
**Changes Made:** None  
**Recommendations:** See CRASH_REPORT_USER_SCENARIO.md and BUG_REPORT_DONUT_CHART.md for fix recommendations
