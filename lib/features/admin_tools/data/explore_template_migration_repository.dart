import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/migration_exceptions.dart';
import '../domain/migration_report.dart';
import 'admin_audit_log_repository.dart';
import '../domain/admin_audit_log.dart';

/// Abstract interface for explore template migration operations
abstract class ExploreTemplateMigrationRepository {
  /// Backfill missing servingSize in explore template meal slots
  /// 
  /// [defaultServingSize] must be > 0
  /// [dryRun] if true, calculates what would change without writing
  /// [limitTemplates] optional limit on number of templates to process
  /// [strict] if true, throws on invalid slot structure; if false, warns and skips
  /// [adminUserId] ID of the admin user running the operation (for audit log)
  Future<MigrationReport> backfillServingSize({
    required double defaultServingSize,
    required bool dryRun,
    bool strict = true,
    int? limitTemplates,
    required String adminUserId,
  });
}

/// Firestore implementation of explore template migration
class FirestoreExploreTemplateMigrationRepository
    implements ExploreTemplateMigrationRepository {
  final FirebaseFirestore _firestore;
  final AdminAuditLogRepository? _auditRepo;

  FirestoreExploreTemplateMigrationRepository({
    FirebaseFirestore? instance,
    AdminAuditLogRepository? auditRepo,
  })  : _firestore = instance ?? FirebaseFirestore.instance,
        _auditRepo = auditRepo;

  @override
  Future<MigrationReport> backfillServingSize({
    required double defaultServingSize,
    required bool dryRun,
    bool strict = true,
    int? limitTemplates,
    required String adminUserId,
  }) async {
    // Safety check: defaultServingSize must be > 0
    if (defaultServingSize <= 0) {
      throw MigrationException(
        'defaultServingSize must be positive, got $defaultServingSize',
      );
    }

    final startedAt = DateTime.now();

    debugPrint(
      '[ExploreTemplateMigration] 🔵 Starting backfill servingSize migration '
      '(dryRun=$dryRun, default=$defaultServingSize, strict=$strict)',
    );

    int templatesScanned = 0;
    int templatesUpdated = 0;
    int slotsUpdated = 0;
    final updatedDocPaths = <String>[];
    final warnings = <String>[];

    try {
      // Query all explore templates
      Query query = _firestore.collection('meal_plans');
      if (limitTemplates != null) {
        query = query.limit(limitTemplates);
      }

      final templatesSnapshot = await query.get();
      templatesScanned = templatesSnapshot.docs.length;

      debugPrint(
        '[ExploreTemplateMigration] 📊 Found $templatesScanned templates to scan',
      );

      WriteBatch? currentBatch;
      int batchOpCount = 0;
      const maxBatchOps = 450; // Safe headroom under Firestore's 500 limit

      for (final templateDoc in templatesSnapshot.docs) {
        final templateId = templateDoc.id;
        bool templateWasUpdated = false;

        try {
          // Get all days for this template
          final daysSnapshot = await templateDoc.reference
              .collection('days')
              .get();

          for (final dayDoc in daysSnapshot.docs) {
            // Get all meals for this day
            final mealsSnapshot = await dayDoc.reference
                .collection('meals')
                .get();

            for (final mealDoc in mealsSnapshot.docs) {
              final mealData = mealDoc.data();
              final mealPath = mealDoc.reference.path;

              // Check if servingSize is missing or invalid
              final servingSizeValue = mealData['servingSize'];
              final needsUpdate = servingSizeValue == null ||
                  (servingSizeValue is num && servingSizeValue <= 0);

              if (needsUpdate) {
                // Validate slot structure if strict mode
                if (strict) {
                  _validateSlotStructure(mealData, mealPath, templateId);
                } else {
                  // In non-strict mode, check structure but warn instead of throwing
                  try {
                    _validateSlotStructure(mealData, mealPath, templateId);
                  } catch (e) {
                    warnings.add(
                      'Invalid slot structure at $mealPath: $e (skipped)',
                    );
                    continue;
                  }
                }

                if (!dryRun) {
                  // Initialize batch if needed
                  if (currentBatch == null || batchOpCount >= maxBatchOps) {
                    if (currentBatch != null) {
                      await currentBatch.commit();
                      debugPrint(
                        '[ExploreTemplateMigration] ✅ Committed batch of $batchOpCount operations',
                      );
                    }
                    currentBatch = _firestore.batch();
                    batchOpCount = 0;
                  }

                  // Update meal doc with servingSize
                  currentBatch.update(mealDoc.reference, {
                    'servingSize': defaultServingSize,
                  });
                  batchOpCount++;
                }

                slotsUpdated++;
                updatedDocPaths.add(mealPath);
                if (!templateWasUpdated) {
                  templateWasUpdated = true;
                  templatesUpdated++;
                }

                debugPrint(
                  '[ExploreTemplateMigration] 📝 Will ${dryRun ? 'would' : ''} update '
                  '$mealPath with servingSize=$defaultServingSize',
                );
              }
            }
          }
        } catch (e) {
          final errorMsg =
              'Error processing template $templateId: $e';
          if (strict) {
            throw MigrationException(
              errorMsg,
              templateId: templateId,
              docPath: templateDoc.reference.path,
            );
          } else {
            warnings.add(errorMsg);
            debugPrint('[ExploreTemplateMigration] ⚠️ $errorMsg');
          }
        }
      }

      // Commit any remaining batch
      if (!dryRun && currentBatch != null && batchOpCount > 0) {
        await currentBatch.commit();
        debugPrint(
          '[ExploreTemplateMigration] ✅ Committed final batch of $batchOpCount operations',
        );
      }

      final finishedAt = DateTime.now();
      final report = MigrationReport(
        templatesScanned: templatesScanned,
        templatesUpdated: templatesUpdated,
        slotsUpdated: slotsUpdated,
        updatedDocPaths: updatedDocPaths,
        warnings: warnings,
      );

      debugPrint(
        '[ExploreTemplateMigration] ✅ Migration complete: $templatesScanned templates scanned, '
        '$templatesUpdated templates updated, $slotsUpdated slots updated',
      );

      // Write audit log (best-effort, failures don't abort the operation)
      if (_auditRepo != null) {
        try {
          final auditLog = AdminAuditLog(
            action: 'backfillServingSize',
            dryRun: dryRun,
            strictMode: strict,
            adminUserId: adminUserId,
            startedAt: startedAt,
            finishedAt: finishedAt,
            params: {
              'defaultServingSize': defaultServingSize,
              'limitTemplates': limitTemplates,
            },
            affectedDocPaths: updatedDocPaths,
            warnings: warnings,
            status: 'success',
          );
          await _auditRepo.write(auditLog);
        } catch (e) {
          // Best-effort: log warning but don't throw
          debugPrint('[ExploreTemplateMigration] ⚠️ Failed to write audit log: $e');
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
            action: 'backfillServingSize',
            dryRun: dryRun,
            strictMode: strict,
            adminUserId: adminUserId,
            startedAt: startedAt,
            finishedAt: finishedAt,
            params: {
              'defaultServingSize': defaultServingSize,
              'limitTemplates': limitTemplates,
            },
            affectedDocPaths: updatedDocPaths,
            warnings: warnings,
            status: 'failed',
            error: e.toString(),
          );
          await _auditRepo.write(auditLog);
        } catch (auditError) {
          // Best-effort: ignore audit failures
          debugPrint('[ExploreTemplateMigration] ⚠️ Failed to write audit log on error: $auditError');
        }
      }

      if (e is MigrationException) {
        rethrow;
      }
      throw MigrationException(
        'Unexpected error during migration: $e',
        details: {'error': e.toString()},
      );
    }
  }

  /// Validate that a meal slot has required structure
  void _validateSlotStructure(
    Map<String, dynamic> mealData,
    String mealPath,
    String templateId,
  ) {
    // Required fields: mealType, calories, protein, carb, fat
    if (!mealData.containsKey('mealType') || mealData['mealType'] == null) {
      throw MigrationException(
        'Missing required field: mealType',
        templateId: templateId,
        docPath: mealPath,
        details: {'mealData': mealData},
      );
    }

    if (!mealData.containsKey('calories') ||
        mealData['calories'] == null ||
        (mealData['calories'] is num && (mealData['calories'] as num) < 0)) {
      throw MigrationException(
        'Missing or invalid required field: calories',
        templateId: templateId,
        docPath: mealPath,
        details: {'mealData': mealData},
      );
    }

    // Protein, carb, fat are also required
    for (final field in ['protein', 'carb', 'fat']) {
      if (!mealData.containsKey(field) ||
          mealData[field] == null ||
          (mealData[field] is num && (mealData[field] as num) < 0)) {
        throw MigrationException(
          'Missing or invalid required field: $field',
          templateId: templateId,
          docPath: mealPath,
          details: {'mealData': mealData},
        );
      }
    }
  }
}
