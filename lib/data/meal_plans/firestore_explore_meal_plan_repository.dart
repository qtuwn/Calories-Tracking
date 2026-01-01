import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/meal_plans/explore_meal_plan.dart';
import '../../domain/meal_plans/explore_meal_plan_repository.dart';
import '../../domain/meal_plans/meal_plan_goal_type.dart';
import '../../domain/meal_plans/services/meal_nutrition_calculator.dart' show MealNutritionCalculator, MealNutrition;
import 'explore_meal_plan_dto.dart';
import 'explore_meal_plan_query_exception.dart';

/// Firestore implementation of ExploreMealPlanRepository
/// 
/// Collection: meal_plans/{planId}
/// Subcollections:
///   - days/{dayId} (contains dayIndex, totalCalories, protein, carb, fat)
///   - days/{dayId}/meals/{mealId} (contains meal details)
class FirestoreExploreMealPlanRepository implements ExploreMealPlanRepository {
  final FirebaseFirestore _firestore;

  FirestoreExploreMealPlanRepository({FirebaseFirestore? instance})
      : _firestore = instance ?? FirebaseFirestore.instance;

  @override
  Stream<List<ExploreMealPlan>> watchPublishedPlans() {
    debugPrint(
        '[FirestoreExploreMealPlanRepository] 🔵 Watching published plans '
        '(query: meal_plans where isPublished==true, isEnabled==true orderBy name)');

    return _firestore
        .collection('meal_plans')
        .where('isPublished', isEqualTo: true)
        .where('isEnabled', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      final plans = snapshot.docs
          .map((doc) {
            try {
              return ExploreMealPlanDto.fromFirestore(doc).toDomain();
            } catch (e) {
              debugPrint(
                  '[FirestoreExploreMealPlanRepository] ⚠️ Error parsing plan ${doc.id}: $e');
              return null;
            }
          })
          .whereType<ExploreMealPlan>()
          .toList();

      debugPrint(
          '[FirestoreExploreMealPlanRepository] ✅ Retrieved ${plans.length} published plans');
      return plans;
    }).handleError((error) {
      debugPrint(
          '[FirestoreExploreMealPlanRepository] 🔥 Error watching published plans: $error');
      
      // Transform FirebaseException to typed exception with user-friendly message
      if (error is FirebaseException) {
        final code = error.code;
        final message = error.message ?? '';
        
        debugPrint(
            '[FirestoreExploreMealPlanRepository] 🔥 FirebaseException code=$code, message=$message');
        
        if (code == 'failed-precondition') {
          // Composite index missing
          throw ExploreMealPlanQueryException(
            'Firestore index required for published plans query. '
            'Create composite index: isPublished ASC, isEnabled ASC, name ASC.',
            firebaseErrorCode: code,
            queryContext: 'watchPublishedPlans',
          );
        } else if (code == 'permission-denied') {
          throw ExploreMealPlanQueryException(
            'Permission denied: Cannot read published meal plans. '
            'Check Firestore security rules.',
            firebaseErrorCode: code,
            queryContext: 'watchPublishedPlans',
          );
        } else {
          // Generic Firebase error - wrap with context
          throw ExploreMealPlanQueryException(
            'Failed to load published meal plans: $message',
            firebaseErrorCode: code,
            queryContext: 'watchPublishedPlans',
          );
        }
      }
      
      // Re-throw non-Firebase exceptions as-is
      throw error;
    });
  }

  @override
  Stream<List<ExploreMealPlan>> watchAllPlans() {
    debugPrint('[FirestoreExploreMealPlanRepository] 🔵 Watching all plans (admin)');

    return _firestore
        .collection('meal_plans')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      final plans = snapshot.docs
          .map((doc) {
            try {
              return ExploreMealPlanDto.fromFirestore(doc).toDomain();
            } catch (e) {
              debugPrint(
                  '[FirestoreExploreMealPlanRepository] ⚠️ Error parsing plan ${doc.id}: $e');
              return null;
            }
          })
          .whereType<ExploreMealPlan>()
          .toList();

      debugPrint(
          '[FirestoreExploreMealPlanRepository] ✅ Retrieved ${plans.length} plans');
      return plans;
    }).handleError((error) {
      debugPrint(
          '[FirestoreExploreMealPlanRepository] 🔥 Error watching all plans: $error');
      throw error;
    });
  }

  @override
  Future<ExploreMealPlan?> getPlanById(String planId) async {
    try {
      debugPrint('[FirestoreExploreMealPlanRepository] 🔵 Getting plan: $planId');

      final doc = await _firestore.collection('meal_plans').doc(planId).get();

      if (!doc.exists) {
        debugPrint('[FirestoreExploreMealPlanRepository] ℹ️ Plan not found: $planId');
        return null;
      }

      final plan = ExploreMealPlanDto.fromFirestore(doc).toDomain();
      debugPrint('[FirestoreExploreMealPlanRepository] ✅ Retrieved plan: ${plan.name}');
      return plan;
    } catch (e, stackTrace) {
      debugPrint('[FirestoreExploreMealPlanRepository] 🔥 Error getting plan: $e');
      debugPrint('[FirestoreExploreMealPlanRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Stream<List<ExploreMealPlan>> searchPlans({
    String? query,
    MealPlanGoalType? goalType,
    int? minKcal,
    int? maxKcal,
    List<String>? tags,
  }) {
    debugPrint(
        '[FirestoreExploreMealPlanRepository] 🔵 Searching plans: query="$query", goalType=${goalType?.name}');

    Query queryRef = _firestore
        .collection('meal_plans')
        .where('isPublished', isEqualTo: true)
        .where('isEnabled', isEqualTo: true);

    if (goalType != null) {
      queryRef = queryRef.where('goalType', isEqualTo: goalType.name);
    }

    if (minKcal != null) {
      queryRef = queryRef.where('dailyCalories', isGreaterThanOrEqualTo: minKcal);
    }

    if (maxKcal != null) {
      queryRef = queryRef.where('dailyCalories', isLessThanOrEqualTo: maxKcal);
    }

    return queryRef.orderBy('name').limit(50).snapshots().map((snapshot) {
      var plans = snapshot.docs
          .map((doc) {
            try {
              return ExploreMealPlanDto.fromFirestore(doc).toDomain();
            } catch (e) {
              debugPrint(
                  '[FirestoreExploreMealPlanRepository] ⚠️ Error parsing plan ${doc.id}: $e');
              return null;
            }
          })
          .whereType<ExploreMealPlan>()
          .toList();

      // Filter by query (name/description) and tags in memory
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        plans = plans.where((plan) {
          return plan.name.toLowerCase().contains(queryLower) ||
              plan.description.toLowerCase().contains(queryLower);
        }).toList();
      }

      if (tags != null && tags.isNotEmpty) {
        plans = plans.where((plan) {
          return tags.any((tag) => plan.tags.contains(tag));
        }).toList();
      }

      debugPrint(
          '[FirestoreExploreMealPlanRepository] ✅ Found ${plans.length} plans');
      return plans;
    }).handleError((error) {
      debugPrint('[FirestoreExploreMealPlanRepository] 🔥 Error searching plans: $error');
      throw error;
    });
  }

  @override
  Stream<List<ExploreMealPlan>> getFeaturedPlans() {
    debugPrint('[FirestoreExploreMealPlanRepository] 🔵 Getting featured plans');

    return _firestore
        .collection('meal_plans')
        .where('isFeatured', isEqualTo: true)
        .where('isPublished', isEqualTo: true)
        .where('isEnabled', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      final plans = snapshot.docs
          .map((doc) => ExploreMealPlanDto.fromFirestore(doc).toDomain())
          .toList();

      debugPrint(
          '[FirestoreExploreMealPlanRepository] ✅ Retrieved ${plans.length} featured plans');
      return plans;
    }).handleError((error) {
      debugPrint(
          '[FirestoreExploreMealPlanRepository] 🔥 Error getting featured plans: $error');
      throw error;
    });
  }

  @override
  Stream<List<MealPlanDay>> getPlanDays(String planId) {
    debugPrint('[FirestoreExploreMealPlanRepository] 🔵 Getting days for plan: $planId');

    return _firestore
        .collection('meal_plans')
        .doc(planId)
        .collection('days')
        .orderBy('dayIndex')
        .snapshots()
        .map((snapshot) {
      final days = snapshot.docs
          .map((doc) => MealPlanDayDto.fromFirestore(doc).toDomain())
          .toList();

      debugPrint(
          '[FirestoreExploreMealPlanRepository] ✅ Retrieved ${days.length} days');
      return days;
    }).handleError((error) {
      debugPrint(
          '[FirestoreExploreMealPlanRepository] 🔥 Error getting days: $error');
      throw error;
    });
  }

  @override
  Stream<List<MealSlot>> getDayMeals(String planId, int dayIndex) {
    debugPrint(
        '[FirestoreExploreMealPlanRepository] 🔵 Getting meals for plan: $planId, day: $dayIndex');

    return _firestore
        .collection('meal_plans')
        .doc(planId)
        .collection('days')
        .where('dayIndex', isEqualTo: dayIndex)
        .limit(1)
        .snapshots()
        .asyncExpand((daySnapshot) {
      if (daySnapshot.docs.isEmpty) {
        debugPrint(
            '[FirestoreExploreMealPlanRepository] ⚠️ No day found for plan: $planId, day: $dayIndex');
        return Stream.value(<MealSlot>[]);
      }

      final dayDoc = daySnapshot.docs.first;

      return dayDoc.reference
          .collection('meals')
          .orderBy('mealType')
          .snapshots()
          .map((mealsSnapshot) {
        final meals = <MealSlot>[];
        for (final doc in mealsSnapshot.docs) {
          try {
            final dto = MealSlotDto.fromFirestore(doc);
            final meal = dto.toDomain();
            
            // Additional validation: ensure foodId is non-empty and servingSize > 0
            // (DTO parsing already validates servingSize, but defensive check)
            if (meal.foodId != null && meal.foodId!.trim().isEmpty) {
              debugPrint(
                  '[FirestoreExploreMealPlanRepository] ⚠️ Empty foodId in meal ${doc.id}, skipping');
              continue;
            }
            
            meals.add(meal);
          } catch (e) {
            // Log error once per failing doc, then propagate
            debugPrint(
                '[FirestoreExploreMealPlanRepository] 🔥 Error parsing meal ${doc.id}: $e');
            rethrow; // Propagate error instead of silently skipping
          }
        }

        debugPrint(
            '[FirestoreExploreMealPlanRepository] ✅ Loaded ${meals.length} meals');
        return meals;
      });
    }).handleError((error) {
      debugPrint(
          '[FirestoreExploreMealPlanRepository] 🔥 Error loading meals: $error');
      throw error;
    });
  }

  @override
  Future<ExploreMealPlan> createPlan(ExploreMealPlan plan) async {
    try {
      debugPrint('[FirestoreExploreMealPlanRepository] 🔵 Creating plan: ${plan.name}');

      final docRef = _firestore.collection('meal_plans').doc();

      // Set ID in the plan
      final planWithId = plan.copyWith(id: docRef.id);

      final dtoWithId = ExploreMealPlanDto.fromDomain(planWithId);
      await docRef.set(dtoWithId.toFirestore());

      debugPrint('[FirestoreExploreMealPlanRepository] ✅ Created plan: ${docRef.id}');
      return planWithId;
    } catch (e, stackTrace) {
      debugPrint('[FirestoreExploreMealPlanRepository] 🔥 Error creating plan: $e');
      debugPrint('[FirestoreExploreMealPlanRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> updatePlan(ExploreMealPlan plan) async {
    try {
      debugPrint('[FirestoreExploreMealPlanRepository] 🔵 Updating plan: ${plan.id}');

      final dto = ExploreMealPlanDto.fromDomain(plan);
      await _firestore
          .collection('meal_plans')
          .doc(plan.id)
          .update(dto.toFirestore());

      debugPrint('[FirestoreExploreMealPlanRepository] ✅ Updated plan: ${plan.id}');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreExploreMealPlanRepository] 🔥 Error updating plan: $e');
      debugPrint('[FirestoreExploreMealPlanRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> deletePlan(String planId) async {
    try {
      debugPrint('[FirestoreExploreMealPlanRepository] 🔵 Deleting plan: $planId');

      // Delete all days and meals (Firestore will cascade delete subcollections)
      final daysSnapshot = await _firestore
          .collection('meal_plans')
          .doc(planId)
          .collection('days')
          .get();

      final batch = _firestore.batch();

      for (final dayDoc in daysSnapshot.docs) {
        // Delete all meals in this day
        final mealsSnapshot = await dayDoc.reference.collection('meals').get();
        for (final mealDoc in mealsSnapshot.docs) {
          batch.delete(mealDoc.reference);
        }
        // Delete the day
        batch.delete(dayDoc.reference);
      }

      // Delete the plan document
      batch.delete(_firestore.collection('meal_plans').doc(planId));

      await batch.commit();

      debugPrint('[FirestoreExploreMealPlanRepository] ✅ Deleted plan: $planId');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreExploreMealPlanRepository] 🔥 Error deleting plan: $e');
      debugPrint('[FirestoreExploreMealPlanRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> setPublishStatus(String planId, bool isPublished) async {
    try {
      debugPrint(
          '[FirestoreExploreMealPlanRepository] 🔵 Setting publish status: $planId = $isPublished');

      await _firestore.collection('meal_plans').doc(planId).update({
        'isPublished': isPublished,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
          '[FirestoreExploreMealPlanRepository] ✅ Updated publish status: $planId');
    } catch (e, stackTrace) {
      debugPrint(
          '[FirestoreExploreMealPlanRepository] 🔥 Error setting publish status: $e');
      debugPrint('[FirestoreExploreMealPlanRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> saveDayMeals({
    required String planId,
    required int dayIndex,
    required List<MealSlot> mealsToSave,
    required List<String> mealsToDelete,
  }) async {
    try {
      debugPrint(
          '[FirestoreExploreMealPlanRepository] 🔵 Saving meals for plan: $planId, day: $dayIndex');

      // Find or create day document
      final daysQuery = await _firestore
          .collection('meal_plans')
          .doc(planId)
          .collection('days')
          .where('dayIndex', isEqualTo: dayIndex)
          .limit(1)
          .get();

      DocumentReference dayRef;
      if (daysQuery.docs.isEmpty) {
        // Create new day document
        dayRef = _firestore
            .collection('meal_plans')
            .doc(planId)
            .collection('days')
            .doc();

        // Calculate day totals from meals using domain service
        // This validates all meals before any Firestore writes
        final totals = MealNutritionCalculator.sumMealSlots(
          mealsToSave,
          planId: planId,
          dayIndex: dayIndex,
        );

        await dayRef.set({
          'dayIndex': dayIndex,
          'totalCalories': totals.calories,
          'protein': totals.protein,
          'carb': totals.carb,
          'fat': totals.fat,
        });
      } else {
        dayRef = daysQuery.docs.first.reference;
      }

      // Batch write meals
      final batch = _firestore.batch();

      // Delete meals
      for (final mealId in mealsToDelete) {
        batch.delete(dayRef.collection('meals').doc(mealId));
      }

      // Save/update meals
      for (final meal in mealsToSave) {
        final mealRef = meal.id.isEmpty
            ? dayRef.collection('meals').doc()
            : dayRef.collection('meals').doc(meal.id);

        final mealDto = MealSlotDto.fromDomain(meal.copyWith(id: mealRef.id));
        batch.set(mealRef, mealDto.toFirestore());
      }

      // Recalculate day totals using domain service
      // First, compute totals from meals being saved
      final savedTotals = MealNutritionCalculator.sumMealSlots(
        mealsToSave,
        planId: planId,
        dayIndex: dayIndex,
      );

      // Get existing meals that aren't being deleted
      final existingMealsSnapshot = await dayRef.collection('meals').get();
      final existingMeals = <MealSlot>[];
      for (final mealDoc in existingMealsSnapshot.docs) {
        if (!mealsToDelete.contains(mealDoc.id) &&
            !mealsToSave.any((m) => m.id == mealDoc.id)) {
          final meal = MealSlotDto.fromFirestore(mealDoc).toDomain();
          existingMeals.add(meal);
        }
      }

      // Compute totals from existing meals
      final existingTotals = existingMeals.isEmpty
          ? MealNutrition.empty
          : MealNutritionCalculator.sumMealSlots(
              existingMeals,
              planId: planId,
              dayIndex: dayIndex,
            );

      // Combine totals (domain service handles validation)
      final combinedTotals = savedTotals.add(existingTotals);

      // Update day totals using domain-calculated values
      batch.update(dayRef, {
        'totalCalories': combinedTotals.calories,
        'protein': combinedTotals.protein,
        'carb': combinedTotals.carb,
        'fat': combinedTotals.fat,
      });

      await batch.commit();

      debugPrint(
          '[FirestoreExploreMealPlanRepository] ✅ Saved ${mealsToSave.length} meals, deleted ${mealsToDelete.length} meals');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreExploreMealPlanRepository] 🔥 Error saving meals: $e');
      debugPrint('[FirestoreExploreMealPlanRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

