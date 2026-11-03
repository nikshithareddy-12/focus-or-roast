import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAccountModel {
  final String uid;
  final String email;
  final String username;
  final String name;

  SavedAccountModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'name': name,
    };
  }

  factory SavedAccountModel.fromMap(Map<String, dynamic> map) {
    return SavedAccountModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      name: map['name'] ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SavedAccountModel.fromJson(String source) =>
      SavedAccountModel.fromMap(jsonDecode(source));
}

class AccountStorageService {
  static const String _keySavedAccounts = 'saved_accounts_list';
  static const String _keyActiveUid = 'active_account_uid';

  /// Save account identity locally without sensitive credentials
  Future<void> saveAccount(SavedAccountModel account) async {
    final prefs = await SharedPreferences.getInstance();
    final List<SavedAccountModel> accounts = await getSavedAccounts();

    // Replace existing if present or add new
    accounts.removeWhere((a) => a.uid == account.uid);
    accounts.add(account);

    final List<String> encoded = accounts.map((a) => a.toJson()).toList();
    await prefs.setStringList(_keySavedAccounts, encoded);
    await setActiveUid(account.uid);
  }

  /// Get list of all saved account shortcuts
  Future<List<SavedAccountModel>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? rawList = prefs.getStringList(_keySavedAccounts);
    if (rawList == null || rawList.isEmpty) {
      return [];
    }

    return rawList.map((item) {
      try {
        return SavedAccountModel.fromJson(item);
      } catch (_) {
        return SavedAccountModel(uid: '', email: '', username: '', name: '');
      }
    }).where((a) => a.uid.isNotEmpty).toList();
  }

  /// Set currently active UID
  Future<void> setActiveUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveUid, uid);
  }

  /// Get active UID
  Future<String?> getActiveUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActiveUid);
  }

  /// Remove account shortcut from device (DOES NOT delete Firebase account)
  Future<void> removeAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final List<SavedAccountModel> accounts = await getSavedAccounts();
    accounts.removeWhere((a) => a.uid == uid);

    final List<String> encoded = accounts.map((a) => a.toJson()).toList();
    await prefs.setStringList(_keySavedAccounts, encoded);

    final activeUid = await getActiveUid();
    if (activeUid == uid) {
      if (accounts.isNotEmpty) {
        await setActiveUid(accounts.first.uid);
      } else {
        await prefs.remove(_keyActiveUid);
      }
    }
  }

  /// Clear saved account list
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySavedAccounts);
    await prefs.remove(_keyActiveUid);
  }
}
