import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/diary/diary_repository.dart';
import '../../data/firebase/date_utils.dart';
import 'diary_entry_dto.dart';

/// Firestore implementation of DiaryRepository
/// 
/// Collection: users/{uid}/diaryEntries/{entryId}
class FirestoreDiaryRepository implements DiaryRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreDiaryRepository({
    FirebaseFirestore? instance,
    FirebaseAuth? auth,
  })  : _firestore = instance ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Stream<List<DiaryEntry>> watchEntriesForDay(String uid, DateTime day) {
    debugPrint('[FirestoreDiaryRepository] 🔵 Watching diary entries for uid=$uid, day=$day');
    
    final dateString = DateUtils.normalizeToIsoString(day);
    
    // Use query without orderBy to avoid index requirement
    // We'll sort manually in the map function
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
                    return DiaryEntryDto.fromFirestore(doc).toDomain();
                  } catch (e) {
                    debugPrint('[FirestoreDiaryRepository] ⚠️ Error parsing entry ${doc.id}: $e');
                    return null;
                  }
                })
                .whereType<DiaryEntry>()
                .toList();
            
            // Sort by createdAt manually
            entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            
            debugPrint('[FirestoreDiaryRepository] 📊 Found ${entries.length} entries for date=$dateString');
            
            return entries;
          } catch (e, stackTrace) {
            debugPrint('[FirestoreDiaryRepository] 🔥 Error processing snapshot: $e');
            debugPrintStack(stackTrace: stackTrace);
            return <DiaryEntry>[];
          }
        })
        .handleError((error, stackTrace) {
          debugPrint('[FirestoreDiaryRepository] 🔥 Error watching diary entries: $error');
          debugPrintStack(stackTrace: stackTrace);
          return <DiaryEntry>[];
        });
  }

  @override
  Future<List<DiaryEntry>> fetchEntriesForDay(String uid, DateTime day) async {
    final dateString = DateUtils.normalizeToIsoString(day);
    
    try {
      debugPrint('[FirestoreDiaryRepository] 🔵 Getting diary entries for uid=$uid, date=$dateString');
      
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('diaryEntries')
          .where('date', isEqualTo: dateString)
          .orderBy('createdAt', descending: false)
          .get();
      
      final entries = snapshot.docs
          .map((doc) => DiaryEntryDto.fromFirestore(doc).toDomain())
          .toList();
      
      debugPrint('[FirestoreDiaryRepository] ✅ Got ${entries.length} entries for date=$dateString');
      
      return entries;
    } catch (e, stackTrace) {
      debugPrint('[FirestoreDiaryRepository] 🔥 Error getting diary entries: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> addEntry(DiaryEntry entry) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User must be signed in to add diary entries');
    }

    if (entry.userId != uid) {
      throw Exception('Entry userId must match current user');
    }

    try {
      debugPrint('[FirestoreDiaryRepository] 🔵 Adding diary entry for uid=$uid, date=${entry.date}');
      
      final dto = DiaryEntryDto.fromDomain(entry);
      final entryData = dto.toFirestore();
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('diaryEntries')
          .doc();

      // Set the document ID in the entry data
      entryData['id'] = docRef.id;
      
      await docRef.set(entryData);
      
      debugPrint('[FirestoreDiaryRepository] ✅ Added diary entry ${docRef.id}');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreDiaryRepository] 🔥 Error adding diary entry: $e');
      debugPrint('[FirestoreDiaryRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> updateEntry(DiaryEntry entry) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User must be signed in to update diary entries');
    }

    if (entry.userId != uid) {
      throw Exception('Entry userId must match current user');
    }

    try {
      debugPrint('[FirestoreDiaryRepository] 🔵 Updating diary entry ${entry.id} for uid=$uid');
      
      final dto = DiaryEntryDto.fromDomain(entry.copyWith(updatedAt: DateTime.now()));
      final entryData = dto.toFirestore();
      
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('diaryEntries')
          .doc(entry.id)
          .update(entryData);
      
      debugPrint('[FirestoreDiaryRepository] ✅ Updated diary entry ${entry.id}');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreDiaryRepository] 🔥 Error updating diary entry: $e');
      debugPrint('[FirestoreDiaryRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> deleteEntry(String uid, String entryId) async {
    final currentUid = currentUserId;
    if (currentUid == null) {
      throw Exception('User must be signed in to delete diary entries');
    }

    if (uid != currentUid) {
      throw Exception('Cannot delete entries for other users');
    }

    try {
      debugPrint('[FirestoreDiaryRepository] 🔵 Deleting diary entry $entryId for uid=$uid');
      
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('diaryEntries')
          .doc(entryId)
          .delete();
      
      debugPrint('[FirestoreDiaryRepository] ✅ Deleted diary entry $entryId');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreDiaryRepository] 🔥 Error deleting diary entry: $e');
      debugPrint('[FirestoreDiaryRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<List<DiaryEntry>> fetchEntriesForDateRange(
    String uid,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startDateStr = DateUtils.normalizeToIsoString(startDate);
    final endDateStr = DateUtils.normalizeToIsoString(endDate);
    
    try {
      debugPrint('[FirestoreDiaryRepository] Getting diary entries for uid=$uid, range=$startDateStr to $endDateStr');
      
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('diaryEntries')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .orderBy('date', descending: false)
          .orderBy('createdAt', descending: false)
          .get();
      
      final entries = snapshot.docs
          .map((doc) {
            try {
              return DiaryEntryDto.fromFirestore(doc).toDomain();
            } catch (e) {
              debugPrint('[FirestoreDiaryRepository] ⚠️ Error parsing entry ${doc.id}: $e');
              return null;
            }
          })
          .whereType<DiaryEntry>()
          .toList();
      
      debugPrint('[FirestoreDiaryRepository] Found ${entries.length} entries for date range');
      
      return entries;
    } catch (e) {
      debugPrint('[FirestoreDiaryRepository] Error getting diary entries for date range: $e');
      rethrow;
    }
  }
}

