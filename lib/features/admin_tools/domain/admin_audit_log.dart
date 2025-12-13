/// Immutable model for admin audit log entries
/// 
/// Tracks who ran what migration/repair action, when, with what params,
/// and what documents were affected.
class AdminAuditLog {
  final String action; // e.g. 'backfillServingSize', 'repairDayTotals', 'repairMultipleActivePlans'
  final bool dryRun;
  final bool? strictMode; // nullable if not applicable
  final String adminUserId;
  final DateTime startedAt;
  final DateTime finishedAt;
  final Map<String, dynamic> params;
  final List<String> affectedDocPaths;
  final List<String> warnings;
  final String status; // 'success' or 'failed'
  final String? error; // if status == 'failed'

  const AdminAuditLog({
    required this.action,
    required this.dryRun,
    this.strictMode,
    required this.adminUserId,
    required this.startedAt,
    required this.finishedAt,
    required this.params,
    required this.affectedDocPaths,
    required this.warnings,
    required this.status,
    this.error,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'action': action,
      'dryRun': dryRun,
      if (strictMode != null) 'strictMode': strictMode,
      'adminUserId': adminUserId,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'params': params,
      'affectedDocPaths': affectedDocPaths,
      'warnings': warnings,
      'status': status,
      if (error != null) 'error': error,
    };
  }

  /// Parse from Firestore map
  /// 
  /// Throws FormatException if required fields are missing or invalid.
  static AdminAuditLog fromFirestore(Map<String, dynamic> data) {
    try {
      final action = data['action'] as String?;
      if (action == null || action.isEmpty) {
        throw FormatException('Missing or empty required field: action', data);
      }

      final dryRun = data['dryRun'] as bool?;
      if (dryRun == null) {
        throw FormatException('Missing required field: dryRun', data);
      }

      final adminUserId = data['adminUserId'] as String?;
      if (adminUserId == null || adminUserId.isEmpty) {
        throw FormatException('Missing or empty required field: adminUserId', data);
      }

      final startedAtStr = data['startedAt'] as String?;
      if (startedAtStr == null) {
        throw FormatException('Missing required field: startedAt', data);
      }
      final startedAt = DateTime.parse(startedAtStr);

      final finishedAtStr = data['finishedAt'] as String?;
      if (finishedAtStr == null) {
        throw FormatException('Missing required field: finishedAt', data);
      }
      final finishedAt = DateTime.parse(finishedAtStr);

      final params = data['params'] as Map<String, dynamic>? ?? {};

      final affectedDocPaths = (data['affectedDocPaths'] as List?)?.cast<String>() ?? [];

      final warnings = (data['warnings'] as List?)?.cast<String>() ?? [];

      final status = data['status'] as String?;
      if (status == null || status.isEmpty) {
        throw FormatException('Missing or empty required field: status', data);
      }
      if (status != 'success' && status != 'failed') {
        throw FormatException('Invalid status value: $status (must be "success" or "failed")', data);
      }

      final error = data['error'] as String?;

      final strictMode = data['strictMode'] as bool?;

      return AdminAuditLog(
        action: action,
        dryRun: dryRun,
        strictMode: strictMode,
        adminUserId: adminUserId,
        startedAt: startedAt,
        finishedAt: finishedAt,
        params: params,
        affectedDocPaths: affectedDocPaths,
        warnings: warnings,
        status: status,
        error: error,
      );
    } catch (e) {
      if (e is FormatException) {
        rethrow;
      }
      throw FormatException('Failed to parse AdminAuditLog: $e', data);
    }
  }

  @override
  String toString() {
    return 'AdminAuditLog(action=$action, dryRun=$dryRun, status=$status, '
        'adminUserId=${adminUserId.substring(0, 8)}..., '
        'affectedDocPaths=${affectedDocPaths.length}, warnings=${warnings.length})';
  }
}
