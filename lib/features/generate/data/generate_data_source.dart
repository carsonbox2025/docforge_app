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
      '${AppConstants.apiBaseUrl}/generate/stream',
      data: request.toJson(),
      cancelToken: cancelToken,
    ).map((sse) => GenerateEvent(event: sse.event, data: sse.dataAsString));
  }

  /// 获取生成结果（含审校）
  Future<GenerateResult> getResult(String taskId) async {
    final response = await ApiClient.instance.get(
      '${AppConstants.apiBaseUrl}/generate/$taskId/result',
    );
    final data = response.data['data'] ?? response.data;
    return GenerateResult(
      title: data['title'] as String? ?? '',
      chapters: (data['chapters'] as List<dynamic>?)
              ?.map((e) => ChapterMeta.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      content: data['content'] as String? ?? '',
      wordCount: data['word_count'] as int? ?? 0,
      findings: (data['findings'] as List<dynamic>?)
              ?.map((e) => ReviewFinding.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// 导出文档
  Future<void> exportDocument(String taskId, ExportFormat format) async {
    await ApiClient.instance.post(
      '${AppConstants.apiBaseUrl}/generate/$taskId/export',
      data: {'format': format.code},
    );
  }

  /// Mock：模拟生成过程（开发/演示用）
  /// 返回模拟的章节列表（heading + body）用于逐步写入。
  static const List<Map<String, String>> mockSections = [
    {'heading': '一、租赁双方', 'body': '甲方（出租方）：张三\n乙方（承租方）：李四'},
    {'heading': '二、房屋信息', 'body': '位于 XX 市 XX 区 XX 路 XX 号 XX 室，建筑面积 XX 平方米，房屋用途为居住。'},
    {'heading': '三、租期与租金', 'body': '租赁期限自 2026 年 1 月 1 日起至 2027 年 12 月 31 日止，月租金为人民币伍仟元整（¥5,000.00），按季支付。'},
    {'heading': '四、押金', 'body': '乙方于签订本协议时向甲方支付押金人民币壹万元整（¥10,000.00），租赁期满且无违约情形时无息退还。'},
    {'heading': '五、权利与义务', 'body': '甲方应保证房屋产权清晰，无权属纠纷。乙方应合理使用房屋，不得擅自改变房屋结构或用途。'},
    {'heading': '六、违约责任', 'body': '任何一方违约，应向守约方支付相当于两个月租金的违约金。'},
    {'heading': '七、其他约定', 'body': '本协议一式两份，甲乙双方各执一份，自双方签字之日起生效。未尽事宜，双方协商解决。'},
  ];

  /// Mock：构建模拟的生成结果
  GenerateResult buildMockResult({
    required String docTitle,
    required List<ChapterMeta> chapters,
    required String generatedContent,
  }) {
    return GenerateResult(
      title: docTitle.isEmpty ? '租房协议' : docTitle,
      chapters: chapters.isNotEmpty
          ? chapters
          : const [
              ChapterMeta(title: '一、租赁双方', order: 1),
              ChapterMeta(title: '二、房屋信息', order: 2),
              ChapterMeta(title: '三、租期与租金', order: 3),
              ChapterMeta(title: '四、押金', order: 4),
              ChapterMeta(title: '五、权利与义务', order: 5),
              ChapterMeta(title: '六、违约责任', order: 6),
              ChapterMeta(title: '七、其他约定', order: 7),
            ],
      content: generatedContent,
      wordCount: 2000,
      findings: const [
        ReviewFinding(level: ReviewLevel.pass, message: '必需章节完整性检查通过', location: '7/7 章节已包含'),
        ReviewFinding(level: ReviewLevel.pass, message: '格式规范检查通过', location: '全文'),
        ReviewFinding(level: ReviewLevel.pass, message: '条款逻辑一致性检查通过', location: '全文'),
        ReviewFinding(level: ReviewLevel.warn, message: '占位符未填充: {{party_a_name}}', location: '第二章 合同当事人'),
        ReviewFinding(level: ReviewLevel.info, message: '建议增加"保密条款"章节', location: '常见合同条款建议'),
        ReviewFinding(level: ReviewLevel.info, message: '建议增加争议解决方式条款', location: '法律合规建议'),
      ],
    );
  }
}
