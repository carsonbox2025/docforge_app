import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/auth_remote_data_source.dart';
import '../../data/models/auth_models.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/core_providers.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    dataSource: AuthRemoteDataSource(),
    secureStorage: ref.read(secureStorageProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRemoteDataSource _dataSource;
  final SecureStorage _secureStorage;

  AuthNotifier({
    required AuthRemoteDataSource dataSource,
    required SecureStorage secureStorage,
  })  : _dataSource = dataSource,
        _secureStorage = secureStorage,
        super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final token = await _secureStorage.getToken();
      if (token == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }
      // 有 token 即视为已认证，后续调用受保护 API 时若 401 再清除
      ApiClient.instance.setToken(token);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        token: token,
      );
    } catch (e) {
      debugPrint('[Auth] Restore failed: $e');
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> loginWithSms(String phone, String code) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final resp = await _dataSource.loginWithSms(phone, code);
      await _saveSession(resp);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> loginWithPassword(String identifier, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final resp = await _dataSource.loginWithPassword(identifier, password);
      await _saveSession(resp);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> sendSmsCode(String phone) async {
    await _dataSource.sendSmsCode(phone);
  }

  Future<void> _saveSession(AuthResponse resp) async {
    await _secureStorage.setToken(resp.token);
    await _secureStorage.setUserId(resp.user.id);
    ApiClient.instance.setToken(resp.token);
    state = state.copyWith(
      status: AuthStatus.authenticated,
      token: resp.token,
      user: _toUser(resp.user),
    );
  }

  Future<void> logout() async {
    await _secureStorage.clearAll();
    ApiClient.instance.clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void forceClearSession() {
    ApiClient.instance.clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  User _toUser(UserDto dto) => User(
        id: dto.id,
        userid: dto.userid,
        username: dto.username,
        email: dto.email,
        phone: dto.phone,
        role: dto.role,
      );
}
