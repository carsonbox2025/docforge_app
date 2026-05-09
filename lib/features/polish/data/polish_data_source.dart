import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import 'models/polish_models.dart';

class PolishRemoteDataSource {
  /// 提交润色请求（SSE 流式）
  Future<Response> submitPolish(PolishRequest request) async {
    return ApiClient.instance.post(
      '${AppConstants.apiBaseUrl}/polish/submit',
      data: request.toJson(),
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
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

  /// Mock：获取模拟润色结果（开发/演示用）
  PolishResult getMockPolishResult(PolishLevel level) {
    return PolishResult(
      title: '技术开发合同',
      level: level,
      changeCount: 12,
      acceptedCount: 11,
      pendingCount: 1,
      paragraphs: [
        PolishParagraph(segments: [
          const DiffSegment(type: 'delete', text: '甲方和乙方经友好协商'),
          const DiffSegment(type: 'insert', text: '甲乙双方经友好协商'),
          const DiffSegment(type: 'equal', text: '，就智慧园区管理平台开发项目达成如下协议：'),
        ]),
        PolishParagraph(segments: [
          const DiffSegment(type: 'delete', text: '甲方需要给乙方付款'),
          const DiffSegment(type: 'insert', text: '甲方应按合同约定向乙方支付项目款项'),
          const DiffSegment(type: 'equal', text: '，合同总金额为人民币'),
          const DiffSegment(type: 'highlight', text: '壹佰贰拾万元整（¥1,200,000.00）'),
          const DiffSegment(type: 'equal', text: '。'),
        ]),
        PolishParagraph(segments: [
          const DiffSegment(type: 'equal', text: '项目工期为 '),
          const DiffSegment(type: 'highlight', text: '6 个月'),
          const DiffSegment(type: 'equal', text: '，自合同签订之日起计算。乙方应在工期届满前完成全部开发工作并通过甲方验收。'),
        ]),
      ],
    );
  }
}
