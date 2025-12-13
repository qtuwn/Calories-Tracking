# Phase 6: Regression Tests for Meal Plans

## Summary

Phase 6 adds comprehensive regression tests to prevent the bugs fixed in Phases 0-5 from reoccurring. The tests focus on:

1. **Stream behavior** - Ensuring meals stream always emits (no infinite loading)
2. **Cache policy** - Verifying watchActivePlanWithCache Firestore-first policy with timeout
3. **Apply/copy logic** - Ensuring valid IDs are generated when applying templates

## Test Files Created

### 1. Fake Implementations (`test/features/meal_plans/data/fakes/`)

- **`fake_user_meal_plan_repository.dart`**
  - Fake repository with controllable streams
  - Tracks call counts for verification
  - Emits empty list immediately for meals stream (matches Firestore behavior)

- **`fake_user_meal_plan_cache.dart`**
  - In-memory cache for testing
  - Tracks save/load/clear operations
  - Allows verification of cache interactions

### 2. Service Tests (`test/features/meal_plans/domain/services/`)

- **`user_meal_plan_service_test.dart`**
  - Tests `watchActivePlanWithCache` policy:
    - Firestore emits within 300ms → Firestore plan emitted first (not cache)
    - Firestore delayed → Cache plan emitted first, then Firestore
    - Deduplication by planId works correctly
    - Null handling when no plan exists
  - Tests meals stream behavior:
    - Stream emits empty list when day has no meals
    - Stream emits meals when they exist

### 3. Repository Contract Tests (`test/features/meal_plans/data/`)

- **`repository_stream_contract_test.dart`**
  - Critical regression test: meals stream always emits at least once
  - Verifies stream does not hang when day document doesn't exist
  - Ensures empty list is emitted immediately (matches Firestore snapshots() behavior)

- **`apply_template_id_test.dart`**
  - Verifies applyExploreTemplateAsActivePlan returns plan with valid ID
  - Verifies applyCustomPlanAsActive returns plan with valid ID
  - Ensures no empty string IDs are created

## Dependencies Added

- `fake_async: ^1.3.1` - For testing time-dependent behavior (timeouts, delays)

## Test Coverage

### Stream Behavior (Prevents Infinite Loading)
✅ Meals stream emits empty list immediately when day has no meals  
✅ Meals stream does not hang when day document doesn't exist  
✅ Meals stream emits meals when they are added  

### Cache Policy (Prevents Stale Data)
✅ Firestore-first policy: Firestore plan emitted first if within 300ms  
✅ Cache fallback: Cache plan emitted if Firestore delayed  
✅ Deduplication: Same planId only emits once  

### Apply/Copy Logic (Prevents Invalid IDs)
✅ Applied plans have non-empty IDs  
✅ Applied plan IDs match input parameters  
✅ No empty string IDs created  

## Running Tests

```bash
# Run all meal plan tests
flutter test test/features/meal_plans/

# Run specific test file
flutter test test/features/meal_plans/domain/services/user_meal_plan_service_test.dart

# Run with coverage
flutter test --coverage test/features/meal_plans/
```

## Regression Protection

These tests prevent the following regressions:

1. **Infinite loading spinners** - Stream contract test ensures stream always emits
2. **Stale cached plans** - Service test verifies Firestore-first policy
3. **Invalid meal IDs** - Apply test ensures valid IDs are generated
4. **Stream resubscribe spam** - Provider stability (can be added in future)

## Future Enhancements

- Add provider stability test (verify repository stream setup not called repeatedly)
- Add integration tests with real Firestore emulator (optional)
- Add widget tests for MealDetailPage empty state handling

## Notes

- Tests use fake implementations to avoid Firebase dependencies
- Tests are deterministic and fast (no network calls)
- Tests use `FakeAsync` for time-dependent behavior testing
- All tests pass with `flutter test`

