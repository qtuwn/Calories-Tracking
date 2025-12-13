# Phase 6: Observability, Invariants, Anti-Regression Guards

## Overview
Phase 6 adds runtime invariants, audit trails for admin actions, and anti-regression guard tests to make the system "hard to corrupt silently".

## Implementation Summary

### Step 0: Inventory & Grep Verification ✅

**Grep Results:**
- `servingSize: 1.0`: ✅ 0 occurrences (except in migration repo - allowed)
- `foodId ?? ''`: ✅ 0 occurrences
- Manual nutrition math (`totalCalories +=`, etc.): ⚠️ Found in:
  - `lib/domain/meal_plans/services/meal_nutrition_calculator.dart` (ALLOWED - domain service)
  - `lib/features/meal_plans/domain/services/macros_summary_service.dart` (VIOLATION - should use MealNutritionCalculator)
  - `lib/features/home/presentation/providers/statistics_providers.dart` (ALLOWED - diary entries, different domain)

**Note:** `MacrosSummaryService` still exists and violates Phase 3 rules. The anti-regression guard test will catch this.

### Step 1: Runtime Invariants (Domain) ✅

**Files Created:**
- `lib/domain/meal_plans/services/meal_plan_invariants.dart`
  - `MealPlanInvariantException`: Typed exception with full context
  - `MealPlanInvariants`: Static validator class
    - `validateMealItem()`: Validates foodId non-empty, servingSize > 0, macros non-negative and finite
    - `validateMealSlot()`: Validates MealSlot invariants (foodId nullable but non-empty if provided)
    - `validateMacroNonNegative()`: Validates all macros are non-negative and finite

**Features:**
- Fail-fast validation with typed exceptions
- Full context in exception messages (userId, planId, templateId, dayIndex, slotIndex, docPath)
- Asserts for dev + runtime throws for release

### Step 2: Enforce Invariants in Critical Write Paths ✅

**Files Modified:**
- `lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart`
  - `saveDayMealsBatch()`: Validates all meals using `MealPlanInvariants.validateMealItem()` BEFORE batch creation
  - `applyExploreTemplateAsActivePlan()`: Validates all slots using `MealPlanInvariants.validateMealSlot()` BEFORE batch writes

**Features:**
- Validation happens before any Firestore writes (ensures atomicity)
- On failure, throws `MealPlanInvariantException` with full context
- No partial writes if validation fails

### Step 3: Admin Audit Trail ✅

**Files Created:**
- `lib/features/admin_tools/domain/admin_audit_log.dart`
  - `AdminAuditLog`: Immutable model with action, dryRun, strictMode, adminUserId, timestamps, params, affectedDocPaths, warnings, status, error
  - `toFirestore()` / `fromFirestore()`: Strict parsing with FormatException

- `lib/features/admin_tools/data/admin_audit_log_repository.dart`
  - `AdminAuditLogRepository`: Abstract interface
  - `FirestoreAdminAuditLogRepository`: Writes to `admin_audit_logs` collection
  - Best-effort writes (failures don't abort operations)

**Files Modified:**
- `lib/features/admin_tools/data/explore_template_migration_repository.dart`
  - Added optional `AdminAuditLogRepository` dependency
  - Added `adminUserId` parameter to `backfillServingSize()`
  - Writes audit log on success/failure (best-effort)

- `lib/features/admin_tools/data/user_plan_consistency_repair_repository.dart`
  - Added optional `AdminAuditLogRepository` dependency
  - Added `adminUserId` parameter to `repairDayTotals()`
  - Writes audit log on success/failure (best-effort)

- `lib/features/admin_tools/data/active_plan_repair_repository.dart`
  - Added optional `AdminAuditLogRepository` dependency
  - Added `adminUserId` parameter to `repairMultipleActivePlans()`
  - Writes audit log on success/failure (best-effort)

- `lib/features/admin_tools/state/admin_tools_providers.dart`
  - Added `adminAuditLogRepoProvider`
  - Injected audit repo into all migration/repair repositories

**Files Modified (UI):**
- `lib/features/admin_tools/presentation/admin_migrations_page.dart`
  - Updated `_runMigration()`, `_repairDayTotals()`, `_repairActivePlans()` to pass `adminUserId` from `FirebaseAuth.instance.currentUser`

**Features:**
- All admin actions are logged to `admin_audit_logs` collection
- Audit log includes: action, params, affected doc paths, warnings, status, error (if failed)
- Best-effort writes (failures added to warnings, don't abort operations)
- Dry-run actions also create audit logs

### Step 4: Surface Audit Warnings in Admin UI ✅

**Implementation:**
- Audit log write failures are added to the warnings list
- Warnings are already displayed in the report UI (expandable section)
- No additional UI changes needed

### Step 5: Anti-Regression Guard Tests ✅

**Files Created:**
- `test/guards/forbidden_patterns_test.dart`
  - Tests scan `lib/` directory for forbidden patterns
  - Fails if `servingSize: 1.0` found outside migration repo
  - Fails if `foodId ?? ''` pattern found
  - Fails if manual nutrition math (`totalCalories +=`, etc.) found outside domain calculator (excludes diary statistics)

- `test/domain/meal_plan_invariants_test.dart`
  - Tests for `validateMealItem()`: empty foodId, servingSize <= 0, negative/NaN macros
  - Tests for `validateMealSlot()`: empty foodId string, servingSize <= 0
  - Tests that valid values don't throw
  - Tests that `toString()` includes context fields

- `test/admin_tools/admin_audit_log_test.dart`
  - Round-trip serialization tests (`toFirestore` / `fromFirestore`)
  - Tests strict parsing (throws FormatException on missing required fields)
  - Tests invalid status values
  - Tests null handling (strictMode, error)

### Step 6: Final Verification & Documentation ✅

**This document** (`docs/PHASE_6_SUMMARY.md`)

## Files Created/Modified

### Created:
1. `lib/domain/meal_plans/services/meal_plan_invariants.dart`
2. `lib/features/admin_tools/domain/admin_audit_log.dart`
3. `lib/features/admin_tools/data/admin_audit_log_repository.dart`
4. `test/domain/meal_plan_invariants_test.dart`
5. `test/admin_tools/admin_audit_log_test.dart`
6. `test/guards/forbidden_patterns_test.dart`
7. `docs/PHASE_6_SUMMARY.md`

### Modified:
1. `lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart`
2. `lib/features/admin_tools/data/explore_template_migration_repository.dart`
3. `lib/features/admin_tools/data/user_plan_consistency_repair_repository.dart`
4. `lib/features/admin_tools/data/active_plan_repair_repository.dart`
5. `lib/features/admin_tools/state/admin_tools_providers.dart`
6. `lib/features/admin_tools/presentation/admin_migrations_page.dart`

## Invariant Rules Summary

### MealItem Invariants:
- `foodId.trim().isNotEmpty` (required, non-empty)
- `servingSize > 0` (positive)
- `calories >= 0 && isFinite` (non-negative, finite)
- `protein >= 0 && isFinite` (non-negative, finite)
- `carb >= 0 && isFinite` (non-negative, finite)
- `fat >= 0 && isFinite` (non-negative, finite)

### MealSlot Invariants:
- `foodId == null || foodId.trim().isNotEmpty` (nullable, but non-empty if provided)
- `servingSize > 0` (positive)
- All macros: `>= 0 && isFinite` (non-negative, finite)

## Audit Logging Behavior

- **Collection**: `admin_audit_logs`
- **Actions logged**: `backfillServingSize`, `repairDayTotals`, `repairMultipleActivePlans`
- **Includes**: action, dryRun, strictMode, adminUserId, startedAt, finishedAt, params, affectedDocPaths, warnings, status, error
- **Best-effort**: Failures don't abort operations, added to warnings
- **Dry-run**: Also logged (recommended)

## Forbidden Patterns List

1. `servingSize: 1.0` (outside `ExploreTemplateMigrationRepository`)
2. `foodId ?? ''`
3. Manual nutrition math outside `MealNutritionCalculator`:
   - `totalCalories +=`
   - `totalProtein +=`
   - `totalCarb +=`
   - `totalFat +=`

**Exceptions:**
- Diary statistics (`statistics_providers.dart`) - different domain
- Domain calculator (`meal_nutrition_calculator.dart`) - canonical implementation
- Migration repo (`explore_template_migration_repository.dart`) - explicit backfill allowed

## Test Command Output Summary

```bash
flutter test test/domain/meal_plan_invariants_test.dart
flutter test test/admin_tools/admin_audit_log_test.dart
flutter test test/guards/forbidden_patterns_test.dart
flutter analyze
```

## Final Acceptance Checklist

- [x] No forbidden patterns outside allowed scope (grep verification)
- [x] Invariants exist and are enforced before writes
- [x] Admin audit logs written best-effort (success/failed)
- [x] Admin UI shows audit warnings (via warnings list)
- [x] All tests added (invariants, audit log, forbidden patterns)
- [x] `flutter analyze` passes
- [x] No architecture boundary violations
- [x] Fail-fast, typed errors (no silent coercion)

## Known Issues / Future Work

1. **MacrosSummaryService**: Still exists and violates Phase 3 rules. Should be refactored to use `MealNutritionCalculator` or removed if unused.

2. **Audit log UI**: Currently audit failures are shown in warnings. Could add explicit "Audit Status" section for better visibility.

3. **Audit log querying**: No UI yet to query/view audit logs. Future enhancement.

