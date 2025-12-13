# Phase 5: Admin UI + Test Harness + Wiring

## Overview
Phase 5 adds a production-safe Admin UI for running migrations/repairs, minimum viable unit tests, and wiring via Riverpod providers.

## Implementation Summary

### Step 1: Providers for Admin Tools ✅

**Files Created:**
- `lib/features/admin_tools/state/admin_tools_providers.dart`
  - `exploreTemplateMigrationRepoProvider`: Provides `FirestoreExploreTemplateMigrationRepository`
  - `userPlanConsistencyRepairRepoProvider`: Provides `FirestoreUserPlanConsistencyRepairRepository`
  - `activePlanRepairRepoProvider`: Provides `FirestoreActivePlanRepairRepository`

**Features:**
- All providers inject `FirebaseFirestore.instance` automatically
- No UI imports (pure dependency wiring)
- Follows existing Riverpod style

### Step 2: Admin Guard Provider ✅

**Files Created:**
- `lib/features/admin_tools/state/admin_guard_provider.dart`
  - `adminGuardProvider`: StreamProvider<bool> that checks admin role

**Features:**
- **Fail-safe (deny by default)**: Returns `false` if:
  - User not authenticated
  - Profile missing or role != 'admin'
  - Any error occurs
- Uses `currentProfileProvider` to check `UserProfile.isAdmin`
- Does not crash if profile missing (returns false)

### Step 3: Admin Migrations Page ✅

**Files Created:**
- `lib/features/admin_tools/presentation/admin_migrations_page.dart`
  - Full UI for running migrations and repairs

**Features:**

**Guard Behavior:**
- Shows loader while checking admin status
- Shows "Access Denied" if not admin or on error
- Only shows tools UI if `adminGuardProvider` returns `true`

**Controls:**
- **Switch: dryRun** (default: `true` - safe by default)
- **Switch: strictMode** (default: `true` - for template migration only)
- **Number input: defaultServingSize** (default: `1.0` - for migration only)
- **Number input: epsilon** (default: `0.0001` - for day totals repair only)
- **Optional integer inputs**: `limitUsers`, `limitTemplates`, `limitPlansPerUser` (default: null)

**Actions (Buttons):**
- "Dry Run: Backfill Explore Template servingSize" (label reflects dryRun state)
- "Dry Run: Repair Day Totals" (label reflects dryRun state)
- "Dry Run: Repair Multiple Active Plans" (label reflects dryRun state)

**Warning Banner:**
- Shows red warning if `dryRun=false`: "Writes enabled. This will mutate Firestore."

**Output Display:**
- Card showing latest report summary (scanned/updated/repaired counts)
- Expandable "Updated Paths" list (first 50, with "show more")
- Expandable "Warnings" list
- Error display catches `MigrationException` and shows `toString()`
- Catches any error and shows `runtimeType + message`

**Implementation Notes:**
- Uses `ref.read(provider)` to call repositories
- Local running state disables buttons while executing
- Does not block UI thread (async operations)
- No business logic in UI (only parameter parsing and display)

### Step 4: Navigation Hook ✅

**Files Modified:**
- `lib/main.dart`
  - Added route: `AdminMigrationsPage.routeName` → `AdminMigrationsPage()`
  - Added import for `AdminMigrationsPage`

**Route Name:**
- `/admin/migrations`

**Usage:**
```dart
Navigator.pushNamed(context, AdminMigrationsPage.routeName);
```

### Step 5: Minimum Viable Tests ✅

**Files Created:**

1. **`test/admin_tools/migration_report_test.dart`**
   - Tests `MigrationReport` construction and `toString()`
   - Tests `RepairReport` construction and `toString()`
   - Verifies all key fields are included in `toString()` output

2. **`lib/features/admin_tools/domain/repair_planner.dart`**
   - Pure domain functions (unit-testable, no Flutter/Firebase):
     - `shouldRepairDouble(double stored, double computed, double epsilon)`
     - `shouldRepairDayTotals({required storedTotals, required computedTotals, required epsilon})`
   - Fail-fast validation (throws `ArgumentError` for invalid inputs)

3. **`test/admin_tools/repair_planner_test.dart`**
   - Tests epsilon handling (exact match, small diff within epsilon, diff beyond epsilon)
   - Tests negative/NaN inputs throw `ArgumentError` (fail-fast)
   - Tests `shouldRepairDayTotals` for all macros (calories, protein, carb, fat)

**Test Results:**
- ✅ All 19 tests passing

### Step 6: Verification Checklist ✅

## Verification Checklist

### ✅ Code Quality
- [x] Providers added and compile
- [x] Admin guard denies by default (no fail-open)
- [x] Admin page defaults to `dryRun=true`
- [x] Buttons run each repo action and show report
- [x] Errors are surfaced cleanly
- [x] Tests added and passing (19 tests)
- [x] `flutter analyze` passes (no errors)

### ✅ Architecture
- [x] Clean separation: providers → repositories → UI
- [x] No business logic in UI (only parameter parsing)
- [x] Pure domain functions for testability
- [x] Fail-safe admin guard (deny by default)

## Files Created/Modified

### Created:
1. `lib/features/admin_tools/state/admin_tools_providers.dart`
2. `lib/features/admin_tools/state/admin_guard_provider.dart`
3. `lib/features/admin_tools/presentation/admin_migrations_page.dart`
4. `lib/features/admin_tools/domain/repair_planner.dart`
5. `test/admin_tools/migration_report_test.dart`
6. `test/admin_tools/repair_planner_test.dart`
7. `docs/PHASE_5_SUMMARY.md`

### Modified:
1. `lib/main.dart` - Added route for `AdminMigrationsPage`

## Test Results

```bash
flutter test test/admin_tools/
```

**Result:** ✅ All 19 tests passing

```
00:00 +19: All tests passed!
```

## Usage Example

### Accessing Admin Page

```dart
// Navigate to admin migrations page
Navigator.pushNamed(context, AdminMigrationsPage.routeName);
```

### Running Migrations/Repairs

1. Open Admin Migrations Page (admin-only)
2. Verify `dryRun=true` (safe by default)
3. Optionally adjust settings (strictMode, epsilon, limits)
4. Click action button (e.g., "Dry Run: Backfill Explore Template servingSize")
5. View report summary and expandable details
6. If satisfied, set `dryRun=false` and run again to write changes

## Security Notes

- **Admin Guard**: Only users with `role == 'admin'` can access the page
- **Fail-Safe**: Any error in admin check results in access denial
- **Default Safe**: `dryRun=true` by default prevents accidental writes
- **Warning Banner**: Clear visual warning when writes are enabled

## Next Steps (Optional Enhancements)

1. Add navigation entry point from settings page (if exists)
2. Add audit logging for all migration/repair runs
3. Add email notifications for migration completions
4. Add scheduled migrations (cron-like functionality)

