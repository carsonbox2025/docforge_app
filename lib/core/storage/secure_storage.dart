import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static final _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> getToken() => _storage.read(key: AppConstants.tokenKey);

  Future<void> setToken(String token) =>
      _storage.write(key: AppConstants.tokenKey, value: token);

  Future<void> deleteToken() => _storage.delete(key: AppConstants.tokenKey);

  Future<String?> getUserId() => _storage.read(key: AppConstants.userIdKey);

  Future<void> setUserId(String id) =>
      _storage.write(key: AppConstants.userIdKey, value: id);

  Future<void> clearAll() => _storage.deleteAll();
}
