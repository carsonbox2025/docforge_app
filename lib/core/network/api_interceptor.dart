import 'dart:convert';
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

    // 容错：如果返回的是 String，且内容是 JSON 格式，手动进行解码
    if (response.data is String) {
      final dataStr = (response.data as String).trim();
      if (dataStr.startsWith('{') && dataStr.endsWith('}')) {
        try {
          response.data = jsonDecode(dataStr);
        } catch (_) {}
      }
    }

    final data = response.data;

    // 二进制响应（文件下载等）直接放行
    if (data is List<int>) {
      handler.next(response);
      return;
    }

    // 如果返回数据最终不是 Map<String, dynamic>，说明受到了运营商劫持或服务器返回了 HTML 错误网页
    if (data is! Map<String, dynamic>) {
      final dataStr = data.toString();
      final isHtml = dataStr.contains('<!DOCTYPE html>') || dataStr.contains('<html') || dataStr.contains('<body');
      
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: isHtml 
              ? '当前请求已被移动网络阻断或劫持（可能是域名未接入备案或未配置 HTTPS）。请尝试连接 Wi-Fi 或联系客服。'
              : '服务器响应格式异常，请稍后重试。',
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }

    if (!data.containsKey('code')) {
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
    // 底层网络异常转译为用户友好文案
    final friendly = _friendlyNetworkMessage(err);
    if (friendly != null) {
      handler.next(DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        error: friendly,
        type: err.type,
      ));
      return;
    }
    handler.next(err);
  }

  /// 将底层网络异常转译为用户友好文案；返回 null 表示无需转译
  static String? _friendlyNetworkMessage(DioException err) {
    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        '网络连接超时，请检查网络后重试',
      DioExceptionType.connectionError =>
        '无法连接到服务器，请检查网络连接',
      DioExceptionType.badResponse => () {
          final status = err.response?.statusCode;
          return switch (status) {
            400 => '请求参数错误，请稍后重试',
            404 => '请求的服务不存在',
            500 => '服务器开小差了，请稍后重试',
            502 || 503 => '服务器维护中，请稍后重试',
            _ => null,
          };
        }(),
      DioExceptionType.cancel => null,
      _ => '网络请求失败，请稍后重试',
    };
  }
}
