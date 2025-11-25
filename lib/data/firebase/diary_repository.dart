import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:calories_app/features/home/domain/diary_entry.dart';
import 'package:calories_app/features/exercise/data/exercise_model.dart';
import 'date_utils.dart';

/// Repository for managing diary entries in Firestore
/// 
/// Supports both food and exercise diary entries.
/// All entries are stored in: users/{uid}/diaryEntries/{entryId}
class DiaryRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DiaryRepository({FirebaseFirestore? instance, FirebaseAuth? auth})
      : _firestore = instance ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Add a diary entry
  Future<void> addDiaryEntry(DiaryEntry entry) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User must be signed in to add diary entries');
    }

    if (entry.userId != uid) {
      throw Exception('Entry userId must match current user');
    }

    try {
      debugPrint('[DiaryRepository] 🔵 Adding diary entry for uid=$uid, date=${entry.date}');
      
      final entryData = entry.toMap();
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('diaryEntries')
          .doc();

      // Set the document ID in the entry data
      entryData['id'] = docRef.id;
      
      await docRef.set(entryData);
      
      debugPrint('[DiaryRepository] ✅ Added diary entry ${docRef.id}');
    } catch (e, stackTrace) {
      debugPrint('[DiaryRepository] 🔥 Error adding diary entry: $e');
      debugPrint('[DiaryRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Update a diary entry
  Future<void> updateDiaryEntry(DiaryEntry entry) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User must be signed in to update diary entries');
    }

    if (entry.userId != uid) {
      throw Exception('Entry userId must match current user');
    }

    try {
      debugPrint('[DiaryRepository] 🔵 Updating diary entry ${entry.id} for uid=$uid');
      
      final entryData = entry.copyWith(updatedAt: DateTime.now()).toMap();
      
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('diaryEntries')
          .doc(entry.id)
          .update(entryData);
      
      debugPrint('[DiaryRepository] ✅ Updated diary entry ${entry.id}');
    } catch (e, stackTrace) {
      debugPrint('[DiaryRepository] 🔥 Error updating diary entry: $e');
      debugPrint('[DiaryRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete a diary entry
  Future<void> deleteDiaryEntry(String entryId) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User must be signed in to delete diary entries');
    }

    try {
      debugPrint('[DiaryRepository] 🔵 Deleting diary entry $entryId for uid=$uid');
      
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('diaryEntries')
          .doc(entryId)
          .delete();
      
      debugPrint('[DiaryRepository] ✅ Deleted diary entry $entryId');
    } catch (e, stackTrace) {
      debugPrint('[DiaryRepository] 🔥 Error deleting diary entry: $e');
      debugPrint('[DiaryRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Watch diary entries for a specific date
  /// Returns a stream that emits a list of DiaryEntry for the given date
  /// Always emits at least once (empty list if no entries or on error)
  Stream<List<DiaryEntry>> watchDiaryEntriesForDate({
    required String uid,
    required DateTime date,
  }) {
    debugPrint('[DiaryRepository] 🔵 Watching diary entries for uid=$uid, date=$date');
    
    final dateString = DateUtils.normalizeToIsoString(date);
    
    // Use query without orderBy to avoid index requirement
    // We'll sort manually in the map function
    // Firestore snapshots() always emits at least once (even if empty)
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('diaryEntries')
        .where('date', isEqualTo: dateString)
        .snapshots()
        .map((snapshot) {
          try {
            final entries = snapshot.docs
                .map((doc) {
                  try {
                    return DiaryEntry.fromDoc(doc);
                  } catch (e) {
                    debugPrint('[DiaryRepository] ⚠️ Error parsing entry ${doc.id}: $e');
                    return null;
                  }
                })
                .whereType<DiaryEntry>()
                .toList();
            
            // Sort by createdAt manually
            entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            
            debugPrint('[DiaryRepository] 📊 Found ${entries.length} entries for date=$dateString');
            
            return entries;
          } catch (e, stackTrace) {
            debugPrint('[DiaryRepository] 🔥 Error processing snapshot: $e');
            debugPrint('[DiaryRepository] Stack trace: $stackTrace');
            // Return empty list on processing error
            return <DiaryEntry>[];
          }
        })
        .handleError((error, stackTrace) {
          debugPrint('[DiaryRepository] 🔥 Error watching diary entries: $error');
          debugPrint('[DiaryRepository] Stack trace: $stackTrace');
          // Re-throw error so it can be handled by the listener
          throw error;
        });
  }

  /// Get diary entries for a specific date (one-time read)
  Future<List<DiaryEntry>> getDiaryEntriesForDate({
    required String uid,
    required DateTime date,
  }) async {
    final dateString = DateUtils.normalizeToIsoString(date);
    
    try {
      debugPrint('[DiaryRepository] 🔵 Getting diary entries for uid=$uid, date=$dateString');
      
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('diaryEntries')
          .where('date', isEqualTo: dateString)
          .orderBy('createdAt', descending: false)
          .get();
      
      final entries = snapshot.docs
          .map((doc) => DiaryEntry.fromDoc(doc))
          .toList();
      
      debugPrint('[DiaryRepository] ✅ Got ${entries.length} entries for date=$dateString');
      
      return entries;
    } catch (e, stackTrace) {
      debugPrint('[DiaryRepository] 🔥 Error getting diary entries: $e');
      debugPrint('[DiaryRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Add an exercise entry to the diary
  /// 
  /// This creates a new diary entry with type=exercise.
  /// The entry stores:
  /// - exerciseId, exerciseName (denormalized)
  /// - durationMinutes, caloriesBurned
  /// - exerciseUnit, exerciseValue, exerciseLevelName (optional)
  Future<void> addExerciseEntry({
    required Exercise exercise,
    required double durationMinutes,
    required double caloriesBurned,
    required DateTime date,
    double? exerciseValue,
    String? exerciseLevelName,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User must be signed in to add exercise entries');
    }

    try {
      debugPrint(
        '[DiaryRepository] 🔵 Adding exercise entry: ${exercise.name}, duration=$durationMinutes min, calories=$caloriesBurned',
      );

      final entry = DiaryEntry.exercise(
        id: '', // Will be set by Firestore
        userId: uid,
        date: DateUtils.normalizeToIsoString(date),
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        durationMinutes: durationMinutes,
        caloriesBurned: caloriesBurned,
        exerciseUnit: exercise.unit.value,
        exerciseValue: exerciseValue,
        exerciseLevelName: exerciseLevelName,
        createdAt: DateTime.now(),
      );

      final entryData = entry.toMap();
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('diaryEntries')
          .doc();

      // Set the document ID in the entry data
      entryData['id'] = docRef.id;

      await docRef.set(entryData);

      debugPrint('[DiaryRepository] ✅ Added exercise entry ${docRef.id}');
    } catch (e, stackTrace) {
      debugPrint('[DiaryRepository] 🔥 Error adding exercise entry: $e');
      debugPrint('[DiaryRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

