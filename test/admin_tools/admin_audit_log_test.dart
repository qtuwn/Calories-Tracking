import 'package:flutter_test/flutter_test.dart';
import 'package:calories_app/features/admin_tools/domain/admin_audit_log.dart';

void main() {
  group('AdminAuditLog', () {
    test('toFirestore and fromFirestore round-trip', () {
      final original = AdminAuditLog(
        action: 'backfillServingSize',
        dryRun: true,
        strictMode: true,
        adminUserId: 'admin123',
        startedAt: DateTime(2024, 1, 1, 12, 0, 0),
        finishedAt: DateTime(2024, 1, 1, 12, 5, 0),
        params: {'defaultServingSize': 1.0},
        affectedDocPaths: ['path1', 'path2'],
        warnings: ['warning1'],
        status: 'success',
      );

      final firestore = original.toFirestore();
      final restored = AdminAuditLog.fromFirestore(firestore);

      expect(restored.action, original.action);
      expect(restored.dryRun, original.dryRun);
      expect(restored.strictMode, original.strictMode);
      expect(restored.adminUserId, original.adminUserId);
      expect(restored.startedAt, original.startedAt);
      expect(restored.finishedAt, original.finishedAt);
      expect(restored.params, original.params);
      expect(restored.affectedDocPaths, original.affectedDocPaths);
      expect(restored.warnings, original.warnings);
      expect(restored.status, original.status);
      expect(restored.error, original.error);
    });

    test('fromFirestore throws FormatException on missing required field', () {
      final invalid = {
        'dryRun': true,
        // Missing 'action'
      };

      expect(
        () => AdminAuditLog.fromFirestore(invalid),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromFirestore throws FormatException on invalid status', () {
      final invalid = {
        'action': 'test',
        'dryRun': true,
        'adminUserId': 'admin123',
        'startedAt': '2024-01-01T12:00:00Z',
        'finishedAt': '2024-01-01T12:05:00Z',
        'params': {},
        'affectedDocPaths': [],
        'warnings': [],
        'status': 'invalid_status', // Invalid
      };

      expect(
        () => AdminAuditLog.fromFirestore(invalid),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles null strictMode', () {
      final log = AdminAuditLog(
        action: 'repairDayTotals',
        dryRun: false,
        strictMode: null, // Null allowed
        adminUserId: 'admin123',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        params: {},
        affectedDocPaths: [],
        warnings: [],
        status: 'success',
      );

      final firestore = log.toFirestore();
      expect(firestore.containsKey('strictMode'), false); // Not included if null

      final restored = AdminAuditLog.fromFirestore(firestore);
      expect(restored.strictMode, null);
    });

    test('handles error field', () {
      final log = AdminAuditLog(
        action: 'test',
        dryRun: false,
        adminUserId: 'admin123',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        params: {},
        affectedDocPaths: [],
        warnings: [],
        status: 'failed',
        error: 'Test error message',
      );

      final firestore = log.toFirestore();
      final restored = AdminAuditLog.fromFirestore(firestore);

      expect(restored.status, 'failed');
      expect(restored.error, 'Test error message');
    });
  });
}
