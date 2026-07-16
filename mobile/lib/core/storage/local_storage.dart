import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static LocalStorage? _instance;
  late final SharedPreferences _prefs;

  LocalStorage._();

  static Future<LocalStorage> init() async {
    _instance ??= LocalStorage._();
    _instance!._prefs = await SharedPreferences.getInstance();
    return _instance!;
  }

  factory LocalStorage() {
    if (_instance == null) {
      throw Exception('LocalStorage not initialized. Call init() first.');
    }
    return _instance!;
  }

  // Token management
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserRole = 'user_role';
  static const String _keyOnboardingComplete = 'onboarding_complete';

  Future<void> saveAccessToken(String token) async {
    await _prefs.setString(_keyAccessToken, token);
  }

  Future<String?> getAccessToken() async {
    return _prefs.getString(_keyAccessToken);
  }

  Future<void> saveRefreshToken(String token) async {
    await _prefs.setString(_keyRefreshToken, token);
  }

  Future<String?> getRefreshToken() async {
    return _prefs.getString(_keyRefreshToken);
  }

  Future<void> clearTokens() async {
    await _prefs.remove(_keyAccessToken);
    await _prefs.remove(_keyRefreshToken);
  }

  // User info
  Future<void> saveUserId(String id) async {
    await _prefs.setString(_keyUserId, id);
  }

  Future<String?> getUserId() async {
    return _prefs.getString(_keyUserId);
  }

  Future<void> saveUserRole(String role) async {
    await _prefs.setString(_keyUserRole, role);
  }

  Future<String?> getUserRole() async {
    return _prefs.getString(_keyUserRole);
  }

  // Onboarding
  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(_keyOnboardingComplete, true);
  }

  bool isOnboardingComplete() {
    return _prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
