import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sayurpintar/features/auth/data/auth_repository.dart';

/// Local storage for authentication tokens and user data.
class AuthLocalStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'user_data';
  static const _phoneKey = 'user_phone';

  final SharedPreferences _prefs;

  AuthLocalStorage(this._prefs);

  // ── Token management ─────────────────────────

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await Future.wait([
      _prefs.setString(_accessTokenKey, accessToken),
      _prefs.setString(_refreshTokenKey, refreshToken),
    ]);
  }

  String? get accessToken => _prefs.getString(_accessTokenKey);
  String? get refreshToken => _prefs.getString(_refreshTokenKey);

  Future<void> clearTokens() async {
    await Future.wait([
      _prefs.remove(_accessTokenKey),
      _prefs.remove(_refreshTokenKey),
    ]);
  }

  // ── User data ────────────────────────────────

  Future<void> saveUser(User user) async {
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  User? get user {
    final data = _prefs.getString(_userKey);
    if (data == null) return null;
    return User.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<void> clearUser() async => _prefs.remove(_userKey);

  // ── Phone (for OTP flow) ─────────────────────

  Future<void> savePhone(String phone) async =>
      _prefs.setString(_phoneKey, phone);

  String? get phone => _prefs.getString(_phoneKey);

  // ── Utility ──────────────────────────────────

  Future<void> clearAll() async {
    await Future.wait([
      clearTokens(),
      clearUser(),
      _prefs.remove(_phoneKey),
    ]);
  }

  bool get isLoggedIn => accessToken != null;
}
