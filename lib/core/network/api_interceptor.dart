import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class ApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      options.extra['reqTs'] = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[API→] ${options.method} ${options.path}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final reqTs = response.requestOptions.extra['reqTs'] as int?;
      final elapsed = reqTs != null ? '${DateTime.now().millisecondsSinceEpoch - reqTs}ms' : '?';
      final data = response.data;
      final codeStr = data is Map<String, dynamic> ? '${data['code']}' : 'binary';
      debugPrint('[API←] ${response.requestOptions.method} ${response.requestOptions.path} $elapsed code=$codeStr');
    }
    final data = response.data;
    if (data is! Map<String, dynamic> || !data.containsKey('code')) {
      handler.next(response);
      return;
    }
    final code = data['code'];
    if (code == 200 || code == 0) {
      handler.next(response);
    } else if (code == 401 || code == 403) {
      if (kDebugMode) {
        debugPrint('[API!] ${response.requestOptions.path} → rejected: code=$code');
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
        debugPrint('[API!] ${response.requestOptions.path} → rejected: code=$code, message=${data['message']}');
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
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      ApiClient.instance.notifyUnauthorized();
    }
    if (kDebugMode) {
      final reqTs = err.requestOptions.extra['reqTs'] as int?;
      final elapsed = reqTs != null ? '${DateTime.now().millisecondsSinceEpoch - reqTs}ms' : '?';
      debugPrint('[API✗] ${err.requestOptions.path} $elapsed ${err.type}: ${err.message}');
      debugPrint('[API✗] status=${err.response?.statusCode} headers=${err.response?.headers.map}');
      final respData = err.response?.data;
      if (respData is List<int>) {
        debugPrint('[API✗] body(bytes): ${respData.length} bytes');
      } else if (respData != null) {
        debugPrint('[API✗] body: $respData');
      }
      debugPrint('[API✗] error: ${err.error}');
    }
    handler.next(err);
  }
}
