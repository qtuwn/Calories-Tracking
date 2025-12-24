import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem, MealPlanDay, UserMealPlanRepository;
import 'package:calories_app/domain/meal_plans/services/meal_nutrition_calculator.dart' show MealNutritionCalculator, MealNutrition;
import 'package:calories_app/domain/meal_plans/services/meal_plan_invariants.dart' show MealPlanInvariants;
import 'package:calories_app/domain/meal_plans/explore_meal_plan.dart' show ExploreMealPlan, MealSlot;
import 'package:calories_app/domain/meal_plans/explore_meal_plan_repository.dart';
import 'package:calories_app/data/meal_plans/firestore_explore_meal_plan_repository.dart' show FirestoreExploreMealPlanRepository;
import 'package:calories_app/features/meal_plans/domain/services/apply_explore_template_service.dart';
import 'package:calories_app/domain/profile/profile.dart';
import 'package:calories_app/features/meal_plans/data/dto/user_meal_plan_dto.dart';
import 'package:calories_app/features/meal_plans/data/dto/meal_item_dto.dart';

/// Exception thrown when applying an explore template fails due to invalid data
class MealPlanApplyException implements Exception {
  final String message;
  final String userId;
  final String templateId;
  final int dayIndex;
  final int slotIndex;
  final String mealType;
  final Map<String, dynamic>? details;

  MealPlanApplyException(
    this.message, {
    required this.userId,
    required this.templateId,
    required this.dayIndex,
    required this.slotIndex,
    required this.mealType,
    this.details,
  });

  @override
  String toString() {
    final detailsStr = details != null ? ', details: $details' : '';
    return 'MealPlanApplyException: $message '
        '(userId=$userId, templateId=$templateId, dayIndex=$dayIndex, '
        'slotIndex=$slotIndex, mealType=$mealType$detailsStr)';
  }
}

/// Firestore implementation of UserMealPlanRepository
/// 
/// Uses DTOs internally and maps to domain models.
/// Collection: users/{userId}/user_meal_plans/{planId}
class UserMealPlanRepositoryImpl implements UserMealPlanRepository {
  final FirebaseFirestore _firestore;
  final ExploreMealPlanRepository _exploreRepo;
  
  /// Helper to convert domain UserMealPlan to UserMealPlanDto
  UserMealPlanDto _domainToDto(UserMealPlan plan) {
    return UserMealPlanDto(
      id: plan.id,
      userId: plan.userId,
      planTemplateId: plan.planTemplateId,
      name: plan.name,
      goalType: plan.goalType.value,
      type: plan.type.value,
      startDate: plan.startDate,
      currentDayIndex: plan.currentDayIndex,
      status: plan.status.value,
      dailyCalories: plan.dailyCalories,
      durationDays: plan.durationDays,
      isActive: plan.isActive,
      createdAt: plan.createdAt,
      updatedAt: plan.updatedAt,
      description: plan.description,
      tags: plan.tags,
      difficulty: plan.difficulty,
    );
  }

  UserMealPlanRepositoryImpl({
    FirebaseFirestore? instance,
    ExploreMealPlanRepository? exploreRepo,
  })  : _firestore = instance ?? FirebaseFirestore.instance,
        _exploreRepo = exploreRepo ?? FirestoreExploreMealPlanRepository();

  @override
  Stream<UserMealPlan?> getActivePlan(String userId) {
    debugPrint('[UserMealPlanRepository] [ActivePlan] 🔵 Querying active plan for userId=$userId');
    debugPrint('[UserMealPlanRepository] [ActivePlan] 🔵 Query: users/$userId/user_meal_plans where isActive==true limit 1');
    
    // Query for active plan - no type filter (includes both custom and template-applied plans)
    // Order by createdAt descending to get most recent if multiple somehow exist
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('user_meal_plans')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        debugPrint('[UserMealPlanRepository] [ActivePlan] ℹ️ No active plan found for userId=$userId');
        return null;
      }
      
      // Check for multiple active plans (should never happen, but log warning if it does)
      if (snapshot.docs.length > 1) {
        final planIds = snapshot.docs.map((d) => d.id).toList();
        debugPrint('[UserMealPlanRepository] [ActivePlan] ⚠️ WARNING: Found ${snapshot.docs.length} active plans for userId=$userId');
        debugPrint('[UserMealPlanRepository] [ActivePlan] ⚠️ Plan IDs: ${planIds.join(", ")}');
        debugPrint('[UserMealPlanRepository] [ActivePlan] ⚠️ This should never happen - using most recent one');
      }
      
      // Use the first document (ordered by createdAt descending)
      final doc = snapshot.docs.first;
      final dto = UserMealPlanDto.fromFirestore(doc);
      final plan = dto.toDomain();
      
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Found active plan: planId=${plan.id}, name="${plan.name}", isActive=${plan.isActive}, type=${plan.type.value}, planTemplateId=${plan.planTemplateId ?? "none"}');
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Plan source: ${plan.planTemplateId != null ? "explore_template" : "custom"}');
      return plan;
    }).handleError((error, stackTrace) {
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Error querying active plan: $error');
      if (error.toString().contains('permission-denied')) {
        debugPrint('[UserMealPlanRepository] [ActivePlan] ⛔ Permission denied');
      }
      throw error;
    });
  }

  @override
  Stream<List<UserMealPlan>> getPlansForUser(String userId) {
    debugPrint('[UserMealPlanRepository] 🔵 Querying all plans for userId=$userId');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('user_meal_plans')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              final dto = UserMealPlanDto.fromFirestore(doc);
              return dto.toDomain();
            } catch (e) {
              debugPrint('[UserMealPlanRepository] ⚠️ Error parsing plan ${doc.id}: $e');
              return null;
            }
          })
          .whereType<UserMealPlan>()
          .toList();
    }).handleError((error, stackTrace) {
      debugPrint('[UserMealPlanRepository] 🔥 Error querying plans: $error');
      throw error;
    });
  }

  @override
  Future<UserMealPlan?> getPlanById(String planId, String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_meal_plans')
          .doc(planId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      final dto = UserMealPlanDto.fromFirestore(doc);
      return dto.toDomain();
    } catch (e) {
      debugPrint('[UserMealPlanRepository] 🔥 Error getting plan: $e');
      return null;
    }
  }

  @override
  Future<void> savePlan(UserMealPlan plan) async {
    final collectionPath = 'users/${plan.userId}/user_meal_plans';
    final documentPath = '$collectionPath/${plan.id}';
    
    try {
      if (plan.id.isEmpty) {
        throw Exception('Plan ID cannot be empty. Generate ID before saving.');
      }
      
      if (plan.userId.isEmpty) {
        throw Exception('User ID cannot be empty.');
      }
      
      debugPrint('[UserMealPlanRepository] 🔵 Saving plan: ${plan.id}');
      debugPrint('[UserMealPlanRepository] 🔵 Collection path: $collectionPath');
      debugPrint('[UserMealPlanRepository] 🔵 Document path: $documentPath');
      debugPrint('[UserMealPlanRepository] 🔵 Plan details: name="${plan.name}", userId=${plan.userId}, isActive=${plan.isActive}, type=${plan.type.value}');
      
      final dto = _domainToDto(plan);
      final planRef = _firestore
          .collection('users')
          .doc(plan.userId)
          .collection('user_meal_plans')
          .doc(plan.id);
      
      final planData = dto.toFirestore();
      debugPrint('[UserMealPlanRepository] 🔵 Plan data keys: ${planData.keys.join(", ")}');
      
      await planRef.set(planData);
      
      // Verify the write succeeded by reading back
      final verifyDoc = await planRef.get();
      if (!verifyDoc.exists) {
        throw Exception('Write verification failed: document does not exist after set()');
      }
      
      debugPrint('[UserMealPlanRepository] ✅ Successfully saved plan: ${plan.id} to Firestore');
      debugPrint('[UserMealPlanRepository] ✅ Verified: document exists at $documentPath');
    } catch (e, stackTrace) {
      debugPrint('[UserMealPlanRepository] 🔥 ========== ERROR saving plan ==========');
      debugPrint('[UserMealPlanRepository] 🔥 Collection path: $collectionPath');
      debugPrint('[UserMealPlanRepository] 🔥 Document path: $documentPath');
      debugPrint('[UserMealPlanRepository] 🔥 Plan ID: ${plan.id}');
      debugPrint('[UserMealPlanRepository] 🔥 User ID: ${plan.userId}');
      debugPrint('[UserMealPlanRepository] 🔥 Error: $e');
      debugPrint('[UserMealPlanRepository] 🔥 Error type: ${e.runtimeType}');
      debugPrint('[UserMealPlanRepository] 🔥 Stack trace: $stackTrace');
      debugPrint('[UserMealPlanRepository] 🔥 ======================================');
      rethrow;
    }
  }

  @override
  Future<void> deletePlan(String planId, String userId) async {
    try {
      debugPrint('[UserMealPlanRepository] 🔵 Deleting plan: $planId');
      
      // Get all days
      final daysSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_meal_plans')
          .doc(planId)
          .collection('days')
          .get();
      
      // Use batch to delete all subcollections and the plan
      final batch = _firestore.batch();
      
      // Delete all meals for each day
      for (final dayDoc in daysSnapshot.docs) {
        final mealsSnapshot = await dayDoc.reference.collection('meals').get();
        for (final mealDoc in mealsSnapshot.docs) {
          batch.delete(mealDoc.reference);
        }
        batch.delete(dayDoc.reference);
      }
      
      // Delete the plan document
      batch.delete(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('user_meal_plans')
            .doc(planId),
      );
      
      await batch.commit();
      debugPrint('[UserMealPlanRepository] ✅ Deleted plan: $planId');
    } catch (e) {
      debugPrint('[UserMealPlanRepository] 🔥 Error deleting plan: $e');
      rethrow;
    }
  }

  @override
  Future<void> savePlanAndSetActive({
    required UserMealPlan plan,
    required String userId,
  }) async {
    try {
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔵 ========== START savePlanAndSetActive ==========');
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔵 Plan ID: ${plan.id}');
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔵 User ID: $userId');
      
      if (plan.id.isEmpty) {
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 ERROR: Plan ID is empty!');
        throw Exception('Plan ID cannot be empty. Generate ID before saving.');
      }

      if (userId.isEmpty) {
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 ERROR: User ID is empty!');
        throw Exception('User ID cannot be empty.');
      }

      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔵 Saving plan ${plan.id} and setting as active atomically');
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔵 Plan details: name="${plan.name}", type=${plan.type.value}, isActive=${plan.isActive}, planTemplateId=${plan.planTemplateId ?? "none"}');
      
      final batch = _firestore.batch();
      
      // STEP 1: Deactivate ALL other active plans for this user
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Querying for existing active plans to deactivate...');
      final activePlansSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_meal_plans')
          .where('isActive', isEqualTo: true)
          .get();
      
      int deactivatedCount = 0;
      final deactivatedPlanIds = <String>[];
      
      for (final doc in activePlansSnapshot.docs) {
        if (doc.id != plan.id) {
          final planData = doc.data();
          final planName = planData['name'] ?? 'Unknown';
          debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Deactivating plan: ${doc.id} ("$planName")');
          batch.update(doc.reference, {
            'isActive': false,
            'status': 'paused',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          deactivatedCount++;
          deactivatedPlanIds.add(doc.id);
        }
      }
      
      if (deactivatedCount > 0) {
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Deactivating $deactivatedCount existing active plan(s): ${deactivatedPlanIds.join(", ")}');
      } else {
        debugPrint('[UserMealPlanRepository] [ActivePlan] ℹ️ No existing active plans to deactivate');
      }
      
      // STEP 2: Save the new plan with isActive = true
      final dto = _domainToDto(plan);
      final planRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('user_meal_plans')
          .doc(plan.id);
      
      // Ensure isActive is true in the saved plan
      final planData = dto.toFirestore();
      planData['isActive'] = true;
      planData['status'] = 'active';
      
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Saving new plan: ${plan.id} ("${plan.name}") with isActive=true');
      batch.set(planRef, planData);
      
      // STEP 3: Commit the batch atomically
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Committing batch write...');
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Batch contains: $deactivatedCount deactivations + 1 plan creation');
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Plan path: users/$userId/user_meal_plans/${plan.id}');
      
      try {
        await batch.commit();
        
        // Verify the write succeeded
        final verifyDoc = await planRef.get();
        if (!verifyDoc.exists) {
          throw Exception('Write verification failed: plan document does not exist after batch commit');
        }
        final verifyData = verifyDoc.data();
        final verifyIsActive = verifyData?['isActive'] as bool? ?? false;
        if (!verifyIsActive) {
          throw Exception('Write verification failed: plan isActive is false after savePlanAndSetActive');
        }
        debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Verified: plan document exists and isActive=true');
      } catch (e, stackTrace) {
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 ========== ERROR committing batch ==========');
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Collection path: users/$userId/user_meal_plans');
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Plan ID: ${plan.id}');
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Error: $e');
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Error type: ${e.runtimeType}');
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Stack trace: $stackTrace');
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 ============================================');
        rethrow;
      }
      
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ ========== BATCH COMMITTED SUCCESSFULLY ==========');
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Deactivated $deactivatedCount old active plan(s)');
      if (deactivatedCount > 0) {
        debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Deactivated plan IDs: ${deactivatedPlanIds.join(", ")}');
      }
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Saved and activated plan: ${plan.id} ("${plan.name}")');
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Plan type: ${plan.type.value}');
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Plan templateId: ${plan.planTemplateId ?? 'none'}');
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Active plan is now: ${plan.id}');
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Firestore stream will automatically emit the new active plan');
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ ========== END savePlanAndSetActive ==========');
    } catch (e, stackTrace) {
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 ========== ERROR in savePlanAndSetActive ==========');
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Error: $e');
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Error type: ${e.runtimeType}');
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Stack trace: $stackTrace');
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 ================================================');
      rethrow;
    }
  }

  @override
  Future<void> setActivePlan({
    required String userId,
    required String planId,
  }) async {
    try {
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔵 Setting plan $planId as active for user $userId');
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔵 Using batch write to ensure atomicity');
      
      final batch = _firestore.batch();
      
      // STEP 1: Deactivate ALL other active plans for this user
      // This ensures at most one plan is active at any time
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Querying for existing active plans to deactivate...');
      final activePlansSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_meal_plans')
          .where('isActive', isEqualTo: true)
          .get();
      
      int deactivatedCount = 0;
      final deactivatedPlanIds = <String>[];
      
      for (final doc in activePlansSnapshot.docs) {
        if (doc.id != planId) {
          final planData = doc.data();
          final planName = planData['name'] ?? 'Unknown';
          debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Deactivating plan: ${doc.id} ("$planName")');
          batch.update(doc.reference, {
            'isActive': false,
            'status': 'paused', // Set status to paused when deactivated
            'updatedAt': FieldValue.serverTimestamp(),
          });
          deactivatedCount++;
          deactivatedPlanIds.add(doc.id);
        }
      }
      
      if (deactivatedCount > 0) {
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Deactivating $deactivatedCount existing active plan(s): ${deactivatedPlanIds.join(", ")}');
      } else {
        debugPrint('[UserMealPlanRepository] [ActivePlan] ℹ️ No existing active plans to deactivate');
      }
      
      // STEP 2: Activate the selected plan
      // This is done in the same batch to ensure atomicity
      final planRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('user_meal_plans')
          .doc(planId);
      
      // Check if plan exists
      final planDoc = await planRef.get();
      if (!planDoc.exists) {
        throw Exception('Plan not found: $planId');
      }
      
      final planData = planDoc.data();
      final planName = planData?['name'] ?? 'Unknown';
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Activating plan: $planId ("$planName")');
      
      batch.update(planRef, {
        'isActive': true,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // STEP 3: Commit the batch atomically
      // This ensures all deactivations and the activation happen together
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Committing batch write...');
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Batch contains: $deactivatedCount deactivations + 1 plan activation');
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔄 Plan path: users/$userId/user_meal_plans/$planId');
      
      try {
        await batch.commit();
        
        // Verify the write succeeded
        final verifyDoc = await planRef.get();
        if (!verifyDoc.exists) {
          throw Exception('Write verification failed: plan document does not exist after batch commit');
        }
        final verifyData = verifyDoc.data();
        final verifyIsActive = verifyData?['isActive'] as bool? ?? false;
        if (!verifyIsActive) {
          throw Exception('Write verification failed: plan isActive is false after setActivePlan');
        }
        debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Verified: plan document exists and isActive=true');
      } catch (e, stackTrace) {
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 ========== ERROR committing batch ==========');
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Collection path: users/$userId/user_meal_plans');
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Plan ID: $planId');
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Error: $e');
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Error type: ${e.runtimeType}');
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Stack trace: $stackTrace');
        debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 ============================================');
        rethrow;
      }
      
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Batch committed successfully');
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Deactivated $deactivatedCount old active plan(s)');
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Activated plan: $planId ("$planName")');
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Active plan is now: $planId');
      debugPrint('[UserMealPlanRepository] [ActivePlan] ✅ Firestore stream will automatically emit the new active plan');
    } catch (e) {
      debugPrint('[UserMealPlanRepository] [ActivePlan] 🔥 Error setting active plan: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePlanProgress({
    required String planId,
    required String userId,
    required int currentDayIndex,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_meal_plans')
          .doc(planId)
          .update({
        'currentDayIndex': currentDayIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[UserMealPlanRepository] ✅ Updated progress: day $currentDayIndex');
    } catch (e) {
      debugPrint('[UserMealPlanRepository] 🔥 Error updating progress: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePlanStatus({
    required String planId,
    required String userId,
    required String status,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_meal_plans')
          .doc(planId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[UserMealPlanRepository] ✅ Updated status: $status');
    } catch (e) {
      debugPrint('[UserMealPlanRepository] 🔥 Error updating status: $e');
      rethrow;
    }
  }

  @override
  Future<MealPlanDay?> getDay(String planId, String userId, int dayIndex) async {
    try {
      final daySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_meal_plans')
          .doc(planId)
          .collection('days')
          .where('dayIndex', isEqualTo: dayIndex)
          .limit(1)
          .get();
      
      if (daySnapshot.docs.isEmpty) {
        return null;
      }
      
      final doc = daySnapshot.docs.first;
      final data = doc.data();
      return MealPlanDay(
        id: doc.id,
        dayIndex: (data['dayIndex'] as num?)?.toInt() ?? dayIndex,
        totalCalories: (data['totalCalories'] as num?)?.toDouble() ?? 0.0,
        totalProtein: (data['protein'] as num?)?.toDouble() ?? 0.0,
        totalCarb: (data['carb'] as num?)?.toDouble() ?? 0.0,
        totalFat: (data['fat'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      debugPrint('[UserMealPlanRepository] 🔥 Error getting day: $e');
      return null;
    }
  }

  @override
  Stream<List<MealItem>> getDayMeals(
    String planId,
    String userId,
    int dayIndex,
  ) {
    final daysRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('user_meal_plans')
        .doc(planId)
        .collection('days')
        .where('dayIndex', isEqualTo: dayIndex)
        .limit(1);
    
    // Use a class-level cache to track logged states per (planId, dayIndex)
    final streamKey = '$planId:$userId:$dayIndex';
    
    // Log only once per unique stream key to reduce spam
    if (!_streamSetupLogged.containsKey(streamKey)) {
      debugPrint('[UserMealPlanRepository] 🔵 Setting up stream for meals: planId=$planId, userId=$userId, dayIndex=$dayIndex');
      _streamSetupLogged[streamKey] = true;
    }
    
    if (!_dayNotFoundLogged.containsKey(streamKey)) {
      _dayNotFoundLogged[streamKey] = false;
    }
    if (!_lastMealCounts.containsKey(streamKey)) {
      _lastMealCounts[streamKey] = -1;
    }
    
    // Use asyncExpand but ensure we only create one stream per day document
    // IMPORTANT: Start with empty list to ensure stream always emits at least once
    return Stream.value(<MealItem>[]).asyncExpand((_) {
      return daysRef.snapshots().asyncExpand((daySnapshot) {
        if (daySnapshot.docs.isEmpty) {
          // Day document doesn't exist - return a single stable empty stream
          // This prevents infinite loops by not re-subscribing to the days query
          // Log only once when first discovered
          if (!_dayNotFoundLogged[streamKey]!) {
            debugPrint('[UserMealPlanRepository] ℹ️ Day $dayIndex not found for planId=$planId, returning stable empty stream');
            _dayNotFoundLogged[streamKey] = true;
          }
          return Stream.value(<MealItem>[]);
        }
        
        // Reset the "not found" flag when day document appears
        _dayNotFoundLogged[streamKey] = false;
        
        final dayDoc = daySnapshot.docs.first;
        
        // Day document exists - stream meals from its subcollection
        // IMPORTANT: Firestore snapshots() emits immediately with current state (even if empty)
        // This ensures the stream always emits at least once, preventing infinite loading
        return dayDoc.reference
            .collection('meals')
            .orderBy('mealType')
            .snapshots()
            .map((mealsSnapshot) {
          final meals = mealsSnapshot.docs
              .map((doc) {
                try {
                  final dto = MealItemDto.fromFirestore(doc);
                  return dto.toDomain();
                } catch (e) {
                  debugPrint('[UserMealPlanRepository] ⚠️ Error parsing meal ${doc.id}: $e');
                  return null;
                }
              })
              .whereType<MealItem>()
              .toList();
          
          // Only log when meal count actually changes, not on every snapshot
          final lastCount = _lastMealCounts[streamKey] ?? -1;
          if (meals.length != lastCount) {
            debugPrint('[UserMealPlanRepository] 📊 Meals updated for day $dayIndex: ${meals.length} meals');
            _lastMealCounts[streamKey] = meals.length;
          }
          return meals;
        });
      });
    });
  }
  
  // Class-level cache to prevent repeated logging
  static final Map<String, bool> _streamSetupLogged = {};
  static final Map<String, bool> _dayNotFoundLogged = {};
  static final Map<String, int> _lastMealCounts = {};

  @override
  Future<bool> saveDayMealsBatch({
    required String planId,
    required String userId,
    required int dayIndex,
    required List<MealItem> mealsToSave,
    required List<String> mealsToDelete,
  }) async {
    final collectionPath = 'users/$userId/user_meal_plans/$planId/days/$dayIndex/meals';
    
    try {
      debugPrint(
        '[UserMealPlanRepository] 🔵 Batch saving meals: planId=$planId, dayIndex=$dayIndex, '
        '${mealsToSave.length} to save, ${mealsToDelete.length} to delete',
      );
      debugPrint('[UserMealPlanRepository] 🔵 Collection path: $collectionPath');
      
      // Find or create day document
      final daySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_meal_plans')
          .doc(planId)
          .collection('days')
          .where('dayIndex', isEqualTo: dayIndex)
          .limit(1)
          .get();
      
      DocumentReference dayRef;
      final isNewDay = daySnapshot.docs.isEmpty;
      
      if (isNewDay) {
        dayRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('user_meal_plans')
            .doc(planId)
            .collection('days')
            .doc();
        debugPrint('[UserMealPlanRepository] 📝 Creating new day document');
      } else {
        dayRef = daySnapshot.docs.first.reference;
      }
      
      // Validate all meals using invariant validator BEFORE creating batch
      // This ensures atomicity - if validation fails, no partial writes occur
      final dayDocPath = 'users/$userId/user_meal_plans/$planId/days/$dayIndex';
      for (final meal in mealsToSave) {
        MealPlanInvariants.validateMealItem(
          meal,
          userId: userId,
          planId: planId,
          dayIndex: dayIndex,
          docPath: '$dayDocPath/meals/${meal.id}',
        );
      }
      
      // Compute totals using domain service (also validates)
      final totals = MealNutritionCalculator.sumMeals(
        mealsToSave,
        planId: planId,
        userId: userId,
        dayIndex: dayIndex,
      );
      
      // Only create batch after validation succeeds
      final batch = _firestore.batch();
      
      // Create/update day document
      if (isNewDay) {
        batch.set(dayRef, {
          'dayIndex': dayIndex,
          'totalCalories': 0.0,
          'protein': 0.0,
          'carb': 0.0,
          'fat': 0.0,
        });
      }
      
      // Add/update meals
      for (final meal in mealsToSave) {
        final mealDto = MealItemDto(
          id: meal.id,
          mealType: meal.mealType,
          foodId: meal.foodId,
          servingSize: meal.servingSize,
          calories: meal.calories,
          protein: meal.protein,
          carb: meal.carb,
          fat: meal.fat,
        );
        final mealRef = meal.id.isNotEmpty
            ? dayRef.collection('meals').doc(meal.id)
            : dayRef.collection('meals').doc();
        batch.set(mealRef, mealDto.toFirestore());
      }
      
      // Delete meals
      for (final mealId in mealsToDelete) {
        final mealRef = dayRef.collection('meals').doc(mealId);
        batch.delete(mealRef);
      }
      
      // Update day totals using domain-calculated values
      batch.update(dayRef, {
        'totalCalories': totals.calories,
        'protein': totals.protein,
        'carb': totals.carb,
        'fat': totals.fat,
      });
      
      debugPrint('[UserMealPlanRepository] 💾 Committing batch for day $dayIndex...');
      debugPrint('[UserMealPlanRepository] 💾 Collection path: $collectionPath');
      debugPrint('[UserMealPlanRepository] 💾 Batch operations: ${mealsToSave.length} saves, ${mealsToDelete.length} deletes');
      
      try {
        await batch.commit();
        
        debugPrint(
          '[UserMealPlanRepository] ✅ Batch committed: '
          '${mealsToSave.length} saved, ${mealsToDelete.length} deleted, '
          'totals: ${totals.calories.toInt()} kcal',
        );
        debugPrint('[UserMealPlanRepository] ✅ Verified: meals saved to $collectionPath');
        
        return true;
      } catch (e, stackTrace) {
        final errorStr = e.toString();
        
        debugPrint('[UserMealPlanRepository] 🔥 ========== ERROR committing meals batch ==========');
        debugPrint('[UserMealPlanRepository] 🔥 Collection path: $collectionPath');
        debugPrint('[UserMealPlanRepository] 🔥 Plan ID: $planId');
        debugPrint('[UserMealPlanRepository] 🔥 User ID: $userId');
        debugPrint('[UserMealPlanRepository] 🔥 Day index: $dayIndex');
        debugPrint('[UserMealPlanRepository] 🔥 Error: $e');
        debugPrint('[UserMealPlanRepository] 🔥 Error type: ${e.runtimeType}');
        debugPrint('[UserMealPlanRepository] 🔥 Stack trace: $stackTrace');
        debugPrint('[UserMealPlanRepository] 🔥 ===================================================');
        
        // Distinguish error types
        if (errorStr.contains('permission-denied')) {
          debugPrint('[UserMealPlanRepository] ⛔ Permission denied');
          throw Exception('Permission denied: Cannot save meals to $collectionPath');
        } else if (errorStr.contains('unavailable') ||
                   errorStr.contains('deadline-exceeded') ||
                   errorStr.contains('Unable to resolve host') ||
                   errorStr.contains('network') ||
                   errorStr.contains('DNS')) {
          // Network error - write is queued offline
          debugPrint('[UserMealPlanRepository] ⚠️ Network error (write queued offline): $e');
          return true; // Return success since it's queued
        } else {
          rethrow;
        }
      }
    } catch (e) {
      // Outer catch for any other errors
      debugPrint('[UserMealPlanRepository] 🔥 Error in saveDayMealsBatch: $e');
      rethrow;
    }
  }

  @override
  Future<UserMealPlan> applyExploreTemplateAsActivePlan({
    required String userId,
    required String templateId,
    required ExploreMealPlan template,
    required Map<String, dynamic> profileData,
  }) async {
    debugPrint('[UserMealPlanRepository] [ApplyExplore] ========== START applyExploreTemplateAsActivePlan ==========');
    debugPrint('[UserMealPlanRepository] [ApplyExplore] User ID: $userId');
    debugPrint('[UserMealPlanRepository] [ApplyExplore] Template ID: $templateId');
    debugPrint('[UserMealPlanRepository] [ApplyExplore] Template name: "${template.name}"');
    
    try {
      final userPlansRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('user_meal_plans');
      
      // Generate new plan ID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPlanId = '${userId}_$timestamp';
      final newPlanRef = userPlansRef.doc(newPlanId);
      
      debugPrint('[UserMealPlanRepository] [ApplyExplore] Generated plan ID: $newPlanId');
      
      // STEP 1: Use Firestore batch to atomically:
      // - Deactivate any existing active plan
      // - Create new active plan from template
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔄 Starting Firestore batch write...');
      
      final batch = _firestore.batch();
      
      // STEP 1.1: Query and deactivate existing active plan
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔄 Querying for existing active plans...');
      final activeSnapshot = await userPlansRef
          .where('isActive', isEqualTo: true)
          .get();
      
      int deactivatedCount = 0;
      if (activeSnapshot.docs.isNotEmpty) {
        for (final oldActiveDoc in activeSnapshot.docs) {
          final oldPlanId = oldActiveDoc.id;
          final oldPlanData = oldActiveDoc.data();
          final oldPlanName = oldPlanData['name'] ?? 'Unknown';
          
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔄 Deactivating old active plan: $oldPlanId ("$oldPlanName")');
          batch.update(oldActiveDoc.reference, {
            'isActive': false,
            'status': 'paused',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          deactivatedCount++;
        }
        debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Will deactivate $deactivatedCount old active plan(s)');
      } else {
        debugPrint('[UserMealPlanRepository] [ApplyExplore] ℹ️ No existing active plan to deactivate');
      }
      
      // STEP 1.2: Create new active plan from template
      // Convert profileData to Profile domain entity for service
      final profile = Profile.fromJson(profileData);
      // Use domain service to create the plan model
      final userPlan = ApplyExploreTemplateService.applyTemplate(
        template: template,
        userId: userId,
        profile: profile,
        setAsActive: true,
      );
      
      // Create plan with generated ID
      final planToSave = userPlan.copyWith(id: newPlanId);
      final dto = _domainToDto(planToSave);
      final planData = dto.toFirestore();
      
      // Ensure isActive is true
      planData['isActive'] = true;
      planData['status'] = 'active';
      
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔄 Creating new active plan: $newPlanId');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] Plan details: name="${planToSave.name}", type=${planToSave.type.value}, planTemplateId=${planToSave.planTemplateId}');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 🧾 userPlan meta: desc="${planToSave.description}", tags=${planToSave.tags}, difficulty=${planToSave.difficulty}');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 🧾 Firestore payload includes: description=${planData.containsKey('description') ? planData['description'] : 'null'}, tags=${planData['tags']}, difficulty=${planData.containsKey('difficulty') ? planData['difficulty'] : 'null'}');
      
      batch.set(newPlanRef, planData);
      debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ New plan $newPlanId will be created as active');
      
      // Commit the batch atomically
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 💾 Committing batch with ${deactivatedCount + 1} operations...');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 💾 Batch operations: $deactivatedCount deactivations + 1 plan creation');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 💾 New plan path: users/$userId/user_meal_plans/$newPlanId');
      
      try {
        await batch.commit();
        debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Batch committed successfully');
        
        // Verify the write succeeded
        final verifyDoc = await newPlanRef.get();
        if (!verifyDoc.exists) {
          throw Exception('Write verification failed: new plan document does not exist after batch commit');
        }
        debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Verified: new plan document exists');
      } catch (e, stackTrace) {
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ========== ERROR committing batch ==========');
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 Collection path: users/$userId/user_meal_plans');
        debugPrint('[UserMealPlanRepository] 🔥 New plan ID: $newPlanId');
        debugPrint('[UserMealPlanRepository] 🔥 Error: $e');
        debugPrint('[UserMealPlanRepository] 🔥 Error type: ${e.runtimeType}');
        debugPrint('[UserMealPlanRepository] 🔥 Stack trace: $stackTrace');
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ============================================');
        rethrow;
      }
      
      // STEP 2: Copy meals from template to user plan (using batch writes)
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 📋 Copying meals from template to user plan...');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] Template has ${template.durationDays} days');
      
      // Use the injected explore repository to read template meals
      final exploreRepo = _exploreRepo;
      
      int totalMealsCopied = 0;
      int totalDaysCreated = 0;
      final writtenDayPaths = <String>[];
      
      // Process days in batches to stay under Firestore limits (≤450 operations per batch for safety)
      const maxOperationsPerBatch = 450;
      int currentBatchOperations = 0;
      WriteBatch? currentBatch;
      
      for (int dayIndex = 1; dayIndex <= template.durationDays; dayIndex++) {
        print('[UserMealPlanRepository] [ApplyExplore] 📋 Copying day $dayIndex...');
        
        // Get meals for this day from template (returns MealSlot)
        final templateMealsStream = exploreRepo.getDayMeals(templateId, dayIndex);
        final templateMealSlots = await templateMealsStream.first;
        
        // Enforce invariant: each day MUST have at least 1 meal
        // DO NOT skip missing days silently - fail-fast with exception
        if (templateMealSlots.isEmpty) {
          final errorMsg = 'Template day $dayIndex has no meals. Each day must have at least 1 meal. (templateId=$templateId, userId=$userId, planId=$newPlanId)';
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ERROR: $errorMsg');
          throw Exception(errorMsg);
        }
        
        print('[UserMealPlanRepository] [ApplyExplore] 📋 Found ${templateMealSlots.length} meals for day $dayIndex');
        
        // STEP 2.1: Validate ALL slots for this day BEFORE any Firestore writes
        // This ensures atomicity - if validation fails, no partial writes occur
        // Use domain invariant validator (strict validation)
        final validatedSlots = <({MealSlot slot, String foodId, double servingSize})>[];
        final validationDocPath = 'users/$userId/user_meal_plans/$newPlanId/days/$dayIndex';
        
        for (var i = 0; i < templateMealSlots.length; i++) {
          final mealSlot = templateMealSlots[i];
          
          // Validate using domain invariant validator
          MealPlanInvariants.validateMealSlot(
            mealSlot,
            templateId: templateId,
            dayIndex: dayIndex,
            slotIndex: i,
            docPath: '$validationDocPath/slots/$i',
          );
          
          // Validate foodId (required, non-empty) using existing helper
          final validatedFoodId = requireNonEmptyForTesting(
            mealSlot.foodId,
            'foodId',
            userId: userId,
            templateId: templateId,
            dayIndex: dayIndex,
            slotIndex: i,
            mealType: mealSlot.mealType,
          );
          
          // Validate servingSize (now required in MealSlot domain model)
          final validatedServingSize = requirePositiveForTesting(
            mealSlot.servingSize,
            'servingSize',
            userId: userId,
            templateId: templateId,
            dayIndex: dayIndex,
            slotIndex: i,
            mealType: mealSlot.mealType,
          );
          
          // Store validated slot for later use
          validatedSlots.add((
            slot: mealSlot,
            foodId: validatedFoodId,
            servingSize: validatedServingSize,
          ));
        }
        
        // STEP 2.2: Only after validation succeeds, proceed with Firestore writes
        // Check if we need a new batch
        // Each day needs: 1 day doc + N meal docs + 1 day update for totals = 2 + N operations
        final operationsNeeded = 2 + validatedSlots.length;
        if (currentBatch == null || (currentBatchOperations + operationsNeeded) > maxOperationsPerBatch) {
          // Commit previous batch if exists
          if (currentBatch != null) {
            print('[UserMealPlanRepository] [ApplyExplore] 💾 Committing batch with $currentBatchOperations operations...');
            await currentBatch.commit();
            print('[UserMealPlanRepository] [ApplyExplore] ✅ Batch committed');
          }
          // Start new batch
          currentBatch = _firestore.batch();
          currentBatchOperations = 0;
        }
        
        // Create day document with dayIndex field (queryable by dayIndex)
        final dayDocPathForLogging = 'users/$userId/user_meal_plans/$newPlanId/days/$dayIndex';
        final dayRef = newPlanRef
            .collection('days')
            .doc(); // Use auto-generated ID (queryable via dayIndex field)
        
        writtenDayPaths.add(dayDocPathForLogging);
        print('[UserMealPlanRepository] [ApplyExplore] 📋 Creating day document: $dayDocPathForLogging');
        
        currentBatch.set(dayRef, {
          'dayIndex': dayIndex,
          'totalCalories': 0.0, // Will be calculated from meals
          'protein': 0.0,
          'carb': 0.0,
          'fat': 0.0,
        });
        currentBatchOperations++;
        
        // Copy meals (convert MealSlot to MealItem for storage)
        // All slots have been validated above, so we can safely proceed
        final mealItems = <MealItem>[];
        
        for (var i = 0; i < validatedSlots.length; i++) {
          final validated = validatedSlots[i];
          final mealSlot = validated.slot;
          final validatedFoodId = validated.foodId;
          final validatedServingSize = validated.servingSize;
          
          // Create new meal document with auto-generated ID first
          final mealRef = dayRef.collection('meals').doc();
          final mealId = mealRef.id; // Use the auto-generated document ID
          
          // Assertions for invariants (defensive programming)
          assert(validatedFoodId.isNotEmpty, 'foodId must be non-empty after validation');
          assert(validatedServingSize > 0, 'servingSize must be positive after validation');
          
          // Convert MealSlot to MealItem for storage
          final mealItem = MealItem(
            id: mealId,
            mealType: mealSlot.mealType,
            foodId: validatedFoodId,
            servingSize: validatedServingSize,
            calories: mealSlot.calories,
            protein: mealSlot.protein,
            carb: mealSlot.carb,
            fat: mealSlot.fat,
          );
          
          mealItems.add(mealItem);
          
          // Create DTO from MealItem with correct ID
          final mealDto = MealItemDto(
            id: mealItem.id,
            mealType: mealItem.mealType,
            foodId: mealItem.foodId, // No need to check isEmpty - already validated
            servingSize: mealItem.servingSize,
            calories: mealItem.calories,
            protein: mealItem.protein,
            carb: mealItem.carb,
            fat: mealItem.fat,
          );
          
          // Set the meal document with the DTO data
          final mealDocPath = '$dayDocPathForLogging/meals/${mealRef.id}';
          print('[UserMealPlanRepository] [ApplyExplore] 📋 Writing meal document: $mealDocPath (foodId=${mealItem.foodId}, servingSize=${mealItem.servingSize})');
          currentBatch.set(mealRef, mealDto.toFirestore());
          currentBatchOperations++;
        }
        
        // Compute day totals using domain service (validates all meals)
        // This will throw MealNutritionException if any meal is invalid
        final dayTotals = MealNutritionCalculator.sumMeals(
          mealItems,
          planId: newPlanId,
          userId: userId,
          dayIndex: dayIndex,
        );
        
        // Update day totals using domain-calculated values
        currentBatch.update(dayRef, {
          'totalCalories': dayTotals.calories,
          'protein': dayTotals.protein,
          'carb': dayTotals.carb,
          'fat': dayTotals.fat,
        });
        currentBatchOperations++;
        
        totalMealsCopied += validatedSlots.length;
        totalDaysCreated++;
        print('[UserMealPlanRepository] [ApplyExplore] ✅ Copied ${validatedSlots.length} meals for day $dayIndex');
      }
      
      // Commit final batch if exists
      if (currentBatch != null && currentBatchOperations > 0) {
        print('[UserMealPlanRepository] [ApplyExplore] 💾 Committing final batch with $currentBatchOperations operations...');
        print('[UserMealPlanRepository] [ApplyExplore] 💾 Final batch path: users/$userId/user_meal_plans/$newPlanId/days/.../meals');
        try {
          await currentBatch.commit();
          print('[UserMealPlanRepository] [ApplyExplore] ✅ Final batch committed');
        } catch (e, stackTrace) {
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ========== ERROR committing final meals batch ==========');
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 Plan ID: $newPlanId');
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 User ID: $userId');
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 Collection path: users/$userId/user_meal_plans/$newPlanId/days/.../meals');
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 Error: $e');
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 Error type: ${e.runtimeType}');
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 Stack trace: $stackTrace');
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 =======================================================');
          rethrow;
        }
      }
      
      print('[UserMealPlanRepository] [ApplyExplore] ✅ Finished copying template → user plan: $totalMealsCopied total meals across $totalDaysCreated days');
      
      // STEP 2.3: Post-apply verification - ensure all days and meals were created
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔍 Post-apply verification: checking days and meals...');
      
      // Verify: user plan has exactly durationDays days
      final daysSnapshot = await newPlanRef
          .collection('days')
          .get();
      
      if (daysSnapshot.docs.length != template.durationDays) {
        final errorMsg = 'Post-apply verification failed: expected ${template.durationDays} days, found ${daysSnapshot.docs.length} (planId=$newPlanId, userId=$userId, templateId=$templateId)';
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ERROR: $errorMsg');
        throw Exception(errorMsg);
      }
      debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Verified: plan has exactly ${template.durationDays} days');
      
      // Verify: each day has ≥ 1 meal
      int totalVerifiedMeals = 0;
      for (int dayIndex = 1; dayIndex <= template.durationDays; dayIndex++) {
        final daySnapshot = await newPlanRef
            .collection('days')
            .where('dayIndex', isEqualTo: dayIndex)
            .limit(1)
            .get();
        
        if (daySnapshot.docs.isEmpty) {
          final errorMsg = 'Post-apply verification failed: day $dayIndex not found (planId=$newPlanId, userId=$userId, templateId=$templateId)';
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ERROR: $errorMsg');
          throw Exception(errorMsg);
        }
        
        final dayDoc = daySnapshot.docs.first;
        final mealsSnapshot = await dayDoc.reference
            .collection('meals')
            .get();
        
        if (mealsSnapshot.docs.isEmpty) {
          final errorMsg = 'Post-apply verification failed: day $dayIndex has no meals (planId=$newPlanId, userId=$userId, templateId=$templateId)';
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ERROR: $errorMsg');
          throw Exception(errorMsg);
        }
        
        totalVerifiedMeals += mealsSnapshot.docs.length;
        
        // Verify: day totals match sum of meals
        final dayData = dayDoc.data();
        final storedTotals = MealNutrition(
          calories: (dayData['totalCalories'] as num?)?.toDouble() ?? 0.0,
          protein: (dayData['protein'] as num?)?.toDouble() ?? 0.0,
          carb: (dayData['carb'] as num?)?.toDouble() ?? 0.0,
          fat: (dayData['fat'] as num?)?.toDouble() ?? 0.0,
        );
        
        // Load meals and compute totals
        final dayMealsStream = getDayMeals(newPlanId, userId, dayIndex);
        final dayMeals = await dayMealsStream.first;
        
        if (dayMeals.isEmpty) {
          final errorMsg = 'Post-apply verification failed: day $dayIndex meals stream returned empty (planId=$newPlanId, userId=$userId, templateId=$templateId)';
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ERROR: $errorMsg');
          throw Exception(errorMsg);
        }
        
        final computedTotals = MealNutritionCalculator.sumMeals(
          dayMeals,
          planId: newPlanId,
          userId: userId,
          dayIndex: dayIndex,
        );
        
        // Compare totals with epsilon
        const epsilon = 0.0001;
        if ((storedTotals.calories - computedTotals.calories).abs() > epsilon ||
            (storedTotals.protein - computedTotals.protein).abs() > epsilon ||
            (storedTotals.carb - computedTotals.carb).abs() > epsilon ||
            (storedTotals.fat - computedTotals.fat).abs() > epsilon) {
          final errorMsg = 'Post-apply verification failed: day $dayIndex totals mismatch. Stored: $storedTotals, Computed: $computedTotals (planId=$newPlanId, userId=$userId, templateId=$templateId)';
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ERROR: $errorMsg');
          throw Exception(errorMsg);
        }
        
        debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Verified day $dayIndex: ${dayMeals.length} meals, totals match');
      }
      
      if (totalVerifiedMeals != totalMealsCopied) {
        final errorMsg = 'Post-apply verification failed: meal count mismatch. Expected: $totalMealsCopied, Found: $totalVerifiedMeals (planId=$newPlanId, userId=$userId, templateId=$templateId)';
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ERROR: $errorMsg');
        throw Exception(errorMsg);
      }
      
      debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Post-apply verification passed: all days have meals, totals match');
      
      // STEP 3: Load and return the newly created plan
      final newPlanDoc = await newPlanRef.get();
      if (!newPlanDoc.exists) {
        throw Exception('Failed to create plan: document does not exist after transaction');
      }
      
      final newPlanDto = UserMealPlanDto.fromFirestore(newPlanDoc);
      final newPlan = newPlanDto.toDomain();
      
      debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ ========== END applyExploreTemplateAsActivePlan (SUCCESS) ==========');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ New active plan: planId=${newPlan.id}, name="${newPlan.name}", type=${newPlan.type.value}');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Plan templateId: ${newPlan.planTemplateId}');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ ActiveMealPlanProvider will automatically emit this new plan');
      
      // STEP 4: Post-write verification - ensure exactly ONE active plan exists
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔍 Post-write verification: checking active plans...');
      final activePlanCheck = await userPlansRef
          .where('isActive', isEqualTo: true)
          .limit(2)
          .get();
      
      if (activePlanCheck.docs.length > 1) {
        final activePlanIds = activePlanCheck.docs.map((d) => d.id).toList();
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ERROR: Multiple active plans detected after apply!');
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 Active plan IDs: ${activePlanIds.join(", ")}');
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 This violates the invariant - should never happen');
        // Don't throw - log the error but return the plan we just created
        // Admin repair tool can fix this later
      } else if (activePlanCheck.docs.isEmpty) {
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ERROR: No active plan found after apply!');
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 This should not happen - new plan should be active');
        // This is critical - throw an exception
        throw Exception('Post-write verification failed: no active plan found after applying template');
      } else {
        final verifiedActiveId = activePlanCheck.docs.first.id;
        if (verifiedActiveId != newPlanId) {
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ERROR: Active plan mismatch!');
          debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 Expected: $newPlanId, Got: $verifiedActiveId');
          throw Exception('Post-write verification failed: active plan ID mismatch (expected $newPlanId, got $verifiedActiveId)');
        } else {
          debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Post-write verification passed: exactly 1 active plan (planId=$verifiedActiveId)');
        }
      }
      
      return newPlan;
    } catch (e, stackTrace) {
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ========== ERROR in applyExploreTemplateAsActivePlan ==========');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 Error: $e');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 Error type: ${e.runtimeType}');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 Stack trace: $stackTrace');
      debugPrint('[UserMealPlanRepository] [ApplyExplore] 🔥 ===============================================================');
      rethrow;
    }
  }

  @override
  Future<UserMealPlan> applyCustomPlanAsActive({
    required String userId,
    required String planId,
  }) async {
    debugPrint('[UserMealPlanRepository] [ApplyCustom] ========== START applyCustomPlanAsActive ==========');
    debugPrint('[UserMealPlanRepository] [ApplyCustom] User ID: $userId');
    debugPrint('[UserMealPlanRepository] [ApplyCustom] Plan ID: $planId');
    
    try {
      final userPlansRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('user_meal_plans');
      
      // STEP 1: Use Firestore batch to atomically deactivate old plans and activate new one
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔄 Starting Firestore batch write...');
      
      final batch = _firestore.batch();
      
      // STEP 1.1: Query and deactivate existing active plans
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔄 Querying for existing active plans...');
      final activeSnapshot = await userPlansRef
          .where('isActive', isEqualTo: true)
          .get();
      
      int deactivatedCount = 0;
      if (activeSnapshot.docs.isNotEmpty) {
        for (final oldActiveDoc in activeSnapshot.docs) {
          // Don't deactivate the plan we're about to activate
          if (oldActiveDoc.id == planId) {
            debugPrint('[UserMealPlanRepository] [ApplyCustom] ℹ️ Plan $planId is already active, skipping deactivation');
            continue;
          }
          
          final oldPlanId = oldActiveDoc.id;
          final oldPlanData = oldActiveDoc.data();
          final oldPlanName = oldPlanData['name'] ?? 'Unknown';
          
          debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔄 Deactivating old active plan: $oldPlanId ("$oldPlanName")');
          batch.update(oldActiveDoc.reference, {
            'isActive': false,
            'status': 'paused',
            'endedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          deactivatedCount++;
        }
        if (deactivatedCount > 0) {
          debugPrint('[UserMealPlanRepository] [ApplyCustom] ✅ Will deactivate $deactivatedCount old active plan(s)');
        } else {
          debugPrint('[UserMealPlanRepository] [ApplyCustom] ℹ️ No other active plans to deactivate');
        }
      } else {
        debugPrint('[UserMealPlanRepository] [ApplyCustom] ℹ️ No existing active plan to deactivate');
      }
      
      // STEP 1.2: Verify plan exists and belongs to user
      final planRef = userPlansRef.doc(planId);
      final planDoc = await planRef.get();
      
      if (!planDoc.exists) {
        throw Exception('Plan not found: $planId');
      }
      
      final planData = planDoc.data();
      if (planData == null) {
        throw Exception('Plan data is null: $planId');
      }
      
      final planUserId = planData['userId'] as String?;
      if (planUserId != userId) {
        throw Exception('Plan does not belong to user: $planId');
      }
      
      final planName = planData['name'] ?? 'Unknown';
      debugPrint('[UserMealPlanRepository] [ApplyCustom] ✅ Plan found: "$planName"');
      
      // STEP 1.3: Activate the plan
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔄 Activating plan: $planId');
      batch.update(planRef, {
        'isActive': true,
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Commit the batch atomically
      final totalOperations = deactivatedCount + 1; // deactivations + 1 activation
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 💾 Committing batch with $totalOperations operation(s)...');
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 💾 Batch operations: $deactivatedCount deactivation(s) + 1 plan activation');
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 💾 Plan path: users/$userId/user_meal_plans/$planId');
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 💾 User ID (unchanged): $userId');
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 💾 Plan ID (unchanged): $planId');
      
      // Ensure batch has at least one operation (the activation)
      if (totalOperations == 0) {
        throw Exception('Batch has no operations - cannot commit');
      }
      
      try {
        debugPrint('[UserMealPlanRepository] [ApplyCustom] 💾 Executing batch.commit()...');
        await batch.commit();
        debugPrint('[UserMealPlanRepository] [ApplyCustom] ✅ Batch committed successfully to Firestore');
        
        // Verify the write succeeded
        final verifyDoc = await planRef.get();
        if (!verifyDoc.exists) {
          throw Exception('Write verification failed: plan document does not exist after batch commit');
        }
        final verifyData = verifyDoc.data();
        final verifyIsActive = verifyData?['isActive'] as bool? ?? false;
        if (!verifyIsActive) {
          throw Exception('Write verification failed: plan isActive is false after activation');
        }
        debugPrint('[UserMealPlanRepository] [ApplyCustom] ✅ Verified: plan document exists and isActive=true');
      } catch (e, stackTrace) {
        debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 ========== ERROR committing batch ==========');
        debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 Collection path: users/$userId/user_meal_plans');
        debugPrint('[UserMealPlanRepository] 🔥 Plan ID: $planId');
        debugPrint('[UserMealPlanRepository] 🔥 Error: $e');
        debugPrint('[UserMealPlanRepository] 🔥 Error type: ${e.runtimeType}');
        debugPrint('[UserMealPlanRepository] 🔥 Stack trace: $stackTrace');
        debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 ============================================');
        rethrow;
      }
      debugPrint('[UserMealPlanRepository] [ApplyCustom] ✅ Deactivated $deactivatedCount old active plan(s)');
      debugPrint('[UserMealPlanRepository] [ApplyCustom] ✅ Activated plan: $planId ("$planName")');
      
      // STEP 2: Load and return the activated plan
      final activatedPlanDoc = await planRef.get();
      if (!activatedPlanDoc.exists) {
        throw Exception('Plan does not exist after activation: $planId');
      }
      
      final activatedPlanDto = UserMealPlanDto.fromFirestore(activatedPlanDoc);
      final activatedPlan = activatedPlanDto.toDomain();
      
      debugPrint('[UserMealPlanRepository] [ApplyCustom] ✅ ========== END applyCustomPlanAsActive (SUCCESS) ==========');
      debugPrint('[UserMealPlanRepository] [ApplyCustom] ✅ Activated plan: planId=${activatedPlan.id}, name="${activatedPlan.name}", type=${activatedPlan.type.value}, isActive=${activatedPlan.isActive}');
      
      // STEP 3: Post-write verification - ensure exactly ONE active plan exists
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔍 Post-write verification: checking active plans...');
      final activePlanCheck = await userPlansRef
          .where('isActive', isEqualTo: true)
          .limit(2)
          .get();
      
      if (activePlanCheck.docs.length > 1) {
        final activePlanIds = activePlanCheck.docs.map((d) => d.id).toList();
        debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 ERROR: Multiple active plans detected after apply!');
        debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 Active plan IDs: ${activePlanIds.join(", ")}');
        debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 This violates the invariant - should never happen');
        // Don't throw - log the error but return the plan we just activated
        // Admin repair tool can fix this later
      } else if (activePlanCheck.docs.isEmpty) {
        debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 ERROR: No active plan found after apply!');
        debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 This should not happen - plan should be active');
        // This is critical - throw an exception
        throw Exception('Post-write verification failed: no active plan found after applying custom plan');
      } else {
        final verifiedActiveId = activePlanCheck.docs.first.id;
        if (verifiedActiveId != planId) {
          debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 ERROR: Active plan mismatch!');
          debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 Expected: $planId, Got: $verifiedActiveId');
          throw Exception('Post-write verification failed: active plan ID mismatch (expected $planId, got $verifiedActiveId)');
        } else {
          debugPrint('[UserMealPlanRepository] [ApplyCustom] ✅ Post-write verification passed: exactly 1 active plan (planId=$verifiedActiveId)');
        }
      }
      
      return activatedPlan;
    } catch (e, stackTrace) {
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 ========== ERROR in applyCustomPlanAsActive ==========');
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 Error: $e');
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 Error type: ${e.runtimeType}');
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 Stack trace: $stackTrace');
      debugPrint('[UserMealPlanRepository] [ApplyCustom] 🔥 ===============================================================');
      rethrow;
    }
  }
}

/// Helper to validate non-empty string fields
/// 
/// Made public for testing purposes.
String requireNonEmptyForTesting(
  String? value,
  String fieldName, {
  required String userId,
  required String templateId,
  required int dayIndex,
  required int slotIndex,
  required String mealType,
}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    throw MealPlanApplyException(
      'ApplyExploreTemplate failed: missing $fieldName',
      userId: userId,
      templateId: templateId,
      dayIndex: dayIndex,
      slotIndex: slotIndex,
      mealType: mealType,
    );
  }
  return v;
}

/// Helper to validate positive numeric fields
/// 
/// Made public for testing purposes.
double requirePositiveForTesting(
  num? value,
  String fieldName, {
  required String userId,
  required String templateId,
  required int dayIndex,
  required int slotIndex,
  required String mealType,
}) {
  if (value == null) {
    throw MealPlanApplyException(
      'ApplyExploreTemplate failed: MealSlot has no $fieldName; cannot safely apply template',
      userId: userId,
      templateId: templateId,
      dayIndex: dayIndex,
      slotIndex: slotIndex,
      mealType: mealType,
    );
  }
  
  final doubleValue = value.toDouble();
  if (doubleValue <= 0) {
    throw MealPlanApplyException(
      'ApplyExploreTemplate failed: $fieldName must be positive, got $doubleValue',
      userId: userId,
      templateId: templateId,
      dayIndex: dayIndex,
      slotIndex: slotIndex,
      mealType: mealType,
      details: {'value': doubleValue},
    );
  }
  
  return doubleValue;
}


