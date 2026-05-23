import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> getToken() => _storage.read(key: AppConstants.tokenKey);

  Future<void> setToken(String token) =>
      _storage.write(key: AppConstants.tokenKey, value: token);

  Future<void> deleteToken() => _storage.delete(key: AppConstants.tokenKey);

  Future<String?> getUserId() => _storage.read(key: AppConstants.userIdKey);

  Future<void> setUserId(String id) =>
      _storage.write(key: AppConstants.userIdKey, value: id);

  Future<void> deleteUserId() => _storage.delete(key: AppConstants.userIdKey);

  Future<void> clearAll() => _storage.deleteAll();

  /// 仅清除登录 session，保留"记住密码"凭据
  Future<void> clearSession() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.userIdKey);
  }

  // ─── 记住密码凭据 ───

  static const _savedIdKey = 'saved_identifier';
  static const _savedPwdKey = 'saved_password';

  Future<void> saveCredentials(String identifier, String password) async {
    await _storage.write(key: _savedIdKey, value: identifier);
    await _storage.write(key: _savedPwdKey, value: password);
  }

  Future<(String?, String?)> getSavedCredentials() async {
    return (
      await _storage.read(key: _savedIdKey),
      await _storage.read(key: _savedPwdKey),
    );
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _savedIdKey);
    await _storage.delete(key: _savedPwdKey);
  }
}
