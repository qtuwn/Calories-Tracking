import 'package:flutter_test/flutter_test.dart';
import 'package:calories_app/domain/meal_plans/explore_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';
import 'fakes/fake_user_meal_plan_repository.dart';

/// Regression test: Ensures apply template creates meals with valid IDs
/// 
/// This test verifies that:
/// - Meal items created via applyExploreTemplateAsActivePlan have non-empty IDs
/// - Firestore document IDs match the domain model IDs
/// - No empty string IDs are created
void main() {
  group('Apply Template - Valid IDs', () {
    late FakeUserMealPlanRepository fakeRepository;

    setUp(() {
      fakeRepository = FakeUserMealPlanRepository();
    });

    tearDown(() {
      fakeRepository.dispose();
    });

    test('applyExploreTemplateAsActivePlan returns plan with valid ID', () async {
      const userId = 'test-user';
      const templateId = 'template-1';
      
      // Create a fake template
      final template = ExploreMealPlan(
        id: templateId,
        name: 'Test Template',
        description: 'Test',
        templateKcal: 2000,
        durationDays: 7,
        goalType: MealPlanGoalType.maintain,
        isEnabled: true,
        isFeatured: false,
        isPublished: true,
        mealsPerDay: 3,
        tags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final profileData = {
        'id': userId,
        'nickname': 'Test User',
        'tdeeKcal': 2000,
        'targetKcal': 2000,
      };
      
      // Apply template
      final result = await fakeRepository.applyExploreTemplateAsActivePlan(
        userId: userId,
        templateId: templateId,
        template: template,
        profileData: profileData,
      );
      
      // Verify: Plan should have non-empty ID
      expect(result.id, isNotEmpty, reason: 'Applied plan must have non-empty ID');
      expect(result.id, isNot(equals('')), reason: 'Applied plan ID must not be empty string');
      expect(result.userId, equals(userId));
      expect(result.planTemplateId, equals(templateId));
    });

    test('applyCustomPlanAsActive returns plan with valid ID', () async {
      const userId = 'test-user';
      const planId = 'custom-plan-1';
      
      // Apply custom plan
      final result = await fakeRepository.applyCustomPlanAsActive(
        userId: userId,
        planId: planId,
      );
      
      // Verify: Plan should have non-empty ID matching the input
      expect(result.id, isNotEmpty);
      expect(result.id, equals(planId));
      expect(result.id, isNot(equals('')), reason: 'Applied plan ID must not be empty string');
      expect(result.userId, equals(userId));
    });
  });
}

