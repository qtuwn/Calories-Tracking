import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:calories_app/domain/meal_plans/services/meal_nutrition_calculator.dart'
    show MealNutritionCalculator, MealNutrition, MealNutritionException;
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart'
    show MealItem;
import '../domain/migration_exceptions.dart';
import '../domain/migration_report.dart';
import 'admin_audit_log_repository.dart';
import '../domain/admin_audit_log.dart';

/// Abstract interface for user plan consistency repair operations
abstract class UserPlanConsistencyRepairRepository {
  /// Repair day totals to match computed totals from meals
  /// 
  /// [dryRun] if true, calculates what would change without writing
  /// [epsilon] tolerance for floating point comparisons
  /// [limitUsers] optional limit on number of users to process
  /// [limitPlansPerUser] optional limit on number of plans per user
  /// [adminUserId] ID of the admin user running the operation (for audit log)
  Future<RepairReport> repairDayTotals({
    required bool dryRun,
    double epsilon = 0.0001,
    int? limitUsers,
    int? limitPlansPerUser,
    required String adminUserId,
  });
}

/// Firestore implementation of user plan consistency repair
class FirestoreUserPlanConsistencyRepairRepository
    implements UserPlanConsistencyRepairRepository {
  final FirebaseFirestore _firestore;
  final AdminAuditLogRepository? _auditRepo;

  FirestoreUserPlanConsistencyRepairRepository({
    FirebaseFirestore? instance,
    AdminAuditLogRepository? auditRepo,
  })  : _firestore = instance ?? FirebaseFirestore.instance,
        _auditRepo = auditRepo;

  @override
  Future<RepairReport> repairDayTotals({
    required bool dryRun,
    double epsilon = 0.0001,
    int? limitUsers,
    int? limitPlansPerUser,
    required String adminUserId,
  }) async {
    final startedAt = DateTime.now();
    
    debugPrint(
      '[UserPlanConsistencyRepair] 🔵 Starting day totals repair '
      '(dryRun=$dryRun, epsilon=$epsilon)',
    );

    int plansScanned = 0;
    int daysScanned = 0;
    int daysRepaired = 0;
    final repairedDocPaths = <String>[];
    final warnings = <String>[];

    try {
      // Query all users
      Query usersQuery = _firestore.collection('users');
      if (limitUsers != null) {
        usersQuery = usersQuery.limit(limitUsers);
      }

      final usersSnapshot = await usersQuery.get();

      WriteBatch? currentBatch;
      int batchOpCount = 0;
      const maxBatchOps = 450; // Safe headroom under Firestore's 500 limit

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;

        try {
          // Get all meal plans for this user
          Query plansQuery = userDoc.reference.collection('user_meal_plans');
          if (limitPlansPerUser != null) {
            plansQuery = plansQuery.limit(limitPlansPerUser);
          }

          final plansSnapshot = await plansQuery.get();

          for (final planDoc in plansSnapshot.docs) {
            final planId = planDoc.id;
            plansScanned++;

            try {
              // Get all days for this plan (query by dayIndex, not docId)
              final daysSnapshot = await planDoc.reference
                  .collection('days')
                  .get();

              for (final dayDoc in daysSnapshot.docs) {
                daysScanned++;

                try {
                  final dayData = dayDoc.data();
                  final dayPath = dayDoc.reference.path;

                  // Extract stored totals from day document
                  final storedCalories =
                      (dayData['totalCalories'] as num?)?.toDouble() ?? 0.0;
                  final storedProtein =
                      (dayData['protein'] as num?)?.toDouble() ?? 0.0;
                  final storedCarb = (dayData['carb'] as num?)?.toDouble() ?? 0.0;
                  final storedFat = (dayData['fat'] as num?)?.toDouble() ?? 0.0;

                  final storedTotals = MealNutrition(
                    calories: storedCalories,
                    protein: storedProtein,
                    carb: storedCarb,
                    fat: storedFat,
                  );

                  // Load all meals for this day
                  final mealsSnapshot =
                      await dayDoc.reference.collection('meals').get();

                  // Convert meals to domain MealItem objects
                  final meals = <MealItem>[];
                  for (final mealDoc in mealsSnapshot.docs) {
                    try {
                      final mealData = mealDoc.data();
                      final mealItem = MealItem(
                        id: mealDoc.id,
                        mealType: mealData['mealType'] as String? ?? 'breakfast',
                        foodId: mealData['foodId'] as String? ?? '',
                        servingSize:
                            (mealData['servingSize'] as num?)?.toDouble() ?? 1.0,
                        calories: (mealData['calories'] as num?)?.toDouble() ?? 0.0,
                        protein: (mealData['protein'] as num?)?.toDouble() ?? 0.0,
                        carb: (mealData['carb'] as num?)?.toDouble() ?? 0.0,
                        fat: (mealData['fat'] as num?)?.toDouble() ?? 0.0,
                      );

                      // Validate meal using domain service
                      MealNutritionCalculator.computeFromMealItem(
                        mealItem,
                        planId: planId,
                        userId: userId,
                        dayIndex: dayData['dayIndex'] as int?,
                      );

                      meals.add(mealItem);
                    } on MealNutritionException catch (e) {
                      // Invalid meal - add warning but continue
                      warnings.add(
                        'Invalid meal at ${mealDoc.reference.path}: $e',
                      );
                      debugPrint(
                        '[UserPlanConsistencyRepair] ⚠️ Invalid meal: ${mealDoc.reference.path}: $e',
                      );
                      continue;
                    } catch (e) {
                      warnings.add(
                        'Error parsing meal at ${mealDoc.reference.path}: $e',
                      );
                      debugPrint(
                        '[UserPlanConsistencyRepair] ⚠️ Error parsing meal: ${mealDoc.reference.path}: $e',
                      );
                      continue;
                    }
                  }

                  // Compute totals from meals using domain service
                  final computedTotals = MealNutritionCalculator.sumMeals(
                    meals,
                    planId: planId,
                    userId: userId,
                    dayIndex: dayData['dayIndex'] as int?,
                  );

                  // Check if totals match within epsilon
                  final needsRepair = (storedTotals.calories - computedTotals.calories)
                              .abs() >
                          epsilon ||
                      (storedTotals.protein - computedTotals.protein).abs() >
                          epsilon ||
                      (storedTotals.carb - computedTotals.carb).abs() > epsilon ||
                      (storedTotals.fat - computedTotals.fat).abs() > epsilon;

                  if (needsRepair) {
                    if (!dryRun) {
                      // Initialize batch if needed
                      if (currentBatch == null || batchOpCount >= maxBatchOps) {
                        if (currentBatch != null) {
                          await currentBatch.commit();
                          debugPrint(
                            '[UserPlanConsistencyRepair] ✅ Committed batch of $batchOpCount operations',
                          );
                        }
                        currentBatch = _firestore.batch();
                        batchOpCount = 0;
                      }

                      // Update day totals with computed values
                      currentBatch.update(dayDoc.reference, {
                        'totalCalories': computedTotals.calories,
                        'protein': computedTotals.protein,
                        'carb': computedTotals.carb,
                        'fat': computedTotals.fat,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      batchOpCount++;
                    }

                    daysRepaired++;
                    repairedDocPaths.add(dayPath);

                    debugPrint(
                      '[UserPlanConsistencyRepair] 📝 Will ${dryRun ? 'would' : ''} repair '
                      '$dayPath: stored=${storedTotals.calories.toInt()} kcal, '
                      'computed=${computedTotals.calories.toInt()} kcal',
                    );
                  }
                } catch (e) {
                  warnings.add('Error processing day at ${dayDoc.reference.path}: $e');
                  debugPrint(
                    '[UserPlanConsistencyRepair] ⚠️ Error processing day: ${dayDoc.reference.path}: $e',
                  );
                  continue;
                }
              }
            } catch (e) {
              warnings.add('Error processing plan $planId: $e');
              debugPrint(
                '[UserPlanConsistencyRepair] ⚠️ Error processing plan $planId: $e',
              );
              continue;
            }
          }
        } catch (e) {
          warnings.add('Error processing user $userId: $e');
          debugPrint(
            '[UserPlanConsistencyRepair] ⚠️ Error processing user $userId: $e',
          );
          continue;
        }
      }

      // Commit any remaining batch
      if (!dryRun && currentBatch != null && batchOpCount > 0) {
        await currentBatch.commit();
        debugPrint(
          '[UserPlanConsistencyRepair] ✅ Committed final batch of $batchOpCount operations',
        );
      }

      final finishedAt = DateTime.now();
      final report = RepairReport(
        plansScanned: plansScanned,
        daysScanned: daysScanned,
        daysRepaired: daysRepaired,
        activePlansFixed: 0, // Not applicable for this repair
        repairedDocPaths: repairedDocPaths,
        warnings: warnings,
      );

      debugPrint(
        '[UserPlanConsistencyRepair] ✅ Repair complete: $plansScanned plans scanned, '
        '$daysScanned days scanned, $daysRepaired days repaired',
      );

      // Write audit log (best-effort, failures don't abort the operation)
      if (_auditRepo != null) {
        try {
          final auditLog = AdminAuditLog(
            action: 'repairDayTotals',
            dryRun: dryRun,
            strictMode: null, // Not applicable
            adminUserId: adminUserId,
            startedAt: startedAt,
            finishedAt: finishedAt,
            params: {
              'epsilon': epsilon,
              'limitUsers': limitUsers,
              'limitPlansPerUser': limitPlansPerUser,
            },
            affectedDocPaths: repairedDocPaths,
            warnings: warnings,
            status: 'success',
          );
          await _auditRepo.write(auditLog);
        } catch (e) {
          debugPrint('[UserPlanConsistencyRepair] ⚠️ Failed to write audit log: $e');
          warnings.add('Audit log write failed: $e');
        }
      }

      return report;
    } catch (e) {
      final finishedAt = DateTime.now();
      
      // Attempt to write audit log even on failure (best-effort)
      if (_auditRepo != null) {
        try {
          final auditLog = AdminAuditLog(
            action: 'repairDayTotals',
            dryRun: dryRun,
            strictMode: null,
            adminUserId: adminUserId,
            startedAt: startedAt,
            finishedAt: finishedAt,
            params: {
              'epsilon': epsilon,
              'limitUsers': limitUsers,
              'limitPlansPerUser': limitPlansPerUser,
            },
            affectedDocPaths: repairedDocPaths,
            warnings: warnings,
            status: 'failed',
            error: e.toString(),
          );
          await _auditRepo.write(auditLog);
        } catch (auditError) {
          debugPrint('[UserPlanConsistencyRepair] ⚠️ Failed to write audit log on error: $auditError');
        }
      }

      if (e is MigrationException) {
        rethrow;
      }
      throw MigrationException(
        'Unexpected error during repair: $e',
        details: {'error': e.toString()},
      );
    }
  }
}
