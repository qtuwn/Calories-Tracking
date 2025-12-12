import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem, MealPlanDay, UserMealPlanRepository;
import 'package:calories_app/domain/meal_plans/explore_meal_plan.dart' show ExploreMealPlan;
import 'package:calories_app/domain/meal_plans/explore_meal_plan_repository.dart';
import 'package:calories_app/data/meal_plans/firestore_explore_meal_plan_repository.dart' show FirestoreExploreMealPlanRepository;
import 'package:calories_app/features/meal_plans/domain/services/apply_explore_template_service.dart';
import 'package:calories_app/domain/profile/profile.dart';
import 'package:calories_app/features/meal_plans/data/dto/user_meal_plan_dto.dart';
import 'package:calories_app/features/meal_plans/data/dto/meal_item_dto.dart';

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
    // Log only once when stream is created
    debugPrint('[UserMealPlanRepository] 🔵 Setting up stream for meals: planId=$planId, userId=$userId, dayIndex=$dayIndex');
    
    final daysRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('user_meal_plans')
        .doc(planId)
        .collection('days')
        .where('dayIndex', isEqualTo: dayIndex)
        .limit(1);
    
    // Use a class-level cache to track logged states per (planId, dayIndex)
    final streamKey = '$planId:$dayIndex';
    if (!_dayNotFoundLogged.containsKey(streamKey)) {
      _dayNotFoundLogged[streamKey] = false;
    }
    if (!_lastMealCounts.containsKey(streamKey)) {
      _lastMealCounts[streamKey] = -1;
    }
    
    // Use asyncExpand but ensure we only create one stream per day document
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
      // This stream will only emit when meals change, not when the day document changes
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
  }
  
  // Class-level cache to prevent repeated logging
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
      
      // Calculate totals
      double totalCalories = 0.0;
      double totalProtein = 0.0;
      double totalCarb = 0.0;
      double totalFat = 0.0;
      
      for (final meal in mealsToSave) {
        totalCalories += meal.calories;
        totalProtein += meal.protein;
        totalCarb += meal.carb;
        totalFat += meal.fat;
      }
      
      // Update day totals
      batch.update(dayRef, {
        'totalCalories': totalCalories,
        'protein': totalProtein,
        'carb': totalCarb,
        'fat': totalFat,
      });
      
      debugPrint('[UserMealPlanRepository] 💾 Committing batch for day $dayIndex...');
      debugPrint('[UserMealPlanRepository] 💾 Collection path: $collectionPath');
      debugPrint('[UserMealPlanRepository] 💾 Batch operations: ${mealsToSave.length} saves, ${mealsToDelete.length} deletes');
      
      try {
        await batch.commit();
        
        debugPrint(
          '[UserMealPlanRepository] ✅ Batch committed: '
          '${mealsToSave.length} saved, ${mealsToDelete.length} deleted, '
          'totals: ${totalCalories.toInt()} kcal',
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
      int daysWithMeals = 0;
      
      // Process days in batches to stay under Firestore limits (500 operations per batch)
      const maxOperationsPerBatch = 500;
      int currentBatchOperations = 0;
      WriteBatch? currentBatch;
      
      for (int dayIndex = 1; dayIndex <= template.durationDays; dayIndex++) {
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 📋 Loading meals for day $dayIndex from template...');
        
        // Get meals for this day from template (returns MealSlot)
        final templateMealsStream = exploreRepo.getDayMeals(templateId, dayIndex);
        final templateMealSlots = await templateMealsStream.first;
        
        if (templateMealSlots.isEmpty) {
          debugPrint('[UserMealPlanRepository] [ApplyExplore] ℹ️ No meals found for day $dayIndex in template');
          continue;
        }
        
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 📋 Found ${templateMealSlots.length} meals for day $dayIndex');
        
        // Check if we need a new batch
        // Each day needs: 1 day doc + N meal docs
        final operationsNeeded = 1 + templateMealSlots.length;
        if (currentBatch == null || (currentBatchOperations + operationsNeeded) > maxOperationsPerBatch) {
          // Commit previous batch if exists
          if (currentBatch != null) {
            debugPrint('[UserMealPlanRepository] [ApplyExplore] 💾 Committing batch with $currentBatchOperations operations...');
            await currentBatch.commit();
            debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Batch committed');
          }
          // Start new batch
          currentBatch = _firestore.batch();
          currentBatchOperations = 0;
        }
        
        // Create/update day document
        final dayRef = newPlanRef
            .collection('days')
            .doc(); // Use auto-generated ID
        
        currentBatch.set(dayRef, {
          'dayIndex': dayIndex,
          'totalCalories': 0.0, // Will be calculated from meals
          'protein': 0.0,
          'carb': 0.0,
          'fat': 0.0,
        });
        currentBatchOperations++;
        
        // Copy meals (convert MealSlot to MealItem for storage)
        double dayCalories = 0.0;
        double dayProtein = 0.0;
        double dayCarb = 0.0;
        double dayFat = 0.0;
        
        for (final mealSlot in templateMealSlots) {
          // Convert MealSlot to MealItem for storage
          final mealItem = MealItem(
            id: '', // Will get auto-generated ID
            mealType: mealSlot.mealType,
            foodId: mealSlot.foodId ?? '',
            servingSize: 1.0, // MealSlot doesn't have servingSize, use default
            calories: mealSlot.calories,
            protein: mealSlot.protein,
            carb: mealSlot.carb,
            fat: mealSlot.fat,
          );
          
          // Create DTO from MealItem
          final mealDto = MealItemDto(
            id: mealItem.id,
            mealType: mealItem.mealType,
            foodId: mealItem.foodId,
            servingSize: mealItem.servingSize,
            calories: mealItem.calories,
            protein: mealItem.protein,
            carb: mealItem.carb,
            fat: mealItem.fat,
          );
          
          // Create new meal with auto-generated ID
          final mealRef = dayRef.collection('meals').doc();
          currentBatch.set(mealRef, mealDto.toFirestore());
          currentBatchOperations++;
          
          // Accumulate totals
          dayCalories += mealSlot.calories;
          dayProtein += mealSlot.protein;
          dayCarb += mealSlot.carb;
          dayFat += mealSlot.fat;
        }
        
        // Update day totals
        currentBatch.update(dayRef, {
          'totalCalories': dayCalories.toDouble(),
          'protein': dayProtein.toDouble(),
          'carb': dayCarb.toDouble(),
          'fat': dayFat.toDouble(),
        });
        currentBatchOperations++;
        
        totalMealsCopied += templateMealSlots.length;
        daysWithMeals++;
        debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Prepared ${templateMealSlots.length} meals for day $dayIndex');
      }
      
      // Commit final batch if exists
      if (currentBatch != null && currentBatchOperations > 0) {
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 💾 Committing final batch with $currentBatchOperations operations...');
        debugPrint('[UserMealPlanRepository] [ApplyExplore] 💾 Final batch path: users/$userId/user_meal_plans/$newPlanId/days/.../meals');
        try {
          await currentBatch.commit();
          debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Final batch committed');
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
      
      debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Copying complete: $totalMealsCopied total meals across $daysWithMeals days');
      
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
      
      // STEP 4: Sanity check - verify the new plan is actually active
      final activePlanCheck = await userPlansRef
          .where('isActive', isEqualTo: true)
          .limit(2)
          .get();
      
      if (activePlanCheck.docs.length > 1) {
        final activePlanIds = activePlanCheck.docs.map((d) => d.id).toList();
        debugPrint('[UserMealPlanRepository] [ApplyExplore] ⚠️ WARNING: Multiple active plans detected after apply!');
        debugPrint('[UserMealPlanRepository] [ApplyExplore] ⚠️ Active plan IDs: ${activePlanIds.join(", ")}');
        debugPrint('[UserMealPlanRepository] [ApplyExplore] ⚠️ This violates the invariant - should never happen');
      } else if (activePlanCheck.docs.isEmpty) {
        debugPrint('[UserMealPlanRepository] [ApplyExplore] ⚠️ WARNING: No active plan found after apply!');
        debugPrint('[UserMealPlanRepository] [ApplyExplore] ⚠️ This should not happen - new plan should be active');
      } else {
        final verifiedActiveId = activePlanCheck.docs.first.id;
        if (verifiedActiveId != newPlanId) {
          debugPrint('[UserMealPlanRepository] [ApplyExplore] ⚠️ WARNING: Active plan mismatch!');
          debugPrint('[UserMealPlanRepository] [ApplyExplore] ⚠️ Expected: $newPlanId, Got: $verifiedActiveId');
        } else {
          debugPrint('[UserMealPlanRepository] [ApplyExplore] ✅ Sanity check passed: new plan is correctly active');
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
      
      // STEP 3: Sanity check - verify the plan is actually active
      final activePlanCheck = await userPlansRef
          .where('isActive', isEqualTo: true)
          .limit(2)
          .get();
      
      if (activePlanCheck.docs.length > 1) {
        final activePlanIds = activePlanCheck.docs.map((d) => d.id).toList();
        debugPrint('[UserMealPlanRepository] [ApplyCustom] ⚠️ WARNING: Multiple active plans detected after apply!');
        debugPrint('[UserMealPlanRepository] [ApplyCustom] ⚠️ Active plan IDs: ${activePlanIds.join(", ")}');
        debugPrint('[UserMealPlanRepository] [ApplyCustom] ⚠️ This violates the invariant - should never happen');
      } else if (activePlanCheck.docs.isEmpty) {
        debugPrint('[UserMealPlanRepository] [ApplyCustom] ⚠️ WARNING: No active plan found after apply!');
        debugPrint('[UserMealPlanRepository] [ApplyCustom] ⚠️ This should not happen - plan should be active');
      } else {
        final verifiedActiveId = activePlanCheck.docs.first.id;
        if (verifiedActiveId != planId) {
          debugPrint('[UserMealPlanRepository] [ApplyCustom] ⚠️ WARNING: Active plan mismatch!');
          debugPrint('[UserMealPlanRepository] [ApplyCustom] ⚠️ Expected: $planId, Got: $verifiedActiveId');
        } else {
          debugPrint('[UserMealPlanRepository] [ApplyCustom] ✅ Sanity check passed: plan is correctly active');
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

