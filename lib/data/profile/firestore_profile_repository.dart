import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/profile/profile.dart';
import '../../domain/profile/profile_repository.dart';

/// Firestore implementation of ProfileRepository
/// 
/// Collection: users/{userId}/profiles/{profileId}
class FirestoreProfileRepository implements ProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreProfileRepository({
    FirebaseFirestore? instance,
    FirebaseAuth? auth,
  })  : _firestore = instance ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Future<bool> hasExistingProfile(String userId) async {
    try {
      final profilesRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('profiles')
          .limit(1);

      final snapshot = await profilesRef.get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('[FirestoreProfileRepository] Error checking profile: $e');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getUserProfiles(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profiles')
          .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('[FirestoreProfileRepository] Error getting profiles: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUserProfile(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profiles')
          .where('isCurrent', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      return {'id': doc.id, ...doc.data()};
    } catch (e) {
      debugPrint('[FirestoreProfileRepository] Error getting current profile: $e');
      return null;
    }
  }

  @override
  Stream<Map<String, dynamic>?> watchCurrentUserProfile(String userId) {
    debugPrint('[FirestoreProfileRepository] 🔵 Watching profile for uid=$userId');

    try {
      return _firestore
          .collection('users')
          .doc(userId)
          .collection('profiles')
          .where('isCurrent', isEqualTo: true)
          .limit(1)
          .snapshots()
          .asyncMap((snapshot) async {
            if (snapshot.docs.isNotEmpty) {
              final doc = snapshot.docs.first;
              final data = doc.data();
              debugPrint(
                  '[FirestoreProfileRepository] ✅ Found current profile ${doc.id} for uid=$userId');
              return {'id': doc.id, ...data};
            }

            // Fallback: if no profile with isCurrent=true, get the most recent profile
            debugPrint(
                '[FirestoreProfileRepository] ℹ️ No current profile found, checking for any profile for uid=$userId');
            final fallbackSnapshot = await _firestore
                .collection('users')
                .doc(userId)
                .collection('profiles')
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();

            if (fallbackSnapshot.docs.isNotEmpty) {
              final doc = fallbackSnapshot.docs.first;
              final data = doc.data();
              debugPrint(
                  '[FirestoreProfileRepository] ✅ Found fallback profile ${doc.id} for uid=$userId');
              return {'id': doc.id, ...data};
            }

            debugPrint('[FirestoreProfileRepository] ℹ️ No profile found for uid=$userId');
            return null;
          })
          .handleError((error) {
            debugPrint(
                '[FirestoreProfileRepository] 🔥 Error watching profile for uid=$userId: $error');
            return null;
          });
    } catch (e) {
      debugPrint(
          '[FirestoreProfileRepository] 🔥 Exception in watchCurrentUserProfile for uid=$userId: $e');
      return Stream.value(null);
    }
  }

  @override
  Stream<Profile?> watchProfile(String userId) {
    debugPrint('[FirestoreProfileRepository] 🔵 Watching profile as domain entity for uid=$userId');

    return watchCurrentUserProfile(userId).map((profileMap) {
      if (profileMap == null) {
        return null;
      }

      try {
        // Remove 'id' field (metadata, not part of Profile)
        final data = Map<String, dynamic>.from(profileMap);
        data.remove('id');

        // Convert to Profile domain entity using fromJson
        final profile = Profile.fromJson(data);
        debugPrint('[FirestoreProfileRepository] ✅ Converted profile to domain entity');
        return profile;
      } catch (e, stackTrace) {
        debugPrint('[FirestoreProfileRepository] 🔥 Error converting to Profile: $e');
        debugPrintStack(stackTrace: stackTrace);
        return null;
      }
    });
  }

  @override
  Future<String> saveProfile(String userId, Map<String, dynamic> profileData) async {
    debugPrint('[FirestoreProfileRepository] 🔵 Starting saveProfile for uid=$userId');

    try {
      // Step 1: Normalize numeric types (int -> double for consistency)
      final normalized = _normalizeProfileData(profileData);

      debugPrint(
          '[FirestoreProfileRepository] 📊 Normalized profile data: ${normalized.keys.toList()}');

      // Step 2: Ensure required fields
      normalized['isCurrent'] = normalized['isCurrent'] ?? true;
      normalized['createdAt'] = FieldValue.serverTimestamp();

      // Step 3: Get user document reference
      final userDocRef = _firestore.collection('users').doc(userId);

      // Step 4: Create batch for atomic operations
      final batch = _firestore.batch();

      // Step 5: Set all other profiles to isCurrent=false
      final currentProfilesQuery = userDocRef
          .collection('profiles')
          .where('isCurrent', isEqualTo: true);

      final currentProfilesSnapshot = await currentProfilesQuery.get();
      debugPrint(
          '[FirestoreProfileRepository] 📋 Found ${currentProfilesSnapshot.docs.length} existing current profiles');

      for (var doc in currentProfilesSnapshot.docs) {
        batch.update(doc.reference, {'isCurrent': false});
      }

      // Step 6: Add new profile document
      final newProfileRef = userDocRef.collection('profiles').doc();
      batch.set(newProfileRef, normalized);

      debugPrint('[FirestoreProfileRepository] 📝 Created new profile doc: ${newProfileRef.id}');

      // Step 7: Set onboardingCompleted flag on user document
      batch.set(userDocRef, {
        'onboardingCompleted': true,
      }, SetOptions(merge: true));

      debugPrint(
          '[FirestoreProfileRepository] ✅ Setting onboardingCompleted=true for uid=$userId');

      // Step 8: Commit batch (all operations are atomic)
      await batch.commit();

      debugPrint(
          '[FirestoreProfileRepository] 🎉 Successfully saved profile ${newProfileRef.id} and set onboardingCompleted for uid=$userId');

      return newProfileRef.id;
    } catch (e, stackTrace) {
      debugPrint('[FirestoreProfileRepository] 🔥 saveProfile FAILED for uid=$userId');
      debugPrint('[FirestoreProfileRepository] Error: $e');
      debugPrint('[FirestoreProfileRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> updateProfile(
    String userId,
    String profileId,
    Map<String, dynamic> profileData,
  ) async {
    debugPrint(
        '[FirestoreProfileRepository] 🔵 Updating profile for uid=$userId, profileId=$profileId');

    try {
      final normalized = _normalizeProfileData(profileData);

      // Remove createdAt since we don't want to update it
      normalized.remove('createdAt');

      // Add updatedAt timestamp
      normalized['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profiles')
          .doc(profileId)
          .update(normalized);

      debugPrint(
          '[FirestoreProfileRepository] ✅ Successfully updated profile for uid=$userId, profileId=$profileId');
    } catch (e, stackTrace) {
      debugPrint(
          '[FirestoreProfileRepository] 🔥 updateProfile FAILED for uid=$userId, profileId=$profileId');
      debugPrint('[FirestoreProfileRepository] Error: $e');
      debugPrint('[FirestoreProfileRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> setCurrentProfile(String userId, String profileId) async {
    debugPrint(
        '[FirestoreProfileRepository] 🔵 Setting current profile for uid=$userId, profileId=$profileId');

    try {
      final batch = _firestore.batch();

      // Set all other profiles to isCurrent=false
      final currentProfilesQuery = _firestore
          .collection('users')
          .doc(userId)
          .collection('profiles')
          .where('isCurrent', isEqualTo: true);

      final currentProfilesSnapshot = await currentProfilesQuery.get();

      for (var doc in currentProfilesSnapshot.docs) {
        if (doc.id != profileId) {
          batch.update(doc.reference, {'isCurrent': false});
        }
      }

      // Set the specified profile to isCurrent=true
      batch.update(
        _firestore.collection('users').doc(userId).collection('profiles').doc(profileId),
        {'isCurrent': true},
      );

      await batch.commit();

      debugPrint(
          '[FirestoreProfileRepository] ✅ Successfully set current profile for uid=$userId, profileId=$profileId');
    } catch (e, stackTrace) {
      debugPrint(
          '[FirestoreProfileRepository] 🔥 setCurrentProfile FAILED for uid=$userId, profileId=$profileId');
      debugPrint('[FirestoreProfileRepository] Error: $e');
      debugPrint('[FirestoreProfileRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> deleteProfile(String userId, String profileId) async {
    debugPrint(
        '[FirestoreProfileRepository] 🔵 Deleting profile for uid=$userId, profileId=$profileId');

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profiles')
          .doc(profileId)
          .delete();

      debugPrint(
          '[FirestoreProfileRepository] ✅ Successfully deleted profile for uid=$userId, profileId=$profileId');
    } catch (e, stackTrace) {
      debugPrint(
          '[FirestoreProfileRepository] 🔥 deleteProfile FAILED for uid=$userId, profileId=$profileId');
      debugPrint('[FirestoreProfileRepository] Error: $e');
      debugPrint('[FirestoreProfileRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Normalize profile data: convert int to double for numeric fields
  Map<String, dynamic> _normalizeProfileData(Map<String, dynamic> profile) {
    final normalized = Map<String, dynamic>.from(profile);

    // Fields that should be double (not int)
    final doubleFields = [
      'height',
      'weight',
      'weightKg',
      'bmi',
      'targetWeight',
      'weeklyDeltaKg',
      'activityMultiplier',
      'bmr',
      'tdee',
      'targetKcal',
      'proteinPercent',
      'carbPercent',
      'fatPercent',
      'proteinGrams',
      'carbGrams',
      'fatGrams',
    ];

    for (final key in doubleFields) {
      if (normalized.containsKey(key) && normalized[key] is int) {
        normalized[key] = (normalized[key] as int).toDouble();
        debugPrint('[FirestoreProfileRepository] 🔄 Normalized $key: int -> double');
      }
    }

    // Remove null values for cleaner Firestore writes
    normalized.removeWhere((key, value) => value == null);

    return normalized;
  }

  @override
  Future<String?> getCurrentProfileId(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profiles')
          .where('isCurrent', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('[FirestoreProfileRepository] ℹ️ No current profile found for uid=$userId');
        return null;
      }

      final profileId = snapshot.docs.first.id;
      debugPrint('[FirestoreProfileRepository] ✅ Found current profileId=$profileId for uid=$userId');
      return profileId;
    } catch (e, stackTrace) {
      debugPrint('[FirestoreProfileRepository] 🔥 Error getting current profileId for uid=$userId: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<void> updateProfileAvatarBase64({
    required String userId,
    required String profileId,
    required String photoBase64,
  }) async {
    debugPrint(
      '[FirestoreProfileRepository] 🔵 Updating photoBase64 for uid=$userId, profileId=$profileId',
    );

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profiles')
          .doc(profileId)
          .update({'photoBase64': photoBase64});

      debugPrint(
        '[FirestoreProfileRepository] ✅ Successfully updated photoBase64 for uid=$userId, profileId=$profileId',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[FirestoreProfileRepository] 🔥 updateProfileAvatarBase64 FAILED for uid=$userId, profileId=$profileId',
      );
      debugPrint('[FirestoreProfileRepository] Error: $e');
      debugPrint('[FirestoreProfileRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

