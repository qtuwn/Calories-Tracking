import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/features/admin/domain/audit_log_model.dart';
import 'package:calories_app/shared/state/auth_providers.dart';

/// Provider for admin statistics using real-time Firestore streams
/// Updates automatically when data changes - no manual refresh needed
final adminStatsProvider = StreamProvider<AdminStats>((ref) {
  final firestore = FirebaseFirestore.instance;

  debugPrint('[AdminStatsProvider] 🔵 Setting up real-time stats stream');

  // Combine multiple Firestore streams to react to any collection changes
  // Using users collection as the trigger (most frequently updated)
  return firestore.collection('users').snapshots().asyncMap((_) async {
    try {
      // Get counts from each collection
      final usersSnapshot = await firestore.collection('users').count().get();
      final foodsSnapshot = await firestore.collection('foods').count().get();
      final exercisesSnapshot = await firestore
          .collection('exercises')
          .count()
          .get();

      // Get today's diary entries count across all users
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      int totalDiaryEntriesToday = 0;

      // Note: For production with large datasets, consider using Cloud Functions
      // to maintain aggregated counts in a separate document for instant loading
      final usersQuerySnapshot = await firestore.collection('users').get();

      for (final userDoc in usersQuerySnapshot.docs) {
        final diarySnapshot = await firestore
            .collection('diaries')
            .doc(userDoc.id)
            .collection('entries')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('date', isLessThan: Timestamp.fromDate(endOfDay))
            .count()
            .get();

        totalDiaryEntriesToday += diarySnapshot.count ?? 0;
      }

      debugPrint(
        '[AdminStatsProvider] 📊 Loaded stats: users=${usersSnapshot.count}, foods=${foodsSnapshot.count}, exercises=${exercisesSnapshot.count}, diaryToday=$totalDiaryEntriesToday',
      );

      return AdminStats(
        totalUsers: usersSnapshot.count ?? 0,
        totalFoods: foodsSnapshot.count ?? 0,
        totalExercises: exercisesSnapshot.count ?? 0,
        totalDiaryEntriesToday: totalDiaryEntriesToday,
      );
    } catch (e, stackTrace) {
      debugPrint('[AdminStatsProvider] 🔥 Error fetching stats: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  });
});

/// Admin statistics model
class AdminStats {
  final int totalUsers;
  final int totalFoods;
  final int totalExercises;
  final int totalDiaryEntriesToday;

  const AdminStats({
    required this.totalUsers,
    required this.totalFoods,
    required this.totalExercises,
    required this.totalDiaryEntriesToday,
  });
}

/// Provider for all users list (admin only)
/// Fetches all users without ordering to handle documents with missing fields
final allUsersProvider = StreamProvider<List<UserProfile>>((ref) {
  debugPrint('[AllUsersProvider] 🔵 Streaming all users');

  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((snapshot) {
        final users = snapshot.docs
            .map((doc) => UserProfile.fromDoc(doc))
            .toList();

        // Sort by email in Dart (handles null/missing emails gracefully)
        users.sort((a, b) {
          final emailA = a.email ?? '';
          final emailB = b.email ?? '';
          return emailA.compareTo(emailB);
        });

        debugPrint('[AllUsersProvider] ✅ Retrieved ${users.length} users');
        return users;
      })
      .handleError((error) {
        debugPrint('[AllUsersProvider] 🔥 Error fetching users: $error');
        throw error;
      });
});

/// Provider for audit logs stream
final auditLogsProvider = StreamProvider<List<AuditLog>>((ref) {
  debugPrint('[AuditLogsProvider] 🔵 Streaming audit logs');

  return FirebaseFirestore.instance
      .collection('auditLogs')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) {
        final logs = snapshot.docs.map((doc) => AuditLog.fromDoc(doc)).toList();
        debugPrint('[AuditLogsProvider] ✅ Retrieved ${logs.length} audit logs');
        return logs;
      })
      .handleError((error) {
        debugPrint('[AuditLogsProvider] 🔥 Error fetching audit logs: $error');
        throw error;
      });
});

/// Repository for admin user management operations
class AdminUserRepository {
  final FirebaseFirestore _firestore;

  AdminUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Update user role
  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
      });

      debugPrint(
        '[AdminUserRepository] ✅ Updated user $userId role to $newRole',
      );
    } catch (e, stackTrace) {
      debugPrint('[AdminUserRepository] 🔥 Error updating user role: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}

/// Provider for admin user repository
final adminUserRepositoryProvider = Provider<AdminUserRepository>((ref) {
  return AdminUserRepository();
});
