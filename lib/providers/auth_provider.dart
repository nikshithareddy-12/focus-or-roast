import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/account_storage_service.dart';
import '../services/firestore_service.dart';
import 'timer_provider.dart';
import 'session_provider.dart';
import 'group_provider.dart';
import 'notification_provider.dart';
import 'quiz_provider.dart';
import 'distraction_provider.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final AccountStorageService _accountStorage = AccountStorageService();
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _currentUser;
  List<SavedAccountModel> _savedAccounts = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Completer<void> _initCompleter = Completer<void>();

  bool _suppressAuthListener = false;
  StreamSubscription<User?>? _authSub;
  bool _initialResolved = false;

  UserModel? get currentUser => _currentUser;
  UserModel? get userProfile => _currentUser;
  List<SavedAccountModel> get savedAccounts => _savedAccounts;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;
  Future<void> get isInitialized => _initCompleter.future;

  AuthProvider() {
    _init();
  }

  void _init() {
    // Subscribe synchronously — no await gap — so no auth event can be dropped
    // between startup and listener attachment. Firebase emits the current state
    // immediately on listen, which drives the initial profile load
    // deterministically (persistent login is preserved via the local cache in
    // AuthService; we never force a re-login on launch).
    _authSub = _authService.authStateChanges.listen(
      _handleAuthUser,
      onError: (e) => developer.log('authStateChanges error: $e', name: 'AuthProvider'),
    );

    // Safety net: if Firebase never emits (offline / very slow), stop the splash
    // spinner so the user is not stuck. isInitialized resolves either way.
    Future.delayed(const Duration(seconds: 6), () {
      if (!_initialResolved) {
        developer.log('Auth bootstrap timed out', name: 'AuthProvider');
        _finishInit();
      }
    });
  }

  Future<void> _handleAuthUser(User? firebaseUser) async {
    if (_suppressAuthListener) return;
    try {
      if (firebaseUser != null) {
        if (_currentUser == null || _currentUser!.uid != firebaseUser.uid) {
          final profile = await _authService.getCurrentActiveUser(
            onProfileSynced: (synced) {
              // Only accept a background sync that still matches the active user,
              // so a late callback can't overwrite a switched account.
              if (!_suppressAuthListener && _currentUser?.uid == synced.uid) {
                _currentUser = synced;
                notifyListeners();
              }
            },
          );
          if (_suppressAuthListener) return;
          if (profile != null) {
            _currentUser = profile;
            await _accountStorage.saveAccount(
              SavedAccountModel(
                uid: profile.uid,
                email: profile.email,
                username: profile.username,
                name: profile.name,
              ),
            );
            await refreshSavedAccounts();
            // Sync aggregated stats and refresh/backfill the public projection.
            _syncAndRefreshProfile(profile.uid);
            notifyListeners();
          }
        }
      } else {
        if (_currentUser != null) {
          _currentUser = null;
          notifyListeners();
        }
        await refreshSavedAccounts();
      }
    } catch (e) {
      developer.log('_handleAuthUser error: $e', name: 'AuthProvider');
    } finally {
      _finishInit();
    }
  }

  void _finishInit() {
    if (_initialResolved) return;
    _initialResolved = true;
    _isLoading = false;
    if (!_initCompleter.isCompleted) {
      _initCompleter.complete();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> refreshSavedAccounts() async {
    _savedAccounts = await _accountStorage.getSavedAccounts();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void resetAllProviders(BuildContext context) {
    try {
      Provider.of<TimerProvider>(context, listen: false).resetState();
      Provider.of<SessionProvider>(context, listen: false).resetState();
      Provider.of<GroupProvider>(context, listen: false).resetState();
      Provider.of<NotificationProvider>(context, listen: false).resetState();
      Provider.of<QuizProvider>(context, listen: false).resetState();
      Provider.of<DistractionProvider>(context, listen: false).resetState();
    } catch (_) {}
  }

  Future<bool> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required List<String> distractionApps,
    BuildContext? context,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _suppressAuthListener = true;
    notifyListeners();

    if (context != null) resetAllProviders(context);

    try {
      _currentUser = await _authService.registerUser(
        name: name,
        username: username,
        email: email,
        password: password,
        distractionApps: distractionApps,
      );

      developer.log(
        'register success: _currentUser uid=${_currentUser?.uid}, email=${_currentUser?.email}',
        name: 'AuthProvider',
      );

      if (_currentUser != null) {
        await _accountStorage.saveAccount(
          SavedAccountModel(
            uid: _currentUser!.uid,
            email: _currentUser!.email,
            username: _currentUser!.username,
            name: _currentUser!.name,
          ),
        );
      }
      await refreshSavedAccounts();
      return _currentUser != null;
    } catch (e) {
      if (e is FirebaseAuthException) {
        developer.log(
          'register FirebaseAuthException: code=${e.code}, message=${e.message}',
          name: 'AuthProvider',
        );
      } else {
        developer.log('register error: $e', name: 'AuthProvider');
      }
      _errorMessage = _friendlyAuthError(e.toString());
      return false;
    } finally {
      _isLoading = false;
      _suppressAuthListener = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password, {BuildContext? context}) async {
    _isLoading = true;
    _errorMessage = null;
    _suppressAuthListener = true;
    notifyListeners();

    if (context != null) resetAllProviders(context);

    try {
      _currentUser = await _authService.loginUser(email, password);

      developer.log(
        'login success: _currentUser uid=${_currentUser?.uid}, email=${_currentUser?.email}',
        name: 'AuthProvider',
      );

      if (_currentUser != null) {
        await _accountStorage.saveAccount(
          SavedAccountModel(
            uid: _currentUser!.uid,
            email: _currentUser!.email,
            username: _currentUser!.username,
            name: _currentUser!.name,
          ),
        );
        // Sync aggregated stats from session history after login
        _syncAndRefreshProfile(_currentUser!.uid);
      }
      await refreshSavedAccounts();
      return _currentUser != null;
    } catch (e) {
      // Log the Firebase Auth exception code safely (never log credentials)
      if (e is FirebaseAuthException) {
        developer.log(
          'login FirebaseAuthException: code=${e.code}, message=${e.message}',
          name: 'AuthProvider',
        );
      } else {
        developer.log('login error: $e', name: 'AuthProvider');
      }
      _errorMessage = _friendlyAuthError(e.toString());
      return false;
    } finally {
      _isLoading = false;
      _suppressAuthListener = false;
      notifyListeners();
    }
  }

  Future<bool> switchAccount({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _suppressAuthListener = true;
    notifyListeners();

    resetAllProviders(context);

    try {
      _currentUser = await _authService.loginUser(email, password);

      if (_currentUser != null) {
        await _accountStorage.saveAccount(
          SavedAccountModel(
            uid: _currentUser!.uid,
            email: _currentUser!.email,
            username: _currentUser!.username,
            name: _currentUser!.name,
          ),
        );
        // Sync aggregated stats from session history after account switch
        _syncAndRefreshProfile(_currentUser!.uid);
      }
      await refreshSavedAccounts();
      return _currentUser != null;
    } catch (e) {
      _errorMessage = _friendlyAuthError(e.toString());
      return false;
    } finally {
      _isLoading = false;
      _suppressAuthListener = false;
      notifyListeners();
    }
  }

  Future<void> removeAccountFromDevice(String uid, BuildContext context) async {
    await _accountStorage.removeAccount(uid);
    await refreshSavedAccounts();

    if (_currentUser != null && _currentUser!.uid == uid) {
      await logout(context: context);
    }
  }

  Future<void> updateDistractionApps(List<String> packageNames) async {
    if (_currentUser == null) return;
    try {
      await _authService.updateDistractionApps(_currentUser!.uid, packageNames);
      _currentUser = _currentUser!.copyWith(distractionApps: packageNames);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updatePrivacySetting(bool allowGroupInvites) async {
    if (_currentUser == null) return;
    try {
      await _authService.updatePrivacySetting(_currentUser!.uid, allowGroupInvites);
      _currentUser = _currentUser!.copyWith(allowGroupInvites: allowGroupInvites);
      // Mirror the privacy toggle into the public projection that group-invite
      // lookups read (allowGroupInvites is part of publicProfiles).
      await _firestoreService.upsertPublicProfile(_currentUser!);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _errorMessage = _friendlyAuthError(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sync user stats from Firestore session history and refresh the local profile.
  /// This recomputes time-relative fields (todayMinutes, weeklyMinutes, etc.)
  /// and streak data from the durable session collection, then reloads the
  /// updated user document so in-memory _currentUser reflects accurate values.
  void _syncAndRefreshProfile(String uid) async {
    try {
      await _firestoreService.syncUserStats(uid);
      // Re-fetch the updated profile so _currentUser has fresh aggregated values
      final freshProfile = await _authService.getUserProfile(uid);
      if (freshProfile == null) return;
      // Guard against an account switch that happened while this was in flight:
      // only apply the result if it still belongs to the active user.
      if (_currentUser?.uid != uid) return;
      _currentUser = freshProfile;
      await _authService.saveCachedProfile(freshProfile);
      // Keep the public projection in sync (also backfills legacy accounts that
      // predate the publicProfiles collection).
      await _firestoreService.upsertPublicProfile(freshProfile);
      notifyListeners();
    } catch (e) {
      developer.log('Background stats sync error: $e', name: 'AuthProvider');
    }
  }

  Future<void> logout({BuildContext? context}) async {
    if (context != null) resetAllProviders(context);
    await _authService.signOut();
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  String _friendlyAuthError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('email-already-in-use') || msg.contains('already registered')) {
      return 'This email address is already registered. If it\'s yours, try logging in instead.';
    }
    if (msg.contains('weak-password') || msg.contains('at least 6 characters')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }
    if (msg.contains('invalid-email') || msg.contains('invalid email')) {
      return 'The email address is not valid. Please check and try again.';
    }
    // Firebase Auth v6+ merged 'user-not-found' and 'wrong-password' into
    // 'invalid-credential'. Handle all three codes so the user gets a clear
    // message regardless of the Firebase SDK version.
    if (msg.contains('invalid-credential') ||
        msg.contains('invalid_login_credentials') ||
        msg.contains('supplied auth credential')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    }
    if (msg.contains('user-not-found') || msg.contains('no account found')) {
      return 'No account found for this email. Please check your credentials or register.';
    }
    if (msg.contains('wrong-password') || msg.contains('incorrect password')) {
      return 'Incorrect password. Please try again.';
    }
    if (msg.contains('too-many-requests') || msg.contains('blocked all requests')) {
      return 'Too many failed attempts. Please wait a moment and try again.';
    }
    if (msg.contains('network-request-failed') || msg.contains('network error')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    if (msg.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    }
    if (msg.contains('username') && msg.contains('taken')) {
      return raw.replaceAll('Exception: ', '');
    }
    return raw.replaceAll('Exception: ', '').replaceAll('[firebase_auth/', '').replaceAll(']', '');
  }
}
