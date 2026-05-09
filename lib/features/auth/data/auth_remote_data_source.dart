import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import 'models/auth_models.dart';

class AuthRemoteDataSource {
  Future<AuthResponse> loginWithPassword(String identifier, String password) async {
    final response = await ApiClient.instance.post(
      AppConstants.apiLoginUrl,
      data: {'identifier': identifier, 'password': password},
    );
    return AuthResponse.fromJson(response.data['data'] ?? response.data);
  }

  Future<void> sendSmsCode(String phone) async {
    await ApiClient.instance.post(
      AppConstants.apiSmsSendCodeUrl,
      data: {'phone': phone, 'type': 'login'},
    );
  }

  Future<AuthResponse> loginWithSms(String phone, String code) async {
    final response = await ApiClient.instance.post(
      AppConstants.apiSmsVerifyLoginUrl,
      data: {'phone': phone, 'code': code, 'type': 'login'},
    );
    return AuthResponse.fromJson(response.data['data'] ?? response.data);
  }

  Future<UserDto> getMe() async {
    // BFF 没有独立的 /me 接口，通过 token 解析或暂不调用
    // 此处保留用于 session restore，后端需提供对应接口
    throw UnimplementedError('getMe not available via BFF');
  }
}
