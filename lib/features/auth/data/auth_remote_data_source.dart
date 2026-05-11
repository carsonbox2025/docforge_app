import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/constants/app_constants.dart';
import 'models/auth_models.dart';

class AuthRemoteDataSource {
  /// 认证接口走 /aistudio/service/app/ 路径前缀，不走 ApiClient 的 baseUrl
  Dio get _authDio {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(ApiInterceptor());
    return dio;
  }

  Future<AuthResponse> loginWithPassword(String identifier, String password) async {
    final response = await _authDio.post(
      AppConstants.apiLoginUrl,
      data: {'identifier': identifier, 'password': password},
    );
    return AuthResponse.fromJson(response.data['data'] ?? response.data);
  }

  Future<void> sendSmsCode(String phone) async {
    await _authDio.post(
      AppConstants.apiSmsSendCodeUrl,
      data: {'phone': phone, 'type': 'login'},
    );
  }

  Future<AuthResponse> loginWithSms(String phone, String code) async {
    final response = await _authDio.post(
      AppConstants.apiSmsVerifyLoginUrl,
      data: {'phone': phone, 'code': code, 'type': 'login'},
    );
    return AuthResponse.fromJson(response.data['data'] ?? response.data);
  }

  Future<UserDto> getMe() async {
    throw UnimplementedError('getMe not available via BFF');
  }
}
