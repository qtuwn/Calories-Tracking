import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/migration_exceptions.dart';
import '../domain/migration_report.dart';
import 'admin_audit_log_repository.dart';
import '../domain/admin_audit_log.dart';

/// Abstract interface for active plan repair operations
abstract class ActivePlanRepairRepository {
  /// Repair multiple active plans per user (keep only newest as active)
  /// 
  /// [dryRun] if true, calculates what would change without writing
  /// [limitUsers] optional limit on number of users to process
  /// [adminUserId] ID of the admin user running the operation (for audit log)
  Future<RepairReport> repairMultipleActivePlans({
    required bool dryRun,
    int? limitUsers,
    required String adminUserId,
  });
}

/// Firestore implementation of active plan repair
class FirestoreActivePlanRepairRepository
    implements ActivePlanRepairRepository {
  final FirebaseFirestore _firestore;
  final AdminAuditLogRepository? _auditRepo;

  FirestoreActivePlanRepairRepository({
    FirebaseFirestore? instance,
    AdminAuditLogRepository? auditRepo,
  })  : _firestore = instance ?? FirebaseFirestore.instance,
        _auditRepo = auditRepo;

  @override
  Future<RepairReport> repairMultipleActivePlans({
    required bool dryRun,
    int? limitUsers,
    required String adminUserId,
  }) async {
    final startedAt = DateTime.now();
    
    debugPrint(
      '[ActivePlanRepair] 🔵 Starting multiple active plans repair '
      '(dryRun=$dryRun)',
    );

    int plansScanned = 0;
    int daysScanned = 0; // Not applicable for this repair
    int daysRepaired = 0; // Not applicable for this repair
    int activePlansFixed = 0;
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
          // Query all active plans for this user, ordered by createdAt desc (newest first)
          final activePlansSnapshot = await userDoc.reference
              .collection('user_meal_plans')
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .get();

          plansScanned += activePlansSnapshot.docs.length;

          // If more than one active plan, we need to repair
          if (activePlansSnapshot.docs.length > 1) {
            final allActivePlanIds =
                activePlansSnapshot.docs.map((d) => d.id).toList();
            final newestPlanId = activePlansSnapshot.docs.first.id;

            debugPrint(
              '[ActivePlanRepair] 🔍 User $userId has ${activePlansSnapshot.docs.length} active plans: ${allActivePlanIds.join(", ")}',
            );
            debugPrint(
              '[ActivePlanRepair] 🔍 Keeping newest as active: $newestPlanId',
            );

            // Keep the newest (first) as active, deactivate the rest
            for (int i = 1; i < activePlansSnapshot.docs.length; i++) {
              final planDoc = activePlansSnapshot.docs[i];
              final planId = planDoc.id;
              final planPath = planDoc.reference.path;

              if (!dryRun) {
                // Initialize batch if needed
                if (currentBatch == null || batchOpCount >= maxBatchOps) {
                  if (currentBatch != null) {
                    await currentBatch.commit();
                    debugPrint(
                      '[ActivePlanRepair] ✅ Committed batch of $batchOpCount operations',
                    );
                  }
                  currentBatch = _firestore.batch();
                  batchOpCount = 0;
                }

                // Deactivate this plan
                currentBatch.update(planDoc.reference, {
                  'isActive': false,
                  'status': 'paused',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                batchOpCount++;
              }

              activePlansFixed++;
              repairedDocPaths.add(planPath);

              debugPrint(
                '[ActivePlanRepair] 📝 Will ${dryRun ? 'would' : ''} deactivate plan $planId at $planPath',
              );
            }

            // Log warning about affected plans
            final deactivatedIds =
                activePlansSnapshot.docs.skip(1).map((d) => d.id).toList();
            warnings.add(
              'User $userId: Deactivated ${deactivatedIds.length} active plan(s): ${deactivatedIds.join(", ")}. '
              'Kept newest active: $newestPlanId',
            );
          }
        } catch (e) {
          warnings.add('Error processing user $userId: $e');
          debugPrint(
            '[ActivePlanRepair] ⚠️ Error processing user $userId: $e',
          );
          continue;
        }
      }

      // Commit any remaining batch
      if (!dryRun && currentBatch != null && batchOpCount > 0) {
        await currentBatch.commit();
        debugPrint(
          '[ActivePlanRepair] ✅ Committed final batch of $batchOpCount operations',
        );
      }

      final finishedAt = DateTime.now();
      final report = RepairReport(
        plansScanned: plansScanned,
        daysScanned: daysScanned,
        daysRepaired: daysRepaired,
        activePlansFixed: activePlansFixed,
        repairedDocPaths: repairedDocPaths,
        warnings: warnings,
      );

      debugPrint(
        '[ActivePlanRepair] ✅ Repair complete: $plansScanned plans scanned, '
        '$activePlansFixed active plans fixed',
      );

      // Write audit log (best-effort, failures don't abort the operation)
      if (_auditRepo != null) {
        try {
          final auditLog = AdminAuditLog(
            action: 'repairMultipleActivePlans',
            dryRun: dryRun,
            strictMode: null, // Not applicable
            adminUserId: adminUserId,
            startedAt: startedAt,
            finishedAt: finishedAt,
            params: {
              'limitUsers': limitUsers,
            },
            affectedDocPaths: repairedDocPaths,
            warnings: warnings,
            status: 'success',
          );
          await _auditRepo.write(auditLog);
        } catch (e) {
          debugPrint('[ActivePlanRepair] ⚠️ Failed to write audit log: $e');
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
            action: 'repairMultipleActivePlans',
            dryRun: dryRun,
            strictMode: null,
            adminUserId: adminUserId,
            startedAt: startedAt,
            finishedAt: finishedAt,
            params: {
              'limitUsers': limitUsers,
            },
            affectedDocPaths: repairedDocPaths,
            warnings: warnings,
            status: 'failed',
            error: e.toString(),
          );
          await _auditRepo.write(auditLog);
        } catch (auditError) {
          debugPrint('[ActivePlanRepair] ⚠️ Failed to write audit log on error: $auditError');
        }
      }

      if (e is MigrationException) {
        rethrow;
      }
      throw MigrationException(
        'Unexpected error during active plan repair: $e',
        details: {'error': e.toString()},
      );
    }
  }
}
