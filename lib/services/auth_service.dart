import 'dart:convert';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _keyCachedProfile = 'cached_user_profile_data';
  static const String _keyActiveUid = 'active_authenticated_uid';

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // Local Profile Cache Helpers (No passwords stored!)
  // ---------------------------------------------------------------------------

  Future<UserModel?> _getCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_keyCachedProfile);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final String? cachedUid = prefs.getString(_keyActiveUid);
      return UserModel.fromMap(data, cachedUid ?? data['uid'] ?? '');
    } catch (e) {
      developer.log('Error reading cached user profile: $e', name: 'AuthService');
      return null;
    }
  }

  Future<void> _saveCachedProfile(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = user.toMap();
      await prefs.setString(_keyCachedProfile, jsonEncode(map));
      await prefs.setString(_keyActiveUid, user.uid);
    } catch (e) {
      developer.log('Error saving cached profile: $e', name: 'AuthService');
    }
  }

  Future<void> _clearCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCachedProfile);
      await prefs.remove(_keyActiveUid);
    } catch (_) {}
  }

  Future<void> saveCachedProfile(UserModel user) async => _saveCachedProfile(user);

  // ---------------------------------------------------------------------------
  // Get Current Active User
  // ---------------------------------------------------------------------------

  /// Restores authenticated user session and returns user profile
  Future<UserModel?> getCurrentActiveUser({Function(UserModel)? onProfileSynced}) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      await _clearCachedProfile();
      return null;
    }

    // Check cached profile first for fast startup
    final cached = await _getCachedProfile();
    if (cached != null && cached.uid == firebaseUser.uid) {
      // If cached profile has a valid registered username, return it immediately
      if (cached.username.isNotEmpty && !cached.username.contains('@') && cached.username.toLowerCase() != 'user') {
        _syncProfileFromFirestore(firebaseUser.uid, onProfileSynced);
        return cached;
      }
    }

    // Fetch fresh profile from Firestore
    try {
      final profile = await getUserProfile(firebaseUser.uid).timeout(const Duration(seconds: 4));
      if (profile != null) {
        await _saveCachedProfile(profile);
        return profile;
      }
    } catch (e) {
      developer.log('Failed to fetch profile from Firestore on startup: $e', name: 'AuthService');
    }

    // If cache existed (even without ideal username), use it rather than generic User
    if (cached != null && cached.uid == firebaseUser.uid) {
      return cached;
    }

    // Fallback: Construct UserModel from Firebase User
    final fallbackUser = UserModel(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? '',
      username: '',
      email: firebaseUser.email ?? '',
      distractionApps: const [],
      allowGroupInvites: true,
      createdAt: DateTime.now(),
    );
    await _saveCachedProfile(fallbackUser);
    return fallbackUser;
  }

  void _syncProfileFromFirestore(String uid, [Function(UserModel)? onUpdated]) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get().timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        final profile = UserModel.fromMap(doc.data()!, doc.id);
        await _saveCachedProfile(profile);
        if (onUpdated != null) {
          onUpdated(profile);
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Username Checks
  // ---------------------------------------------------------------------------

  Future<bool> isUsernameTaken(String username) async {
    final clean = username.toLowerCase().trim();
    try {
      final doc = await _firestore.collection('Usernames').doc(clean).get().timeout(const Duration(seconds: 3));
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Register User
  // ---------------------------------------------------------------------------

  Future<UserModel> registerUser({
    required String name,
    required String username,
    required String email,
    required String password,
    required List<String> distractionApps,
  }) async {
    final cleanUsername = username.toLowerCase().trim();
    final cleanEmail = email.toLowerCase().trim();
    final cleanName = name.trim();

    // Fast pre-check for UX. The authoritative reservation happens inside the
    // transaction below, which closes the check-then-write race.
    final taken = await isUsernameTaken(cleanUsername);
    if (taken) {
      throw Exception('Username "$cleanUsername" is already taken. Please choose another.');
    }

    // Create Firebase Auth user
    final cred = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final fbUser = cred.user;
    if (fbUser == null) {
      throw Exception('Failed to create account with Firebase Authentication.');
    }

    final uid = fbUser.uid;
    final newUser = UserModel(
      uid: uid,
      name: cleanName,
      username: cleanUsername,
      email: cleanEmail,
      distractionApps: distractionApps,
      allowGroupInvites: true,
      createdAt: DateTime.now(),
    );

    final usernameRef = _firestore.collection('Usernames').doc(cleanUsername);
    final userRef = _firestore.collection('users').doc(uid);
    final publicProfileRef = _firestore.collection('publicProfiles').doc(uid);

    // Atomically reserve the username and write the profile + public projection.
    // If any part fails, roll back the freshly created auth user so we never
    // leave a credential without data (and so the email can be reused on retry).
    try {
      await _firestore.runTransaction((tx) async {
        final usernameSnap = await tx.get(usernameRef);
        if (usernameSnap.exists) {
          throw Exception(
            'Username "$cleanUsername" is already taken. Please choose another.',
          );
        }
        // Usernames index stores ONLY { uid, username } — never the email.
        tx.set(usernameRef, {'uid': uid, 'username': cleanUsername});
        tx.set(userRef, newUser.toFirestoreMap());
        tx.set(publicProfileRef, newUser.toPublicProfileMap());
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      developer.log('Registration transaction failed for uid=$uid: $e', name: 'AuthService');
      try {
        await fbUser.delete();
      } catch (deleteError) {
        developer.log(
          'Failed to roll back auth user after registration error: $deleteError',
          name: 'AuthService',
        );
      }
      rethrow;
    }

    // Cache locally
    await _saveCachedProfile(newUser);
    developer.log('Registration complete for uid=$uid', name: 'AuthService');
    return newUser;
  }

  // ---------------------------------------------------------------------------
  // Login User
  // ---------------------------------------------------------------------------

  Future<UserModel?> loginUser(String email, String password) async {
    final cleanEmail = email.toLowerCase().trim();

    developer.log('Login request started for $cleanEmail', name: 'AuthService');
    
    UserCredential cred;
    try {
      cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      developer.log('Login request failed: $e', name: 'AuthService');
      throw Exception('Login timed out or failed: $e');
    }

    developer.log('Login request completed. User: ${cred.user?.uid}', name: 'AuthService');

    if (cred.user == null) {
      throw Exception('Failed to authenticate with Firebase.');
    }

    final uid = cred.user!.uid;
    UserModel? profile;

    try {
      developer.log('Firestore profile request started for $uid', name: 'AuthService');
      profile = await getUserProfile(uid).timeout(const Duration(seconds: 5));
      developer.log('Firestore profile request completed', name: 'AuthService');
    } catch (e) {
      developer.log('Firestore profile request failed: $e', name: 'AuthService');
      throw Exception('Firestore database is unavailable: $e');
    }

    if (profile == null) {
      profile = UserModel(
        uid: uid,
        name: cred.user!.displayName ?? 'User',
        username: 'User',
        email: cleanEmail,
        distractionApps: const [],
        allowGroupInvites: true,
        createdAt: DateTime.now(),
      );
      // Save created doc to Firestore
      try {
        developer.log('Firestore profile creation started for $uid', name: 'AuthService');
        await _firestore.collection('users').doc(uid).set(profile.toFirestoreMap()).timeout(const Duration(seconds: 5));
        developer.log('Firestore profile creation completed', name: 'AuthService');
      } catch (e) {
        developer.log('Firestore profile creation failed: $e', name: 'AuthService');
        throw Exception('Failed to create user profile in Firestore: $e');
      }
    }

    await _saveCachedProfile(profile);
    developer.log('Login successful for uid=$uid', name: 'AuthService');
    return profile;
  }

  // ---------------------------------------------------------------------------
  // Profile & Password Updates
  // ---------------------------------------------------------------------------

  Future<UserModel?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await _firestore.collection('users').doc(uid).get().timeout(const Duration(seconds: 5));
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      developer.log('Error getting user profile $uid: $e', name: 'AuthService');
      throw Exception('Failed to connect to Firestore: $e');
    }
    return null;
  }

  Future<void> updateDistractionApps(String uid, List<String> packageNames) async {
    final cached = await _getCachedProfile();
    if (cached != null && cached.uid == uid) {
      final updated = cached.copyWith(distractionApps: packageNames);
      await _saveCachedProfile(updated);
    }
    try {
      await _firestore.collection('users').doc(uid).update({
        'distractionApps': packageNames,
      }).timeout(const Duration(seconds: 3));
    } catch (e) {
      developer.log('Error updating distraction apps in Firestore: $e', name: 'AuthService');
    }
  }

  Future<void> updatePrivacySetting(String uid, bool allowGroupInvites) async {
    final cached = await _getCachedProfile();
    if (cached != null && cached.uid == uid) {
      final updated = cached.copyWith(allowGroupInvites: allowGroupInvites);
      await _saveCachedProfile(updated);
    }
    try {
      await _firestore.collection('users').doc(uid).update({
        'allowGroupInvites': allowGroupInvites,
      }).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user != null && user.email != null) {
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } else {
      throw Exception('No authenticated user session found.');
    }
  }

  Future<void> signOut() async {
    await _clearCachedProfile();
    await _auth.signOut();
  }
}
