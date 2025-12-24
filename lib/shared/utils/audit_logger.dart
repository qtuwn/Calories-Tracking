import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility class for logging admin actions to Firestore
class AuditLogger {
  final FirebaseFirestore _firestore;

  AuditLogger({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Log an admin action to the auditLogs collection
  ///
  /// [actorUid] - The UID of the user performing the action
  /// [action] - The action being performed (e.g., 'create_food', 'update_exercise', 'change_role')
  /// [target] - The target of the action (e.g., 'food:123', 'exercise:456', 'user:789')
  /// [payload] - Optional additional data about the action
  Future<void> logAdminAction(
    String actorUid,
    String action,
    String target, [
    Map<String, dynamic>? payload,
  ]) async {
    // Safety check: Skip logging if actorUid is empty
    if (actorUid.isEmpty) {
      debugPrint(
        '[AuditLogger] ⚠️ Skipping log - actorUid is empty for action: $action on $target',
      );
      return;
    }

    try {
      final logData = {
        'actorId': actorUid,
        'action': action,
        'target': target,
        'timestamp': FieldValue.serverTimestamp(),
        if (payload != null) 'payload': payload,
      };

      await _firestore.collection('auditLogs').add(logData);

      debugPrint(
        '[AuditLogger] ✅ Recorded action=$action, target=$target, actor=${actorUid.substring(0, 8)}...',
      );
    } catch (e, stackTrace) {
      debugPrint('[AuditLogger] 🔥 Failed to log action: $e');
      debugPrintStack(stackTrace: stackTrace);
      // Don't rethrow - audit logging failures should not break the main operation
    }
  }
}

/// Global instance of audit logger
final auditLogger = AuditLogger();
