import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:calories_app/features/home/domain/weight_entry.dart';
import 'package:calories_app/data/firebase/profile_repository.dart';
import 'date_utils.dart';

/// Repository for managing weight entries in Firestore.
/// 
/// Entries are stored in: users/{uid}/weights/{weightEntryId}
/// 
/// Weight entries track weight measurements over time, allowing users to
/// monitor their weight progress and view historical trends.
class WeightRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  WeightRepository({FirebaseFirestore? instance, FirebaseAuth? auth})
      : _firestore = instance ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Watch recent weight entries for the last N days
  /// 
  /// Returns a stream that emits a list of WeightEntry sorted by date (oldest first).
  /// Always emits at least once (empty list if no entries or on error).
  Stream<List<WeightEntry>> watchRecentWeights({
    required String uid,
    required int days,
  }) {
    debugPrint(
      '[WeightRepository] 🔵 Watching recent weights for uid=$uid, days=$days',
    );

    try {
      final now = DateTime.now();
      final startDate = DateUtils.normalizeToMidnight(now.subtract(Duration(days: days - 1)));
      final endDate = DateUtils.normalizeToMidnight(now);

      debugPrint(
        '[WeightRepository] Date range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
      );

      return _firestore
          .collection('users')
          .doc(uid)
          .collection('weights')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: false)
          .snapshots()
          .map((snapshot) {
        try {
          final entries = snapshot.docs
              .map((doc) => WeightEntry.fromDoc(doc))
              .toList();

          debugPrint(
            '[WeightRepository] ✅ Found ${entries.length} weight entries for uid=$uid',
          );

          // Fill in missing days with null entries (for chart continuity)
          // This is optional - you can return only actual entries if preferred
          return entries;
        } catch (e, stackTrace) {
          debugPrint(
            '[WeightRepository] 🔥 Error parsing weight entries: $e',
          );
          debugPrint('[WeightRepository] Stack trace: $stackTrace');
          return <WeightEntry>[];
        }
      }).handleError((error) {
        debugPrint('[WeightRepository] 🔥 Stream error: $error');
        return <WeightEntry>[];
      });
    } catch (e, stackTrace) {
      debugPrint('[WeightRepository] 🔥 Exception creating stream: $e');
      debugPrint('[WeightRepository] Stack trace: $stackTrace');
      return Stream.value(<WeightEntry>[]);
    }
  }

  /// Watch the latest weight entry
  /// 
  /// Returns a stream that emits the most recent WeightEntry, or null if none exists.
  Stream<WeightEntry?> watchLatestWeight({required String uid}) {
    debugPrint('[WeightRepository] 🔵 Watching latest weight for uid=$uid');

    try {
      return _firestore
          .collection('users')
          .doc(uid)
          .collection('weights')
          .orderBy('date', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        try {
          if (snapshot.docs.isEmpty) {
            debugPrint(
              '[WeightRepository] ℹ️ No weight entries found for uid=$uid',
            );
            return null;
          }

          final entry = WeightEntry.fromDoc(snapshot.docs.first);
          debugPrint(
            '[WeightRepository] ✅ Latest weight for uid=$uid: ${entry.weightKg}kg on ${entry.date.toIso8601String()}',
          );
          return entry;
        } catch (e, stackTrace) {
          debugPrint(
            '[WeightRepository] 🔥 Error parsing latest weight: $e',
          );
          debugPrint('[WeightRepository] Stack trace: $stackTrace');
          return null;
        }
      }).handleError((error) {
        debugPrint('[WeightRepository] 🔥 Stream error: $error');
        return null;
      });
    } catch (e, stackTrace) {
      debugPrint('[WeightRepository] 🔥 Exception creating stream: $e');
      debugPrint('[WeightRepository] Stack trace: $stackTrace');
      return Stream.value(null);
    }
  }

  /// Add or update today's weight entry
  /// 
  /// If an entry for today's date already exists, it will be updated.
  /// Otherwise, a new entry will be created.
  /// 
  /// Also updates the profile's currentWeightKg to keep it in sync.
  Future<void> addOrUpdateTodayWeight({
    required String uid,
    required double weightKg,
  }) async {
    debugPrint(
      '[WeightRepository] 🔵 Adding/updating today weight for uid=$uid, weight=$weightKg kg',
    );

    if (weightKg <= 0 || weightKg > 500) {
      throw Exception('Weight must be between 0 and 500 kg');
    }

    try {
      final today = DateUtils.normalizeToMidnight(DateTime.now());
      final todayTimestamp = Timestamp.fromDate(today);

      // Check if entry for today exists
      final existingQuery = await _firestore
          .collection('users')
          .doc(uid)
          .collection('weights')
          .where('date', isEqualTo: todayTimestamp)
          .limit(1)
          .get();

      final batch = _firestore.batch();

      if (existingQuery.docs.isNotEmpty) {
        // Update existing entry
        final docRef = existingQuery.docs.first.reference;
        debugPrint(
          '[WeightRepository] 📝 Updating existing weight entry ${docRef.id}',
        );

        batch.update(docRef, {
          'weightKg': weightKg,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new entry
        final docRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('weights')
            .doc();

        debugPrint('[WeightRepository] ➕ Creating new weight entry ${docRef.id}');

        batch.set(docRef, {
          'weightKg': weightKg,
          'date': todayTimestamp,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Update profile's currentWeightKg to keep it in sync
      final profileRepository = ProfileRepository();
      final profileId = await profileRepository.getCurrentProfileId(uid);
      if (profileId != null) {
        debugPrint(
          '[WeightRepository] 🔄 Syncing weight to profile currentWeightKg',
        );
        batch.update(
          _firestore.collection('users').doc(uid).collection('profiles').doc(profileId),
          {
            'weightKg': weightKg,
            'weight': weightKg, // Also update legacy weight field
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      // Commit all changes in a single transaction
      await batch.commit();

      debugPrint('[WeightRepository] ✅ Successfully saved weight entry');
    } catch (e, stackTrace) {
      debugPrint('[WeightRepository] 🔥 Error adding/updating weight: $e');
      debugPrint('[WeightRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get weight entries for a date range (one-time fetch)
  /// 
  /// Useful for analytics or exporting data.
  Future<List<WeightEntry>> getWeightHistory({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    debugPrint(
      '[WeightRepository] 🔵 Fetching weight history for uid=$uid from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
    );

    try {
      final normalizedStart = DateUtils.normalizeToMidnight(startDate);
      final normalizedEnd = DateUtils.normalizeToMidnight(endDate);

      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('weights')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(normalizedEnd))
          .orderBy('date', descending: false)
          .get();

      final entries = snapshot.docs.map((doc) => WeightEntry.fromDoc(doc)).toList();

      debugPrint(
        '[WeightRepository] ✅ Found ${entries.length} weight entries',
      );

      return entries;
    } catch (e, stackTrace) {
      debugPrint('[WeightRepository] 🔥 Error fetching weight history: $e');
      debugPrint('[WeightRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

