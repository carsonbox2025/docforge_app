import 'dart:async';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/sse/sse_client.dart';
import 'models/generate_models.dart';

class GenerateDataSource {
  /// 发起文档生成（SSE 流式）
  Stream<GenerateEvent> generateStream(GenerateRequest request, {CancelToken? cancelToken}) {
    return SseClient.connect(
      '${AppConstants.apiBaseUrl}/generate/content',
      data: request.toJson(),
      cancelToken: cancelToken,
    ).map((sse) => GenerateEvent(event: sse.event, data: sse.dataAsString));
  }

  /// 导出文档（返回字节流）
  Future<List<int>> exportDocument(String taskId, ExportFormat format) async {
    final response = await ApiClient.instance.post<List<int>>(
      '${AppConstants.apiBaseUrl}/export/word',
      data: {'task_id': taskId, 'format': format.code},
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }
}
