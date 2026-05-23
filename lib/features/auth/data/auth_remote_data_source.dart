import 'package:dio/dio.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/constants/app_constants.dart';
import 'models/auth_models.dart';

class AuthRemoteDataSource {
  Dio get _authDio {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(ApiInterceptor());
    return dio;
  }

  Dio _tokenDio(String token) => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

  Future<AuthResponse> loginWithPassword(String identifier, String password) async {
    final response = await _authDio.post(
      AppConstants.apiLoginUrl,
      data: {'identifier': identifier, 'password': password},
    );
    return AuthResponse.fromJson(response.data['data'] ?? response.data);
  }

  Future<Map<String, dynamic>> sendSmsCode(String phone, {String type = 'login'}) async {
    final response = await _authDio.post(
      AppConstants.apiSmsSendCodeUrl,
      data: {'phone': phone, 'type': type},
    );
    final body = response.data;
    return (body['data'] ?? body) as Map<String, dynamic>;
  }

  Future<AuthResponse> loginWithSms(String phone, String code) async {
    final response = await _authDio.post(
      AppConstants.apiSmsVerifyLoginUrl,
      data: {'phone': phone, 'code': code, 'type': 'login'},
    );
    return AuthResponse.fromJson(response.data['data'] ?? response.data);
  }

  Future<UserDto> getMe(String token) async {
    final response = await _tokenDio(token).get(AppConstants.apiGetMeUrl);
    return UserDto.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<AuthResponse> setupProfile(String token, SetupProfileRequest req) async {
    final response = await _tokenDio(token).post(
      AppConstants.apiSetupProfileUrl,
      data: req.toJson(),
    );
    return AuthResponse.fromJson(response.data['data'] ?? response.data);
  }

  Future<UserDto> setPassword(String token, String password, String code) async {
    final response = await _tokenDio(token).post(
      AppConstants.apiSetPasswordUrl,
      data: {'password': password, 'code': code},
    );
    return UserDto.fromJson(response.data['data']['user'] as Map<String, dynamic>);
  }
}
