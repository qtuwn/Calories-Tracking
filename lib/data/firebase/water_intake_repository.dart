import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:calories_app/features/home/domain/water_intake_entry.dart';
import 'date_utils.dart';

/// Repository for managing water intake entries in Firestore.
/// 
/// Entries are stored in: users/{uid}/waterIntake/{entryId}
/// 
/// Water intake is tracked separately from food/exercise diary and has
/// 0 calories - it does not affect any calorie-related metrics.
class WaterIntakeRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  WaterIntakeRepository({FirebaseFirestore? instance, FirebaseAuth? auth})
      : _firestore = instance ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Add a water intake entry
  Future<void> addWaterIntake(WaterIntakeEntry entry) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User must be signed in to add water intake');
    }

    if (entry.userId != uid) {
      throw Exception('Entry userId must match current user');
    }

    try {
      debugPrint(
        '[WaterIntakeRepository] 🔵 Adding water intake for uid=$uid, amount=${entry.amountMl}ml',
      );
      
      final entryData = entry.toMap();
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('waterIntake')
          .doc();

      // Set the document ID in the entry data
      entryData['id'] = docRef.id;
      
      await docRef.set(entryData);
      
      debugPrint('[WaterIntakeRepository] ✅ Added water intake entry ${docRef.id}');
    } catch (e, stackTrace) {
      debugPrint('[WaterIntakeRepository] 🔥 Error adding water intake: $e');
      debugPrint('[WaterIntakeRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete a water intake entry
  Future<void> deleteWaterIntake(String entryId) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User must be signed in to delete water intake');
    }

    try {
      debugPrint(
        '[WaterIntakeRepository] 🔵 Deleting water intake entry $entryId for uid=$uid',
      );
      
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('waterIntake')
          .doc(entryId)
          .delete();
      
      debugPrint('[WaterIntakeRepository] ✅ Deleted water intake entry $entryId');
    } catch (e, stackTrace) {
      debugPrint('[WaterIntakeRepository] 🔥 Error deleting water intake: $e');
      debugPrint('[WaterIntakeRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Watch water intake entries for a specific date
  /// 
  /// Returns a stream that emits a list of WaterIntakeEntry for the given date.
  /// Always emits at least once (empty list if no entries or on error).
  Stream<List<WaterIntakeEntry>> watchWaterIntakeForDate({
    required String uid,
    required DateTime date,
  }) {
    debugPrint(
      '[WaterIntakeRepository] 🔵 Watching water intake for uid=$uid, date=$date',
    );
    
    final dateString = DateUtils.normalizeToIsoString(date);
    
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('waterIntake')
        .where('date', isEqualTo: dateString)
        .snapshots()
        .map((snapshot) {
          try {
            final entries = snapshot.docs
                .map((doc) {
                  try {
                    return WaterIntakeEntry.fromDoc(doc);
                  } catch (e) {
                    debugPrint(
                      '[WaterIntakeRepository] ⚠️ Error parsing entry ${doc.id}: $e',
                    );
                    return null;
                  }
                })
                .whereType<WaterIntakeEntry>()
                .toList();
            
            debugPrint(
              '[WaterIntakeRepository] 📊 Found ${entries.length} water intake entries for date=$dateString',
            );
            
            return entries;
          } catch (e, stackTrace) {
            debugPrint(
              '[WaterIntakeRepository] 🔥 Error processing snapshot: $e',
            );
            debugPrint('[WaterIntakeRepository] Stack trace: $stackTrace');
            // Return empty list on processing error
            return <WaterIntakeEntry>[];
          }
        })
        .handleError((error, stackTrace) {
          debugPrint(
            '[WaterIntakeRepository] 🔥 Error watching water intake: $error',
          );
          debugPrint('[WaterIntakeRepository] Stack trace: $stackTrace');
          // Re-throw error so it can be handled by the listener
          throw error;
        });
  }

  /// Get water intake entries for a specific date (one-time read)
  Future<List<WaterIntakeEntry>> getWaterIntakeForDate({
    required String uid,
    required DateTime date,
  }) async {
    final dateString = DateUtils.normalizeToIsoString(date);
    
    try {
      debugPrint(
        '[WaterIntakeRepository] 🔵 Getting water intake for uid=$uid, date=$dateString',
      );
      
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('waterIntake')
          .where('date', isEqualTo: dateString)
          .orderBy('timestamp', descending: false)
          .get();
      
      final entries = snapshot.docs
          .map((doc) => WaterIntakeEntry.fromDoc(doc))
          .toList();
      
      debugPrint(
        '[WaterIntakeRepository] ✅ Got ${entries.length} water intake entries for date=$dateString',
      );
      
      return entries;
    } catch (e, stackTrace) {
      debugPrint(
        '[WaterIntakeRepository] 🔥 Error getting water intake: $e',
      );
      debugPrint('[WaterIntakeRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Quick add water intake for today
  /// 
  /// Convenience method to add a specified amount of water for the current date.
  Future<void> addWaterForToday({
    required int amountMl,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User must be signed in to add water intake');
    }

    try {
      debugPrint(
        '[WaterIntakeRepository] 🔵 Quick adding water: ${amountMl}ml for today',
      );

      final entry = WaterIntakeEntry.forToday(
        userId: uid,
        amountMl: amountMl,
      );

      await addWaterIntake(entry);

      debugPrint('[WaterIntakeRepository] ✅ Quick added water successfully');
    } catch (e, stackTrace) {
      debugPrint(
        '[WaterIntakeRepository] 🔥 Error quick adding water: $e',
      );
      debugPrint('[WaterIntakeRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

