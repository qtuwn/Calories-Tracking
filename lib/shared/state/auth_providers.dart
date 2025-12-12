import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/shared/state/models/user_status.dart';
import 'package:calories_app/domain/profile/profile.dart';
import 'package:calories_app/shared/state/profile_providers.dart' as profile_providers;
import 'package:calories_app/data/profile/firestore_profile_repository.dart';

/// Stream provider for Firebase Auth state changes
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// User profile model for currentProfileProvider
class UserProfile {
  final String uid;
  final String? displayName;
  final String? email;
  final String role;
  final bool onboardingCompleted;

  bool get isAdmin => role == 'admin';

  const UserProfile({
    required this.uid,
    this.displayName,
    this.email,
    this.role = 'user',
    required this.onboardingCompleted,
  });

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      role: (data['role'] as String?) ?? 'user',
      onboardingCompleted: data['onboardingCompleted'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'role': role,
      'onboardingCompleted': onboardingCompleted,
    };
  }
}

/// Stream provider for current user's onboarding completion status
/// Watches users/{uid}.onboardingCompleted from Firestore in real-time
/// Guards against Firestore reads when user is signed out
final currentProfileProvider = StreamProvider.family<UserProfile?, String>((
  ref,
  uid,
) {
  debugPrint(
    '[CurrentProfileProvider] 🔵 Watching onboardingCompleted for uid=$uid',
  );

  final firestore = FirebaseFirestore.instance;
  final userDocRef = firestore.collection('users').doc(uid);

  return userDocRef.snapshots().asyncMap((snapshot) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != uid) {
        debugPrint(
          '[CurrentProfileProvider] ⚠️ User signed out or uid mismatch, returning null',
        );
        return null;
      }

      if (snapshot.exists) {
        final data = snapshot.data();
        final onboardingCompleted = data?['onboardingCompleted'] == true;
        debugPrint(
          '[CurrentProfileProvider] 📊 onboardingCompleted=$onboardingCompleted for uid=$uid',
        );

        if (onboardingCompleted) {
          return UserProfile.fromDoc(snapshot);
        }
        // If document exists but flag is false, fall through to check profiles subcollection.
      } else {
        debugPrint(
          '[CurrentProfileProvider] ℹ️ User document does not exist for uid=$uid, checking profiles subcollection',
        );
      }

      // When doc is missing or flag is false, check profiles subcollection.
      final profilesSnapshot = await userDocRef
          .collection('profiles')
          .limit(1)
          .get();

      final hasProfile = profilesSnapshot.docs.isNotEmpty;

      if (hasProfile) {
        debugPrint(
          '[CurrentProfileProvider] ✅ Profile found in subcollection for uid=$uid, backfilling onboardingCompleted',
        );
        await userDocRef.set({
          'onboardingCompleted': true,
        }, SetOptions(merge: true));
        // Get user data from FirebaseAuth for displayName and email
        final authUser = FirebaseAuth.instance.currentUser;
        return UserProfile(
          uid: uid,
          displayName: authUser?.displayName,
          email: authUser?.email,
          role: 'user', // Default role
          onboardingCompleted: true,
        );
      }

      debugPrint(
        '[CurrentProfileProvider] ℹ️ No profile data found for uid=$uid, onboarding incomplete',
      );
      final authUser = FirebaseAuth.instance.currentUser;
      return UserProfile(
        uid: uid,
        displayName: authUser?.displayName,
        email: authUser?.email,
        role: 'user', // Default role
        onboardingCompleted: false,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[CurrentProfileProvider] 🔥 Error while resolving onboarding status for uid=$uid: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      // On error, emit null so the UI can decide how to handle (usually treated as onboarding needed).
      return null;
    }
  });
});

/// Future provider for user status (profile and onboarding state)
/// Automatically backfills onboardingCompleted flag if profile exists but flag is missing
/// Guards against Firestore reads when user is signed out
final userStatusProvider = FutureProvider.family<UserStatus, String>((
  ref,
  uid,
) async {
  debugPrint('[UserStatusProvider] 🔵 Checking user status for uid=$uid');

  // Guard: Check if user is still signed in before Firestore queries
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null || currentUser.uid != uid) {
    debugPrint(
      '[UserStatusProvider] ⚠️ User signed out or uid mismatch, returning default status',
    );
    return UserStatus(hasProfile: false, onboardingCompleted: false);
  }

  try {
    final firestore = FirebaseFirestore.instance;
    final userDocRef = firestore.collection('users').doc(uid);

    // Check user document for onboardingCompleted flag
    final userDoc = await userDocRef.get();

    // Double-check user is still signed in after async operation
    final currentUserAfter = FirebaseAuth.instance.currentUser;
    if (currentUserAfter == null || currentUserAfter.uid != uid) {
      debugPrint(
        '[UserStatusProvider] ⚠️ User signed out during query, returning default status',
      );
      return UserStatus(hasProfile: false, onboardingCompleted: false);
    }

    final hasFlag =
        userDoc.exists && userDoc.data()?['onboardingCompleted'] == true;

    if (hasFlag) {
      debugPrint('[UserStatusProvider] ✅ Flag exists for uid=$uid');
      return UserStatus(hasProfile: true, onboardingCompleted: true);
    }

    // Check for profiles subcollection
    final profilesSnapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('profiles')
        .limit(1)
        .get();

    // Double-check user is still signed in after second async operation
    final currentUserAfter2 = FirebaseAuth.instance.currentUser;
    if (currentUserAfter2 == null || currentUserAfter2.uid != uid) {
      debugPrint(
        '[UserStatusProvider] ⚠️ User signed out during query, returning default status',
      );
      return UserStatus(hasProfile: false, onboardingCompleted: false);
    }

    final hasProfile = profilesSnapshot.docs.isNotEmpty;

    if (hasProfile) {
      debugPrint(
        '[UserStatusProvider] 📋 Profile exists but flag missing, backfilling for uid=$uid',
      );
      // Backfill onboardingCompleted flag
      // Note: Direct Firestore call for backfill (not in ProfileRepository interface)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'onboardingCompleted': true,
      }, SetOptions(merge: true));

      return UserStatus(hasProfile: true, onboardingCompleted: true);
    }

    debugPrint('[UserStatusProvider] ℹ️ No profile found for uid=$uid');
    return UserStatus(hasProfile: false, onboardingCompleted: false);
  } catch (e) {
    // Handle PERMISSION_DENIED and other Firestore errors gracefully
    if (e.toString().contains('PERMISSION_DENIED') ||
        e.toString().contains('permission-denied')) {
      debugPrint(
        '[UserStatusProvider] ⚠️ Permission denied for uid=$uid (user may have signed out): $e',
      );
      return UserStatus(hasProfile: false, onboardingCompleted: false);
    }
    debugPrint('[UserStatusProvider] ⚠️ Error checking user status: $e');
    rethrow;
  }
});

/// Stream provider for current user's detailed profile data with cache support
/// Watches users/{uid}/profiles subcollection for the current profile
/// Returns Profile with all health metrics (weight, height, BMI, etc.)
/// Returns null if user is not signed in or profile doesn't exist
/// 
/// NOTE: This is a family provider that takes uid as parameter.
/// Uses the new cache-aware ProfileService for instant loading.
/// For automatic auth-state-aware profile loading, use `currentUserProfileProvider` instead.
final currentUserProfileDataProvider = StreamProvider.family<Profile?, String>((
  ref,
  uid,
) {
  debugPrint(
    '[CurrentUserProfileDataProvider] 🔵 Watching detailed profile for uid=$uid',
  );

  // Guard: Check if user is signed in
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null || currentUser.uid != uid) {
    debugPrint(
      '[CurrentUserProfileDataProvider] ⚠️ User not signed in or uid mismatch, returning null',
    );
    return Stream.value(null);
  }

  // Use the new cache-aware provider
  // Note: currentProfileProvider returns StreamProvider, so we need to watch it and extract the stream
  final profileAsync = ref.watch(profile_providers.currentProfileProvider(uid));
  return profileAsync.when(
    data: (profile) => Stream.value(profile),
    loading: () => const Stream<Profile?>.empty(),
    error: (_, __) => Stream.value(null),
  );
});

/// Stream provider for current authenticated user's detailed profile data
/// Automatically watches auth state and updates when user changes
/// Returns Profile with all health metrics (weight, height, BMI, etc.)
/// Returns null if user is not signed in or profile doesn't exist
/// 
/// This provider automatically reacts to auth state changes, making it ideal
/// for AccountPage and other screens that need to update when switching accounts.
/// 
/// Uses the new cache-aware ProfileService for instant loading from cache.
final currentUserProfileProvider = StreamProvider<Profile?>((ref) {
  debugPrint('[CurrentUserProfileProvider] 🔵 Setting up auth-aware profile stream');
  
  // Watch auth state - this ensures the provider recomputes when user changes
  final authStateAsync = ref.watch(authStateProvider);
  
  // Handle auth state and return appropriate stream
  return authStateAsync.when(
    data: (user) {
      if (user == null) {
        debugPrint('[CurrentUserProfileProvider] ⚠️ No user signed in, returning null');
        return Stream<Profile?>.value(null);
      }
      
      final uid = user.uid;
      debugPrint('[CurrentUserProfileProvider] 🔵 User signed in (uid=$uid), watching profile with cache');
      
      // Use the new cache-aware provider
      // Note: currentProfileProvider returns StreamProvider, so we need to watch it and extract the stream
      final profileAsync = ref.watch(profile_providers.currentProfileProvider(uid));
      return profileAsync.when(
        data: (profile) => Stream.value(profile),
        loading: () => const Stream<Profile?>.empty(),
        error: (_, __) => Stream.value(null),
      );
    },
    loading: () {
      debugPrint('[CurrentUserProfileProvider] ⏳ Auth state loading, returning empty stream');
      return const Stream<Profile?>.empty();
    },
    error: (error, stackTrace) {
      debugPrint('[CurrentUserProfileProvider] 🔥 Auth state error: $error');
      return Stream<Profile?>.value(null);
    },
  );
});
