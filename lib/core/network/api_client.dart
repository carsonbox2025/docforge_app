import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import 'api_interceptor.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  VoidCallback? _onUnauthorized;

  Dio get dio => _dio;

  void init({String? baseUrl}) {
    final effectiveBaseUrl = baseUrl ?? _resolveBaseUrl();
    _dio = Dio(BaseOptions(
      baseUrl: effectiveBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(ApiInterceptor());
  }

  void setUnauthorizedCallback(VoidCallback callback) {
    _onUnauthorized = callback;
  }

  void notifyUnauthorized() {
    _onUnauthorized?.call();
  }

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearToken() {
    _dio.options.headers.remove('Authorization');
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> put<T>(String path, {Object? data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.delete<T>(path, queryParameters: queryParameters);

  static String _resolveBaseUrl() {
    if (kIsWeb) return AppConstants.apiBasePath;
    return '${AppConstants.apiSchemeAndHost}${AppConstants.apiBasePath}';
  }
}
