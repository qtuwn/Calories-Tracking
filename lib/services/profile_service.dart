import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/profile.dart';
import 'firebase_service.dart';

/// ProfileService provides methods to read/write profiles and upload avatars.
/// It supports two modes: Firebase-backed and in-memory mock. The service
/// decides mode using FirebaseService.shouldUseFirebase().
class ProfileService {
  final bool useFirebase;
  final Map<String, Profile> _localStore = {};

  ProfileService._(this.useFirebase);

  static Future<ProfileService> create() async {
    final use = FirebaseService.shouldUseFirebase();
    // If use is true, the app should have initialized Firebase in main().
    return ProfileService._(use);
  }

  /// Fetch profile for the given uid. If firebase is enabled, reads from
  /// Firestore at users/{uid}/profile. If not, returns from in-memory store or default.
  Future<Profile> fetchProfile(String uid) async {
    if (!useFirebase) {
      // Try to read persisted mock profile from SharedPreferences first
      try {
        final prefs = await SharedPreferences.getInstance();
        final json = prefs.getString('profile_$uid');
        if (json != null) {
          final map = jsonDecode(json) as Map<String, dynamic>;
          final p = Profile.fromMap(map);
          _localStore[uid] = p;
          return p;
        }
      } catch (e) {
        debugPrint('SharedPreferences read failed: $e');
      }
      return _localStore[uid] ?? const Profile(name: 'Người dùng');
    }
    // Firebase-backed read
    try {
      // Use a document at users/{uid} to store profile fields.
      final firestore = await _getFirestore() as FirebaseFirestore;
      final docRef = firestore.collection('users').doc(uid);
      final doc = await docRef.get();
      final map = doc.data();
      if (map == null) {
        return _localStore[uid] ?? const Profile(name: 'Người dùng');
      }
      return Profile.fromMap(map);
    } catch (e) {
      debugPrint('Firestore read failed: $e');
      return _localStore[uid] ?? const Profile(name: 'Người dùng');
    }
  }

  /// Update profile in Firestore or local store, and return updated profile.
  Future<Profile> updateProfile(String uid, Profile profile) async {
    final updated = profile.copyWith(updatedAt: DateTime.now().toUtc());
    if (!useFirebase) {
      _localStore[uid] = updated;
      // Persist to SharedPreferences so mock data survives restarts
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_$uid', jsonEncode(updated.toMap()));
      } catch (e) {
        debugPrint('SharedPreferences write failed: $e');
      }
      return updated;
    }
    try {
      // Prevent accidental production writes
      FirebaseService.ensureCanWrite();
      final firestore = await _getFirestore() as FirebaseFirestore;
      await firestore.collection('users').doc(uid).set(updated.toMap());
      return updated;
    } catch (e) {
      debugPrint('Firestore write failed: $e');
      _localStore[uid] = updated;
      return updated;
    }
  }

  /// Delete all stored data for a given user. When running with Firebase enabled
  /// this will attempt to remove the profile document and avatar files. In
  /// MOCK mode this removes the profile from the in-memory store.
  Future<void> deleteAccount(String uid) async {
    if (!useFirebase) {
      _localStore.remove(uid);
      return;
    }
    try {
      // Prevent accidental production writes
      FirebaseService.ensureCanWrite();
      final firestore = await _getFirestore() as FirebaseFirestore;
      // Try to delete profile document stored at users/{uid}
      await firestore.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('Failed to delete profile doc: $e');
    }

    try {
      final storage = await _getStorage();
      // Attempt to delete avatar folder or single ref. Real implementation
      // should enumerate files and delete them. We'll attempt a best-effort
      // single-ref delete for common cases.
      final ref = storage.ref('avatars/$uid');
      if (ref != null) {
        // Some storage SDKs allow deleting a folder by referencing it; if not,
        // this will be a no-op or throw which we swallow.
        await ref.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete avatar storage: $e');
    }
  }

  /// Change the password of the currently signed-in user.
  /// Returns true if the password update completed (or was a no-op in mock),
  /// throws on errors from FirebaseAuth when running with Firebase enabled.
  Future<bool> changePassword(String newPassword) async {
    if (!useFirebase) {
      // In mock mode there's no real auth; treat as success for local dev.
      debugPrint('Mock mode: changePassword no-op');
      return true;
    }

    try {
      final user = FirebaseService.auth.currentUser;
      if (user == null) throw StateError('No authenticated user');
      await user.updatePassword(newPassword);
      debugPrint('Password updated for uid=${user.uid}');
      return true;
    } catch (e) {
      debugPrint('Failed to update password: $e');
      rethrow;
    }
  }

  /// Uploads avatar file and returns a URL (download URL) or local path.
  /// When useFirebase is true, it uploads to Firebase Storage at avatars/{uid}/{ts}.jpg
  Future<String?> uploadAvatar(String uid, XFile file) async {
    if (!useFirebase) {
      // In mock mode we just return the local path
      return file.path;
    }
    try {
      // Prevent accidental production writes
      FirebaseService.ensureCanWrite();

      // Allow storing avatar directly in Firestore if storage is disabled
      final useStorage = const String.fromEnvironment(
        'USE_STORAGE',
        defaultValue: 'true',
      );
      if (useStorage.toLowerCase() == 'false') {
        try {
          final bytes = await file.readAsBytes();
          final b64 = base64Encode(bytes);
          final firestore = await _getFirestore() as FirebaseFirestore;
          await firestore.collection('users').doc(uid).set({
            'avatarBase64': b64,
          }, SetOptions(merge: true));
          // Return a pseudo-url to indicate a data-backed avatar
          return 'data:image;base64:${b64.substring(0, 40)}...';
        } catch (e) {
          debugPrint('Failed to store avatar in Firestore: $e');
          // fallthrough to try Storage upload
        }
      }

      final storage = await _getStorage();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = storage.ref('avatars/$uid/$ts.jpg');
      // upload
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Storage upload failed: $e');
      return null;
    }
  }

  /// Save a measurement for the given user.
  /// This will append a history document in `users/{uid}/measurements_history`
  /// and update a `measurements.latest.{type}` field on the user document.
  /// Uses a batched write so both changes are committed together when using
  /// Firestore.
  Future<void> saveMeasurement(
    String uid, {
    required String type,
    required double value,
    String unit = 'kg',
    String? note,
  }) async {
    final now = DateTime.now().toUtc();

    if (!useFirebase) {
      // Update in-memory profile where possible (best-effort).
      final p = _localStore[uid];
      if (p != null) {
        if (type.toLowerCase() == 'weight' ||
            type.toLowerCase().contains('cân nặng')) {
          _localStore[uid] = p.copyWith(weightKg: value, updatedAt: now);
        } else if (type.toLowerCase() == 'height' ||
            type.toLowerCase().contains('chiều cao')) {
          _localStore[uid] = p.copyWith(heightCm: value, updatedAt: now);
        } else {
          // For other types we don't have a typed field on Profile; ignore.
        }
      }
      // Persist mock profile to SharedPreferences for dev runs.
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = _localStore[uid] ?? const Profile(name: 'Người dùng');
        await prefs.setString('profile_$uid', jsonEncode(stored.toMap()));
      } catch (e) {
        debugPrint('SharedPreferences write failed: $e');
      }
      return;
    }

    try {
      FirebaseService.ensureCanWrite();
      final firestore = await _getFirestore() as FirebaseFirestore;
      final userRef = firestore.collection('users').doc(uid);
      final historyCol = userRef.collection('measurements_history');

      final batch = firestore.batch();
      final historyDoc = historyCol.doc();
      final historyData = {
        'type': type,
        'value': value,
        'unit': unit,
        'note': note,
        'ts': FieldValue.serverTimestamp(),
      }..removeWhere((k, v) => v == null);

      batch.set(historyDoc, historyData);
      // Update latest measurement path under measurements.latest.<type>
      final latestPath = 'measurements.latest.$type';
      final updateData = <String, dynamic>{
        latestPath: value,
        'updatedAt': now.toUtc().toIso8601String(),
      };
      batch.set(userRef, updateData, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint('Failed to save measurement: $e');
      // Best-effort fallback: store in local store
      final p = _localStore[uid];
      if (p != null) {
        if (type.toLowerCase() == 'weight' ||
            type.toLowerCase().contains('cân nặng')) {
          _localStore[uid] = p.copyWith(weightKg: value, updatedAt: now);
        } else if (type.toLowerCase() == 'height' ||
            type.toLowerCase().contains('chiều cao')) {
          _localStore[uid] = p.copyWith(heightCm: value, updatedAt: now);
        }
      }
      // Re-throw so UI can show the error (do not silently swallow in debug).
      rethrow;
    }
  }

  // Helper to lazily import firestore (dynamic to avoid static dependency in some dev flows)
  Future<dynamic> _getFirestore() async {
    // Return the real Firestore instance when Firebase is enabled.
    return FirebaseFirestore.instance;
  }

  Future<dynamic> _getStorage() async {
    return FirebaseStorage.instance;
  }
}

// The wrappers below are small shim classes so the code compiles in this
// environment. In a real project these would be replaced with actual imports
// from firebase packages.

class CloudFirestoreWrapper {
  dynamic get instance => _MockFirestore();
}

class FirebaseStorageWrapper {
  dynamic get instance => _MockStorage();
}

class _MockFirestore {
  Future<_MockDoc> doc(String path) async => _MockDoc();
}

class _MockDoc {
  Future<_MockSnap> get() async => _MockSnap();
  Future<void> set(Map<String, dynamic> map) async {}
}

class _MockSnap {
  Map<String, dynamic>? data() => null;
}

class _MockStorage {
  _MockRef ref(String path) => _MockRef();
}

class _MockRef {
  Future<void> putFile(File f) async {}
  Future<String> getDownloadURL() async => '';
}

// Stubs to satisfy analyzer where imports are guarded in runtime.
void importCloudFirestore() {}
void importFirebaseStorage() {}
