import 'dart:async';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/sse/sse_client.dart';
import 'models/polish_models.dart';

class PolishRemoteDataSource {
  /// 提交润色请求（SSE 流式）
  Stream<SseEvent> submitPolish(PolishRequest request) {
    return SseClient.connect(
      '${AppConstants.apiBaseUrl}/polish/submit',
      data: request.toJson(),
    );
  }

  /// 上传文档文件
  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await ApiClient.instance.post(
      '${AppConstants.apiBaseUrl}/polish/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data['data'] ?? response.data;
  }

  /// 导出润色结果
  Future<Response> exportResult({
    required String taskId,
    required ExportFormat format,
  }) async {
    return ApiClient.instance.post(
      '${AppConstants.apiBaseUrl}/polish/export',
      data: {'task_id': taskId, 'format': format.name},
      options: Options(responseType: ResponseType.bytes),
    );
  }
}
