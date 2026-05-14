import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import 'models/document_models.dart';

class DocumentDataSource {
  /// 提交文档任务
  Future<int> submitDocument({
    required String docType,
    required String sourceType,
    required Map<String, dynamic> userInput,
    String? templateId,
    String? title,
    String? polishLevel,
    String? sourceLang,
    String? targetLang,
  }) async {
    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      '/document/submit',
      data: {
        'doc_type': docType,
        'source_type': sourceType,
        'user_input': userInput,
        'template_id': ?templateId,
        'title': ?title,
        'polish_level': ?polishLevel,
        'source_lang': ?sourceLang,
        'target_lang': ?targetLang,
      },
    );
    final data = response.data!;
    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '提交失败');
    }
    return data['data']['id'] as int;
  }

  /// 文档列表
  Future<Map<String, dynamic>> listDocuments({
    DocStatus? status,
    String? docType,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (status != null) queryParams['status'] = status.code;
    if (docType != null) queryParams['doc_type'] = docType;

    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/document/list',
      queryParameters: queryParams,
    );
    final data = response.data!;
    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '查询失败');
    }
    return data['data'] as Map<String, dynamic>;
  }

  /// 文档详情
  Future<DocForgeDocument> getDocument(int docId) async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/document/$docId',
    );
    final data = response.data!;
    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '查询失败');
    }
    return DocForgeDocument.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// SSE 实时进度流（独立 Dio 实例，避免占用连接池）
  Stream<DocProgress> progressStream(int docId, {CancelToken? cancelToken}) async* {
    final dio = Dio(BaseOptions(
      baseUrl: ApiClient.instance.dio.options.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
    try {
      final response = await dio.get<ResponseBody>(
        '/document/$docId/stream',
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 10),
        ),
        cancelToken: cancelToken,
      );

      final stream = response.data!.stream;
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final payload = line.substring(6).trim();
            if (payload == '[DONE]') return;

            try {
              final json = jsonDecode(payload) as Map<String, dynamic>;
              final progress = (json['progress'] as num?)?.toDouble() ?? 0;
              if (progress < 0) continue;
              yield DocProgress(
                progress: progress,
                message: json['message'] as String? ?? '',
                detail: json['detail'] as Map<String, dynamic>?,
              );
              if (progress >= 1.0) return;
            } catch (_) {
              continue;
            }
          }
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
    }
  }

  /// 取消
  Future<bool> cancelDocument(int docId) async {
    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      '/document/$docId/cancel',
    );
    final data = response.data!;
    return data['code'] == 200;
  }

  /// 删除
  Future<bool> deleteDocument(int docId) async {
    final response = await ApiClient.instance.delete<Map<String, dynamic>>(
      '/document/$docId',
    );
    final data = response.data!;
    return data['code'] == 200;
  }

  /// 导出 Word
  Future<List<int>> exportWord(int docId) async {
    final dio = ApiClient.instance.dio;
    final response = await dio.post<List<int>>(
      '/export/word',
      data: {'document_id': docId, 'auto_fix': true},
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }
}
