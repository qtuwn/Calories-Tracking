import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calories_app/data/meal_plans/explore_meal_plan_dto.dart';
import 'package:calories_app/domain/meal_plans/explore_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';

/// Regression test: Ensure metadata fields (description, tags, difficulty) are preserved
/// in DTO roundtrip conversions (domain ↔ DTO ↔ Firestore)
void main() {
  group('ExploreMealPlanDto Metadata Preservation', () {
    test('toFirestore includes description, tags, and difficulty', () {
      final plan = ExploreMealPlan(
        id: 'test-plan',
        name: 'Test Plan',
        goalType: MealPlanGoalType.maintain,
        description: 'A comprehensive meal plan for maintaining weight',
        templateKcal: 2000,
        durationDays: 7,
        mealsPerDay: 3,
        tags: ['healthy', 'balanced', 'vegetarian'],
        isFeatured: false,
        isPublished: true,
        isEnabled: true,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        createdBy: 'admin-123',
        difficulty: 'medium',
      );

      final dto = ExploreMealPlanDto.fromDomain(plan);
      final firestoreMap = dto.toFirestore();

      // Verify all metadata fields are present
      expect(firestoreMap['description'], equals('A comprehensive meal plan for maintaining weight'));
      expect(firestoreMap['tags'], isA<List>());
      expect(firestoreMap['tags'], equals(['healthy', 'balanced', 'vegetarian']));
      expect(firestoreMap['difficulty'], equals('medium'));
    });

    test('fromDomain preserves description, tags, and difficulty', () {
      final plan = ExploreMealPlan(
        id: 'test-plan',
        name: 'Test Plan',
        goalType: MealPlanGoalType.maintain,
        description: 'A comprehensive meal plan',
        templateKcal: 2000,
        durationDays: 7,
        mealsPerDay: 3,
        tags: ['healthy', 'balanced'],
        isFeatured: false,
        isPublished: true,
        isEnabled: true,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        createdBy: 'admin-123',
        difficulty: 'hard',
      );

      final dto = ExploreMealPlanDto.fromDomain(plan);

      // Verify all metadata fields are preserved in DTO
      expect(dto.description, equals('A comprehensive meal plan'));
      expect(dto.tags, equals(['healthy', 'balanced']));
      expect(dto.difficulty, equals('hard'));
      expect(dto.createdBy, equals('admin-123'));
    });

    test('roundtrip: domain → DTO → Firestore map → DTO → domain preserves metadata', () {
      final originalPlan = ExploreMealPlan(
        id: 'test-plan',
        name: 'Test Plan',
        goalType: MealPlanGoalType.loseFat,
        description: 'Weight loss meal plan',
        templateKcal: 1500,
        durationDays: 14,
        mealsPerDay: 4,
        tags: ['low-cal', 'high-protein', 'keto'],
        isFeatured: true,
        isPublished: true,
        isEnabled: true,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        createdBy: 'admin-456',
        difficulty: 'easy',
      );

      // Domain → DTO
      final dto = ExploreMealPlanDto.fromDomain(originalPlan);
      
      // DTO → Firestore map
      final firestoreMap = dto.toFirestore();
      
      // Verify Firestore map contains all metadata
      expect(firestoreMap['description'], equals(originalPlan.description));
      expect(firestoreMap['tags'], equals(originalPlan.tags));
      expect(firestoreMap['difficulty'], equals(originalPlan.difficulty));
      expect(firestoreMap['createdBy'], equals(originalPlan.createdBy));
      
      // DTO → Domain (verify roundtrip)
      final rehydratedPlan = dto.toDomain();

      // Verify all metadata fields are preserved
      expect(rehydratedPlan.description, equals(originalPlan.description));
      expect(rehydratedPlan.tags, equals(originalPlan.tags));
      expect(rehydratedPlan.difficulty, equals(originalPlan.difficulty));
      expect(rehydratedPlan.createdBy, equals(originalPlan.createdBy));
    });

    test('handles null/empty metadata fields correctly', () {
      final plan = ExploreMealPlan(
        id: 'test-plan',
        name: 'Test Plan',
        goalType: MealPlanGoalType.maintain,
        description: '', // Empty description
        templateKcal: 2000,
        durationDays: 7,
        mealsPerDay: 3,
        tags: [], // Empty tags
        isFeatured: false,
        isPublished: true,
        isEnabled: true,
        createdAt: DateTime(2024, 1, 1),
        difficulty: null, // Null difficulty
        createdBy: null, // Null createdBy
      );

      final dto = ExploreMealPlanDto.fromDomain(plan);
      final firestoreMap = dto.toFirestore();

      // Verify empty/null fields are handled
      expect(firestoreMap['description'], equals(''));
      expect(firestoreMap['tags'], isA<List>());
      expect(firestoreMap['tags'], isEmpty);
      expect(firestoreMap.containsKey('difficulty'), isFalse); // Optional field not included if null
      expect(firestoreMap.containsKey('createdBy'), isFalse); // Optional field not included if null
    });

    test('toFirestore omits null optional fields', () {
      final plan = ExploreMealPlan(
        id: 'test-plan',
        name: 'Test Plan',
        goalType: MealPlanGoalType.maintain,
        description: 'Test description',
        templateKcal: 2000,
        durationDays: 7,
        mealsPerDay: 3,
        tags: ['tag1'],
        isFeatured: false,
        isPublished: true,
        isEnabled: true,
        createdAt: DateTime(2024, 1, 1),
        difficulty: null, // Null difficulty
        createdBy: null, // Null createdBy
      );

      final dto = ExploreMealPlanDto.fromDomain(plan);
      final firestoreMap = dto.toFirestore();

      // Verify required fields are present
      expect(firestoreMap['description'], equals('Test description'));
      expect(firestoreMap['tags'], equals(['tag1']));
      
      // Verify optional fields are omitted when null (not included in map)
      expect(firestoreMap.containsKey('difficulty'), isFalse);
      expect(firestoreMap.containsKey('createdBy'), isFalse);
    });
  });
}

