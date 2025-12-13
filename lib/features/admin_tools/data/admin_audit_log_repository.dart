import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/admin_audit_log.dart';

/// Abstract interface for writing admin audit logs
abstract class AdminAuditLogRepository {
  /// Write an audit log entry
  /// 
  /// Best-effort: failures should not abort the migration/repair operation.
  Future<void> write(AdminAuditLog log);
}

/// Firestore implementation of [AdminAuditLogRepository]
/// 
/// Writes to collection: admin_audit_logs
/// Uses ISO 8601 strings for timestamps (consistent format).
class FirestoreAdminAuditLogRepository implements AdminAuditLogRepository {
  final FirebaseFirestore _firestore;

  FirestoreAdminAuditLogRepository({FirebaseFirestore? instance})
      : _firestore = instance ?? FirebaseFirestore.instance;

  @override
  Future<void> write(AdminAuditLog log) async {
    try {
      final logData = log.toFirestore();
      await _firestore.collection('admin_audit_logs').add(logData);
      debugPrint(
          '[AdminAuditLogRepository] ✅ Audit log written: action=${log.action}, '
          'status=${log.status}, adminUserId=${log.adminUserId.substring(0, 8)}...');
    } catch (e, stackTrace) {
      // Best-effort: log error but don't throw
      debugPrint('[AdminAuditLogRepository] 🔥 Failed to write audit log: $e');
      debugPrintStack(stackTrace: stackTrace);
      // Don't rethrow - audit logging failures should not break the main operation
    }
  }
}
