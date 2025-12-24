import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// State for security operations (account deletion)
class SecurityState {
  final bool isLoading;
  final String? error;

  const SecurityState({
    this.isLoading = false,
    this.error,
  });

  SecurityState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return SecurityState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Controller for security-related operations
class SecurityController extends Notifier<SecurityState> {
  @override
  SecurityState build() {
    return const SecurityState();
  }

  /// Delete the current user's account and all associated data
  /// 
  /// This method:
  /// 1. Deletes all Firestore data (profiles, diary entries, weights, water intake)
  /// 2. Deletes the Firebase Auth user
  /// 3. Handles errors gracefully
  /// 
  /// Note: This is a destructive operation that cannot be undone.
  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Không tìm thấy người dùng đăng nhập');
    }

    final uid = user.uid;

    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('[SecurityController] 🔵 Starting account deletion for uid=$uid');

      final firestore = FirebaseFirestore.instance;

      // Step 1: Delete all subcollections
      // Note: Firestore batch operations have a limit of 500 operations per batch
      // We'll collect all deletions and commit in batches if needed
      
      final allDeletions = <DocumentReference>[];
      
      // Collect all document references to delete
      debugPrint('[SecurityController] 📋 Collecting documents to delete...');
      
      // Delete profiles
      final profilesSnapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('profiles')
          .get();
      allDeletions.addAll(profilesSnapshot.docs.map((doc) => doc.reference));
      debugPrint('[SecurityController] Found ${profilesSnapshot.docs.length} profile documents');

      // Delete diary entries
      final diarySnapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('diaryEntries')
          .get();
      allDeletions.addAll(diarySnapshot.docs.map((doc) => doc.reference));
      debugPrint('[SecurityController] Found ${diarySnapshot.docs.length} diary entries');

      // Delete weight entries
      final weightsSnapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('weights')
          .get();
      allDeletions.addAll(weightsSnapshot.docs.map((doc) => doc.reference));
      debugPrint('[SecurityController] Found ${weightsSnapshot.docs.length} weight entries');

      // Delete water intake entries
      final waterSnapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('waterIntake')
          .get();
      allDeletions.addAll(waterSnapshot.docs.map((doc) => doc.reference));
      debugPrint('[SecurityController] Found ${waterSnapshot.docs.length} water intake entries');

      // Add user document to deletions
      final userDocRef = firestore.collection('users').doc(uid);
      allDeletions.add(userDocRef);

      debugPrint('[SecurityController] Total documents to delete: ${allDeletions.length}');

      // Step 2: Delete in batches (Firestore batch limit is 500 operations)
      const batchLimit = 500;
      for (var i = 0; i < allDeletions.length; i += batchLimit) {
        final batch = firestore.batch();
        final end = (i + batchLimit < allDeletions.length)
            ? i + batchLimit
            : allDeletions.length;
        
        for (var j = i; j < end; j++) {
          batch.delete(allDeletions[j]);
        }
        
        debugPrint('[SecurityController] 💾 Committing batch ${(i ~/ batchLimit) + 1} (${end - i} documents)...');
        await batch.commit();
      }
      
      debugPrint('[SecurityController] ✅ All Firestore data deleted successfully');

      // Step 4: Delete Firebase Auth user
      // Note: This may require recent authentication. If it fails, we'll catch and handle it.
      debugPrint('[SecurityController] 🔐 Deleting Firebase Auth user...');
      try {
        await user.delete();
        debugPrint('[SecurityController] ✅ Firebase Auth user deleted successfully');
      } catch (authError) {
        // If deletion fails due to recent authentication requirement, re-authenticate
        if (authError.toString().contains('requires-recent-login')) {
          debugPrint('[SecurityController] ⚠️ Re-authentication required');
          throw Exception(
            'Vui lòng đăng nhập lại để xác nhận xoá tài khoản. '
            'Đây là yêu cầu bảo mật của Firebase.',
          );
        }
        rethrow;
      }

      state = state.copyWith(isLoading: false);
      debugPrint('[SecurityController] 🎉 Account deletion completed successfully');
    } catch (e, stackTrace) {
      debugPrint('[SecurityController] 🔥 Error deleting account: $e');
      debugPrint('[SecurityController] Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }
}

/// Provider for SecurityController
final securityControllerProvider =
    NotifierProvider<SecurityController, SecurityState>(
  () => SecurityController(),
);

