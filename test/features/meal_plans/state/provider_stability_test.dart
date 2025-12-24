import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/features/meal_plans/state/meal_plan_repository_providers.dart';
import 'package:calories_app/shared/state/user_meal_plan_providers.dart' as user_meal_plan_providers;
import '../data/fakes/fake_user_meal_plan_repository.dart';
import '../data/fakes/fake_user_meal_plan_cache.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_service.dart';

/// Provider stability regression test
/// 
/// Ensures that watching the same provider with the same arguments multiple times
/// does not trigger repository stream setup repeatedly (unless invalidated).
/// This prevents stream recreation spam and improves performance.
void main() {
  group('Provider Stability - Stream Recreation Prevention', () {
    late FakeUserMealPlanRepository fakeRepository;
    late FakeUserMealPlanCache fakeCache;
    late ProviderContainer container;

    setUp(() {
      fakeRepository = FakeUserMealPlanRepository();
      fakeCache = FakeUserMealPlanCache();
      
      // Create a service with fake dependencies
      final service = UserMealPlanService(fakeRepository, fakeCache);
      
      // Override providers with fake implementations
      container = ProviderContainer(
        overrides: [
          user_meal_plan_providers.userMealPlanRepositoryProvider.overrideWithValue(fakeRepository),
          user_meal_plan_providers.userMealPlanCacheProvider.overrideWithValue(fakeCache),
          user_meal_plan_providers.userMealPlanServiceProvider.overrideWithValue(service),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      fakeRepository.dispose();
      fakeCache.clear();
    });

    test('watching same provider args multiple times does not recreate stream', () async {
      const planId = 'test-plan';
      const userId = 'test-user';
      const dayIndex = 1;
      
      final args = (planId: planId, userId: userId, dayIndex: dayIndex);
      
      // Reset call count
      final initialCallCount = fakeRepository.getDayMealsCallCount;
      
      // Watch provider multiple times with same args
      final provider1 = userMealPlanMealsProvider(args);
      final provider2 = userMealPlanMealsProvider(args);
      final provider3 = userMealPlanMealsProvider(args);
      
      // Read from all three providers (simulating multiple widgets watching)
      container.read(provider1);
      container.read(provider2);
      container.read(provider3);
      
      // Wait a bit for any async operations
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify: Stream setup should only be called once (or a small number of times)
      // due to provider memoization, not once per watch
      final finalCallCount = fakeRepository.getDayMealsCallCount;
      final callCountIncrease = finalCallCount - initialCallCount;
      
      // With keepAlive and proper memoization, we expect at most 1-2 calls
      // (one for the initial setup, possibly one more if provider is recreated)
      expect(
        callCountIncrease,
        lessThanOrEqualTo(2),
        reason: 'Stream setup should not be called repeatedly for same provider args. '
            'Expected at most 2 calls (initial + possible recreation), got $callCountIncrease',
      );
    });

    test('watching different provider args creates separate streams', () async {
      const planId1 = 'plan-1';
      const planId2 = 'plan-2';
      const userId = 'test-user';
      const dayIndex = 1;
      
      final initialCallCount = fakeRepository.getDayMealsCallCount;
      
      // Watch with different args
      final provider1 = userMealPlanMealsProvider((planId: planId1, userId: userId, dayIndex: dayIndex));
      final provider2 = userMealPlanMealsProvider((planId: planId2, userId: userId, dayIndex: dayIndex));
      
      container.read(provider1);
      container.read(provider2);
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify: Different args should create separate streams (2 calls)
      final finalCallCount = fakeRepository.getDayMealsCallCount;
      final callCountIncrease = finalCallCount - initialCallCount;
      
      expect(
        callCountIncrease,
        greaterThanOrEqualTo(2),
        reason: 'Different provider args should create separate streams',
      );
    });
  });
}

