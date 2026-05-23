import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/auth_remote_data_source.dart';
import '../../data/models/auth_models.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
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
    state = state.copyWith(status: AuthStatus.restoring);
    try {
      final token = await _secureStorage.getToken();
      if (token == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }
      ApiClient.instance.setToken(token);
      try {
        final userDto = await _dataSource.getMe(token);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          token: token,
          user: _toUser(userDto),
        );
      } catch (_) {
        await _secureStorage.clearAll();
        ApiClient.instance.clearToken();
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
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

  Future<Map<String, dynamic>> sendSmsCode(String phone, {String type = 'login'}) async {
    return await _dataSource.sendSmsCode(phone, type: type);
  }

  Future<void> setupProfile(String username, {String? email, String? password}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final token = state.token;
      if (token == null) return;
      final req = SetupProfileRequest(username: username, email: email, password: password);
      final resp = await _dataSource.setupProfile(token, req);
      await _secureStorage.setToken(resp.token);
      ApiClient.instance.setToken(resp.token);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        token: resp.token,
        user: _toUser(resp.user),
        isNewUser: false,
        needsOnboarding: true,
      );
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> _saveSession(AuthResponse resp) async {
    await _secureStorage.setToken(resp.token);
    await _secureStorage.setUserId(resp.user.id);
    ApiClient.instance.setToken(resp.token);
    debugPrint('[Auth] _saveSession: isNewUser=${resp.isNewUser}, user=${resp.user.username}');
    state = state.copyWith(
      status: AuthStatus.authenticated,
      token: resp.token,
      user: _toUser(resp.user),
      isNewUser: resp.isNewUser,
    );
  }

  Future<void> logout() async {
    await _secureStorage.clearSession();
    ApiClient.instance.clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void completeOnboarding() {
    state = state.copyWith(isNewUser: false, needsOnboarding: false);
  }

  void skipProfileSetup() {
    state = state.copyWith(isNewUser: false, needsOnboarding: true);
  }

  Future<void> deleteAccount() async {
    try {
      await ApiClient.instance.post(AppConstants.accountDeleteUrl);
    } catch (_) {
      // 即使 API 失败也清除本地会话
    }
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
