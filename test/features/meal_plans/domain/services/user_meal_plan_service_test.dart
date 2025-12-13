import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'dart:async';
import 'package:calories_app/domain/meal_plans/user_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_service.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' as user_meal_plan_repository;
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';
import '../../data/fakes/fake_user_meal_plan_repository.dart';
import '../../data/fakes/fake_user_meal_plan_cache.dart';

void main() {
  group('UserMealPlanService.watchActivePlanWithCache', () {
    late FakeUserMealPlanRepository fakeRepository;
    late FakeUserMealPlanCache fakeCache;
    late UserMealPlanService service;

    setUp(() {
      fakeRepository = FakeUserMealPlanRepository();
      fakeCache = FakeUserMealPlanCache();
      service = UserMealPlanService(fakeRepository, fakeCache);
    });

    tearDown(() {
      fakeRepository.dispose();
      fakeCache.clear();
    });

    test('emits Firestore plan first when Firestore emits within 300ms timeout', () async {
      await FakeAsync().run((async) {
        const userId = 'test-user';
        
        // Pre-populate cache with old plan
        final cachedPlan = UserMealPlan(
          id: 'cached-plan',
          userId: userId,
          name: 'Cached Plan',
          goalType: MealPlanGoalType.maintain,
          type: UserMealPlanType.custom,
          startDate: DateTime.now(),
          currentDayIndex: 1,
          status: UserMealPlanStatus.active,
          dailyCalories: 2000,
          durationDays: 7,
          isActive: true,
        );
        fakeCache.saveActivePlan(userId, cachedPlan);
        
        // Start watching
        final stream = service.watchActivePlanWithCache(userId);
        final emissions = <UserMealPlan?>[];
        final subscription = stream.listen((plan) {
          emissions.add(plan);
        });
        
        // Firestore emits quickly (within 100ms)
        async.elapse(const Duration(milliseconds: 100));
        final firestorePlan = UserMealPlan(
          id: 'firestore-plan',
          userId: userId,
          name: 'Firestore Plan',
          goalType: MealPlanGoalType.maintain,
          type: UserMealPlanType.custom,
          startDate: DateTime.now(),
          currentDayIndex: 1,
          status: UserMealPlanStatus.active,
          dailyCalories: 2000,
          durationDays: 7,
          isActive: true,
        );
        fakeRepository.emitActivePlan(userId, firestorePlan);
        
        // Wait for emissions
        async.elapse(const Duration(milliseconds: 50));
        
        // Verify: Firestore plan should be emitted first (not cached plan)
        expect(emissions.length, greaterThanOrEqualTo(1));
        expect(emissions.first?.id, equals('firestore-plan'));
        expect(emissions.first?.id, isNot(equals('cached-plan')));
        
        subscription.cancel();
      });
    });

    test('emits cached plan first when Firestore does not emit within 300ms timeout', () async {
      await FakeAsync().run((async) {
        const userId = 'test-user';
        
        // Pre-populate cache
        final cachedPlan = UserMealPlan(
          id: 'cached-plan',
          userId: userId,
          name: 'Cached Plan',
          goalType: MealPlanGoalType.maintain,
          type: UserMealPlanType.custom,
          startDate: DateTime.now(),
          currentDayIndex: 1,
          status: UserMealPlanStatus.active,
          dailyCalories: 2000,
          durationDays: 7,
          isActive: true,
        );
        fakeCache.saveActivePlan(userId, cachedPlan);
        
        // Start watching
        final stream = service.watchActivePlanWithCache(userId);
        final emissions = <UserMealPlan?>[];
        final subscription = stream.listen((plan) {
          emissions.add(plan);
        });
        
        // Wait for timeout (300ms) - Firestore hasn't emitted yet
        async.elapse(const Duration(milliseconds: 300));
        
        // Verify: Cached plan should be emitted as fallback
        expect(emissions.length, greaterThanOrEqualTo(1));
        expect(emissions.first?.id, equals('cached-plan'));
        
        // Now Firestore emits (after timeout)
        async.elapse(const Duration(milliseconds: 50));
        final firestorePlan = UserMealPlan(
          id: 'firestore-plan',
          userId: userId,
          name: 'Firestore Plan',
          goalType: MealPlanGoalType.maintain,
          type: UserMealPlanType.custom,
          startDate: DateTime.now(),
          currentDayIndex: 1,
          status: UserMealPlanStatus.active,
          dailyCalories: 2000,
          durationDays: 7,
          isActive: true,
        );
        fakeRepository.emitActivePlan(userId, firestorePlan);
        
        async.elapse(const Duration(milliseconds: 50));
        
        // Verify: Firestore plan should be emitted after cached plan
        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(emissions.last?.id, equals('firestore-plan'));
        
        subscription.cancel();
      });
    });

    test('deduplicates emissions by planId', () async {
      await FakeAsync().run((async) {
        const userId = 'test-user';
        
        // Start watching
        final stream = service.watchActivePlanWithCache(userId);
        final emissions = <UserMealPlan?>[];
        final subscription = stream.listen((plan) {
          emissions.add(plan);
        });
        
        // Firestore emits plan
        async.elapse(const Duration(milliseconds: 100));
        final plan1 = UserMealPlan(
          id: 'plan-1',
          userId: userId,
          name: 'Plan 1',
          goalType: MealPlanGoalType.maintain,
          type: UserMealPlanType.custom,
          startDate: DateTime.now(),
          currentDayIndex: 1,
          status: UserMealPlanStatus.active,
          dailyCalories: 2000,
          durationDays: 7,
          isActive: true,
        );
        fakeRepository.emitActivePlan(userId, plan1);
        async.elapse(const Duration(milliseconds: 50));
        
        // Firestore emits same plan again (same planId)
        fakeRepository.emitActivePlan(userId, plan1);
        async.elapse(const Duration(milliseconds: 50));
        
        // Verify: Only one emission for the same planId
        final plan1Emissions = emissions.where((p) => p?.id == 'plan-1').length;
        expect(plan1Emissions, equals(1), reason: 'Same planId should only emit once');
        
        // Firestore emits different plan
        final plan2 = UserMealPlan(
          id: 'plan-2',
          userId: userId,
          name: 'Plan 2',
          goalType: MealPlanGoalType.maintain,
          type: UserMealPlanType.custom,
          startDate: DateTime.now(),
          currentDayIndex: 1,
          status: UserMealPlanStatus.active,
          dailyCalories: 2000,
          durationDays: 7,
          isActive: true,
        );
        fakeRepository.emitActivePlan(userId, plan2);
        async.elapse(const Duration(milliseconds: 50));
        
        // Verify: Different planId should emit
        final plan2Emissions = emissions.where((p) => p?.id == 'plan-2').length;
        expect(plan2Emissions, equals(1), reason: 'Different planId should emit');
        
        subscription.cancel();
      });
    });

    test('emits null when no active plan exists and no cache', () async {
      await FakeAsync().run((async) {
        const userId = 'test-user';
        
        // Start watching (no cache, no Firestore plan)
        final stream = service.watchActivePlanWithCache(userId);
        final emissions = <UserMealPlan?>[];
        final subscription = stream.listen((plan) {
          emissions.add(plan);
        });
        
        // Wait for timeout
        async.elapse(const Duration(milliseconds: 300));
        
        // Verify: null should be emitted (no cache fallback)
        expect(emissions.length, greaterThanOrEqualTo(1));
        expect(emissions.first, isNull);
        
        subscription.cancel();
      });
    });
  });

  group('UserMealPlanService - meals stream behavior', () {
    late FakeUserMealPlanRepository fakeRepository;
    late FakeUserMealPlanCache fakeCache;
    late UserMealPlanService service;

    setUp(() {
      fakeRepository = FakeUserMealPlanRepository();
      fakeCache = FakeUserMealPlanCache();
      service = UserMealPlanService(fakeRepository, fakeCache);
    });

    tearDown(() {
      fakeRepository.dispose();
      fakeCache.clear();
    });

    test('meals stream emits empty list when day has no meals', () async {
      const planId = 'test-plan';
      const userId = 'test-user';
      const dayIndex = 1;
      
      // Get meals stream for a day with no meals
      final stream = service.getDayMeals(planId, userId, dayIndex);
      
      // Stream should emit at least once (empty list)
      final firstEmission = await stream.first.timeout(
        const Duration(seconds: 1),
        onTimeout: () => throw TimeoutException('Stream did not emit within timeout'),
      );
      
      expect(firstEmission, isA<List>());
      expect(firstEmission, isEmpty);
    });

    test('meals stream emits meals when they exist', () async {
      const planId = 'test-plan';
      const userId = 'test-user';
      const dayIndex = 1;
      
      // Create a meal
      final meal = user_meal_plan_repository.MealItem(
        id: 'meal-1',
        mealType: 'breakfast',
        foodId: 'food-1',
        servingSize: 1.0,
        calories: 300.0,
        protein: 20.0,
        carb: 30.0,
        fat: 10.0,
      );
      
      // Get meals stream
      final stream = service.getDayMeals(planId, userId, dayIndex);
      
      // Emit meals
      fakeRepository.emitDayMeals(planId, userId, dayIndex, [meal]);
      
      // Stream should emit the meals
      final emissions = await stream.take(2).toList();
      
      // First emission might be empty (from fake), second should have meals
      final lastEmission = emissions.last;
      expect(lastEmission, isNotEmpty);
      expect(lastEmission.first.id, equals('meal-1'));
    });
  });
}

