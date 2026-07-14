import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_provider.dart'; // where sharedPreferencesProvider is defined

final authStorageProvider = Provider<LocalAuthStorageService>((ref) {
  return LocalAuthStorageService(ref.watch(sharedPreferencesProvider));
});

class LocalAuthStorageService {
  final SharedPreferences _prefs;

  LocalAuthStorageService(this._prefs);

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _emailKey = 'auth_email';
  static const _nameKey = 'auth_name';
  static const _profileImageKey = 'auth_profile_image';

  // Instant Synchronous Getters (No more await SharedPreferences.getInstance()!)
  String? get token => _prefs.getString(_tokenKey);
  String? get userId => _prefs.getString(_userIdKey);
  String? get email => _prefs.getString(_emailKey);
  String? get name => _prefs.getString(_nameKey);
  String? get profileImage => _prefs.getString(_profileImageKey);

  // Synchronous Setters via Futures
  Future<void> setToken(String token) => _prefs.setString(_tokenKey, token);
  Future<void> setUserId(String id) => _prefs.setString(_userIdKey, id);
  Future<void> setEmail(String email) => _prefs.setString(_emailKey, email);
  Future<void> setName(String name) => _prefs.setString(_nameKey, name);
  Future<void> setProfileImage(String url) => _prefs.setString(_profileImageKey, url);

  // Clear all Auth Data
  Future<void> clearAll() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userIdKey);
    await _prefs.remove(_emailKey);
    await _prefs.remove(_nameKey);
    await _prefs.remove(_profileImageKey);
  }
}
