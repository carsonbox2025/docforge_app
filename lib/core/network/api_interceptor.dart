import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class ApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[API] ${options.method} ${options.path}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('code')) {
      final code = data['code'];
      if (code == 200 || code == 0) {
        handler.next(response);
      } else if (code == 401 || code == 403) {
        if (kDebugMode) {
          debugPrint('[API] ${response.requestOptions.method} ${response.requestOptions.path} → rejected: code=$code');
        }
        ApiClient.instance.notifyUnauthorized();
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            error: data['message'] ?? '未授权',
            type: DioExceptionType.badResponse,
          ),
        );
      } else {
        if (kDebugMode) {
          debugPrint('[API] ${response.requestOptions.method} ${response.requestOptions.path} → rejected: code=$code, message=${data['message']}');
        }
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            error: data['message'] ?? '请求失败',
            type: DioExceptionType.badResponse,
          ),
        );
      }
    } else {
      handler.next(response);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      ApiClient.instance.notifyUnauthorized();
    }
    if (kDebugMode) {
      debugPrint('[API Error] ${err.type}: ${err.message}');
    }
    handler.next(err);
  }
}
