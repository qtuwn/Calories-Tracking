import 'package:cloud_firestore/cloud_firestore.dart';

/// Audit log entry for tracking admin actions
class AuditLog {
  final String id;
  final String actorId;
  final String action;
  final String target;
  final DateTime timestamp;
  final Map<String, dynamic>? payload;

  const AuditLog({
    required this.id,
    required this.actorId,
    required this.action,
    required this.target,
    required this.timestamp,
    this.payload,
  });

  factory AuditLog.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditLog(
      id: doc.id,
      actorId: data['actorId'] as String,
      action: data['action'] as String,
      target: data['target'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      payload: data['payload'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actorId': actorId,
      'action': action,
      'target': target,
      'timestamp': Timestamp.fromDate(timestamp),
      if (payload != null) 'payload': payload,
    };
  }
}
