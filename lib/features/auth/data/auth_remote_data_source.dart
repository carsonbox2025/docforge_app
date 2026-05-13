import 'package:dio/dio.dart';
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

  Future<void> sendSmsCode(String phone, {String type = 'login'}) async {
    await _authDio.post(
      AppConstants.apiSmsSendCodeUrl,
      data: {'phone': phone, 'type': type},
    );
  }

  Future<AuthResponse> loginWithSms(String phone, String code) async {
    final response = await _authDio.post(
      AppConstants.apiSmsVerifyLoginUrl,
      data: {'phone': phone, 'code': code, 'type': 'login'},
    );
    return AuthResponse.fromJson(response.data['data'] ?? response.data);
  }

  Future<AuthResponse> register(
      String username, String email, String phone, String password, String code) async {
    final response = await _authDio.post(
      AppConstants.apiRegisterUrl,
      data: {
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
        'code': code,
      },
    );
    return AuthResponse.fromJson(response.data['data'] ?? response.data);
  }

  Future<UserDto> getMe(String token) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ));
    final response = await dio.get(AppConstants.apiGetMeUrl);
    return UserDto.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
