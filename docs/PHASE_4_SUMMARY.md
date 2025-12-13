# Phase 4: Production Hardening - Data Migration & Consistency Repair

## Overview
Phase 4 implements production-safe data migration and consistency repair tools for handling legacy Firestore data and enforcing invariants.

## Implementation Summary

### Step 1: Migration Exceptions & Report Models ✅

**Files Created:**
- `lib/features/admin_tools/domain/migration_exceptions.dart`
  - `MigrationException`: Typed exception with full context (userId, templateId, planId, dayIndex, docPath, details)
  
- `lib/features/admin_tools/domain/migration_report.dart`
  - `MigrationReport`: Immutable report for migration operations (templatesScanned, templatesUpdated, slotsUpdated, updatedDocPaths, warnings)
  - `RepairReport`: Immutable report for repair operations (plansScanned, daysScanned, daysRepaired, activePlansFixed, repairedDocPaths, warnings)

### Step 2: Explore Template Migration ✅

**Files Created:**
- `lib/features/admin_tools/data/explore_template_migration_repository.dart`
  - `ExploreTemplateMigrationRepository`: Abstract interface
  - `FirestoreExploreTemplateMigrationRepository`: Firestore implementation
  
**Features:**
- Backfills missing `servingSize` in explore template meal slots
- Supports `dryRun` mode (calculate without writing)
- Supports `strict` mode (throw on invalid structure vs warn and skip)
- Batch writes in chunks ≤ 450 operations (safe headroom under 500)
- Validates `defaultServingSize > 0`
- Records all updated document paths in report
- Idempotent: running twice causes no harm

**Collection Path:**
- `meal_plans/{planId}/days/{dayId}/meals/{mealId}`

### Step 3: Day Totals Consistency Repair ✅

**Files Created:**
- `lib/features/admin_tools/data/user_plan_consistency_repair_repository.dart`
  - `UserPlanConsistencyRepairRepository`: Abstract interface
  - `FirestoreUserPlanConsistencyRepairRepository`: Firestore implementation

**Features:**
- Repairs day totals to match computed totals from meals using `MealNutritionCalculator.sumMeals()`
- Supports `dryRun` mode
- Configurable `epsilon` for floating point comparisons (default: 0.0001)
- Validates each meal using domain service before computing totals
- Catches `MealNutritionException` and adds warnings (does not stop scan)
- Updates only totals fields: `totalCalories`, `protein`, `carb`, `fat`, `updatedAt`
- Query days by `dayIndex` (not docId)
- Batch writes in chunks ≤ 450 operations
- Idempotent

**Collection Path:**
- `users/{userId}/user_meal_plans/{planId}/days/{dayId}/meals/{mealId}`

### Step 4: Active Plan Repair ✅

**Files Created:**
- `lib/features/admin_tools/data/active_plan_repair_repository.dart`
  - `ActivePlanRepairRepository`: Abstract interface
  - `FirestoreActivePlanRepairRepository`: Firestore implementation

**Features:**
- Repairs multiple active plans per user (enforces at most one active plan)
- Keeps newest plan as active (ordered by `createdAt desc`)
- Deactivates older plans: sets `isActive=false`, `status='paused'`, `updatedAt=serverTimestamp`
- Supports `dryRun` mode
- Batch writes per user (atomic operation)
- Records all affected plan IDs in warnings
- Idempotent

**Collection Path:**
- `users/{userId}/user_meal_plans/{planId}`

## Safety Features

### No Silent Coercion
- All mutations are explicit and logged with document paths
- Migration is the only place allowed to backfill missing fields

### Admin-Only Operations
- All repositories are in `lib/features/admin_tools/`
- UI entry point (Step 5) should check admin role before exposing

### Dry Run Mode
- All operations support `dryRun` mode for safe testing
- Calculates what would change without writing to Firestore

### Fail-Fast with Context
- Typed exceptions (`MigrationException`) with full context
- Invalid data throws with document paths and details

### Idempotent Operations
- All repairs can be run multiple times safely
- Running twice causes no harm (no duplicate updates)

### Batch Constraints
- All Firestore batch writes stay ≤ 450 operations (safe headroom under 500)
- Batches are committed in chunks as needed

## Verification Checklist

### ✅ Code Quality
- [x] Migration repository exists with dryRun + strict mode
- [x] Repair totals repo exists with dryRun + epsilon
- [x] Active plan repair exists with dryRun
- [x] All repositories use batch writes with safe limits
- [x] All repositories log document paths
- [x] Typed exceptions with full context

### ✅ Architecture
- [x] Abstract interfaces for all repositories
- [x] Domain models used for validation (`MealNutritionCalculator`, `MealItem`)
- [x] No silent coercion in normal flows
- [x] Migration is explicit and admin-only

### ⚠️ Pending (Optional)
- [ ] Admin-only UI entry point (Step 5) - Optional but recommended
- [ ] Unit tests (Step 6) - Minimum viable tests for report models

## Grep Evidence

### Nutrition Math Verification
**Manual nutrition math only exists in domain service (correct):**
```
lib/domain/meal_plans/services/meal_nutrition_calculator.dart
  - Line 345-348: totalCalories += nutrition.calories (in sumMeals - correct)
  - Line 400-403: totalCalories += nutrition.calories (in sumMealSlots - correct)
```

**No manual math outside domain service found** ✅

### ServingSize Default Verification
**`defaultServingSize` parameter:**
- Only exists in `ExploreTemplateMigrationRepository.backfillServingSize()` ✅

**`servingSize: 1.0` hardcoding:**
- No occurrences found outside migration repository ✅

## Usage Example

```dart
// Explore Template Migration
final migrationRepo = FirestoreExploreTemplateMigrationRepository();
final report = await migrationRepo.backfillServingSize(
  defaultServingSize: 1.0,
  dryRun: true, // Test first
  strict: true,
);
print(report);

// Day Totals Repair
final repairRepo = FirestoreUserPlanConsistencyRepairRepository();
final repairReport = await repairRepo.repairDayTotals(
  dryRun: true,
  epsilon: 0.0001,
);
print(repairReport);

// Active Plan Repair
final activePlanRepo = FirestoreActivePlanRepairRepository();
final activeReport = await activePlanRepo.repairMultipleActivePlans(
  dryRun: true,
);
print(activeReport);
```

## Next Steps (Optional)

1. **Step 5**: Create admin UI entry point (`lib/features/admin_tools/presentation/admin_migrations_page.dart`)
   - Toggles for Dry Run, Strict Mode
   - Buttons for each repair operation
   - Display report summary and doc paths
   - Admin-only access check

2. **Step 6**: Add unit tests
   - `test/admin_tools/migration_report_test.dart`: Test report models
   - `test/admin_tools/repair_planner_test.dart`: Test pure repair logic (if extracted)

## Notes

- All operations are production-safe with proper error handling and logging
- Repositories follow Clean Architecture with abstract interfaces
- Domain services (`MealNutritionCalculator`) are used for all nutrition calculations
- No silent data coercion - all mutations are explicit and auditable

