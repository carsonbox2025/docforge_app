import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// 业务层额度不足异常（code=403，但非认证问题）
class QuotaExceededException implements Exception {
  final String message;
  final String? sceneId;

  const QuotaExceededException(this.message, {this.sceneId});

  @override
  String toString() => message;
}

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
    } else if (code == 401) {
      // 认证失败 → 触发登出
      if (kDebugMode) {
        debugPrint('[API!] ${response.requestOptions.path} → unauthorized: code=$code');
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
    } else if (code == 403) {
      // 额度不足 → 不触发登出，抛出专用异常
      if (kDebugMode) {
        debugPrint('[API!] ${response.requestOptions.path} → quota exceeded: code=$code');
      }
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: QuotaExceededException(data['message'] ?? '额度不足'),
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
    // 从响应体中提取业务错误信息
    if (err.response?.data is Map<String, dynamic>) {
      final data = err.response!.data as Map<String, dynamic>;
      final msg = data['message'] ?? data['msg'];
      if (msg is String && msg.isNotEmpty) {
        handler.next(DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          error: msg,
          type: DioExceptionType.badResponse,
        ));
        return;
      }
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
