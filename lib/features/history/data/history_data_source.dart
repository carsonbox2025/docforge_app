import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import 'models/history_models.dart';

class HistoryDataSource {
  /// 获取历史文档列表
  Future<List<HistoryDocument>> getHistoryList({
    HistoryFilter filter = HistoryFilter.all,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await ApiClient.instance.get(
        '${AppConstants.apiBaseUrl}/history',
        queryParameters: {
          'filter': filter.name,
          'page': page,
          'page_size': pageSize,
        },
      );
      final data = response.data['data'] as List<dynamic>?;
      if (data == null) return [];
      return data.map((e) => _parseDocument(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _getMockData();
    }
  }

  /// 获取文档详情
  Future<HistoryDocument?> getDocumentDetail(int id) async {
    try {
      final response = await ApiClient.instance.get(
        '${AppConstants.apiBaseUrl}/history/$id',
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      return _parseDocument(data);
    } catch (_) {
      return _getMockDetail(id);
    }
  }

  /// 获取文档内容
  Future<String> getDocumentContent(int id) async {
    try {
      final response = await ApiClient.instance.get(
        '${AppConstants.apiBaseUrl}/history/$id/content',
      );
      return response.data['data']?['content'] as String? ?? '';
    } catch (_) {
      return _getMockContent(id);
    }
  }

  /// 获取审校结果
  Future<ReviewResult?> getReviewResult(int id) async {
    try {
      final response = await ApiClient.instance.get(
        '${AppConstants.apiBaseUrl}/history/$id/review',
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      return _parseReview(data);
    } catch (_) {
      return _getMockReview(id);
    }
  }

  /// 删除文档
  Future<bool> deleteDocument(int id) async {
    try {
      await ApiClient.instance.delete('${AppConstants.apiBaseUrl}/history/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  HistoryDocument _parseDocument(Map<String, dynamic> json) {
    return HistoryDocument(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      docType: HistoryDocType.values.firstWhere(
        (e) => e.code == json['doc_type'],
        orElse: () => HistoryDocType.generated,
      ),
      status: DocStatus.values.firstWhere(
        (e) => e.code == json['status'],
        orElse: () => DocStatus.completed,
      ),
      category: DocCategory.values.firstWhere(
        (e) => e.label == json['category'],
        orElse: () => DocCategory.contract,
      ),
      wordCount: json['word_count'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      summary: json['summary'] as String?,
    );
  }

  ReviewResult _parseReview(Map<String, dynamic> json) {
    final issues = (json['issues'] as List<dynamic>?)
            ?.map((e) => ReviewIssue(
                  level: e['level'] as String? ?? 'info',
                  message: e['message'] as String? ?? '',
                  location: e['location'] as String? ?? '',
                ))
            .toList() ??
        [];
    return ReviewResult(
      passCount: json['pass_count'] as int? ?? 0,
      warnCount: json['warn_count'] as int? ?? 0,
      errorCount: json['error_count'] as int? ?? 0,
      issues: issues,
    );
  }

  // ── Mock Data ──

  List<HistoryDocument> _getMockData() {
    return const [
      HistoryDocument(
        id: 1,
        title: '技术开发合同 v2',
        docType: HistoryDocType.generated,
        status: DocStatus.completed,
        category: DocCategory.contract,
        wordCount: 2340,
        createdAt: '2026-05-09 10:30',
      ),
      HistoryDocument(
        id: 2,
        title: '项目可行性报告',
        docType: HistoryDocType.polished,
        status: DocStatus.completed,
        category: DocCategory.report,
        wordCount: 5600,
        createdAt: '2026-05-08 16:20',
      ),
      HistoryDocument(
        id: 3,
        title: '技术规格说明书 (EN)',
        docType: HistoryDocType.translated,
        status: DocStatus.completed,
        category: DocCategory.report,
        wordCount: 5200,
        createdAt: '2026-05-07 14:10',
      ),
      HistoryDocument(
        id: 4,
        title: '年度工作总结',
        docType: HistoryDocType.generated,
        status: DocStatus.completed,
        category: DocCategory.report,
        wordCount: 3200,
        createdAt: '2026-05-06 09:45',
      ),
      HistoryDocument(
        id: 5,
        title: '采购招标文件',
        docType: HistoryDocType.generated,
        status: DocStatus.processing,
        category: DocCategory.bid,
        wordCount: 0,
        createdAt: '2026-05-09 11:00',
      ),
      HistoryDocument(
        id: 6,
        title: '劳动合同模板',
        docType: HistoryDocType.polished,
        status: DocStatus.completed,
        category: DocCategory.contract,
        wordCount: 1800,
        createdAt: '2026-05-05 15:30',
      ),
      HistoryDocument(
        id: 7,
        title: '产品需求文档',
        docType: HistoryDocType.generated,
        status: DocStatus.failed,
        category: DocCategory.report,
        wordCount: 0,
        createdAt: '2026-05-04 11:20',
      ),
      HistoryDocument(
        id: 8,
        title: '会议纪要 - Q1复盘',
        docType: HistoryDocType.generated,
        status: DocStatus.completed,
        category: DocCategory.minutes,
        wordCount: 2100,
        createdAt: '2026-05-03 17:00',
      ),
    ];
  }

  HistoryDocument? _getMockDetail(int id) {
    final docs = _getMockData();
    return docs.where((d) => d.id == id).firstOrNull;
  }

  String _getMockContent(int id) {
    return '''### 一、合同双方

甲方（委托方）：XX科技有限公司
乙方（受托方）：YY信息技术有限公司

### 二、项目概述

甲方委托乙方进行智慧园区管理平台的开发工作，项目包含以下模块：
1. 园区设备管理子系统
2. 安防监控集成模块
3. 能源管理系统
4. 访客管理系统
5. 数据分析看板

### 三、合同金额

合同总金额为人民币壹佰贰拾万元整（¥1,200,000.00），按里程碑分三期支付。

### 四、项目工期

项目工期为6个月，自合同签订之日起计算。乙方应在工期届满前完成全部开发工作并通过甲方验收。

### 五、双方权利与义务

甲方应按合同约定及时支付项目款项，提供必要的需求文档和测试环境。乙方应按照技术规格书的要求完成开发工作，确保交付质量。

### 六、违约责任

任何一方违约，应向守约方支付合同总额10%的违约金。''';
  }

  ReviewResult? _getMockReview(int id) {
    return const ReviewResult(
      passCount: 3,
      warnCount: 2,
      errorCount: 0,
      issues: [
        ReviewIssue(level: 'pass', message: '必需章节完整性检查通过', location: '6/6 章节已包含'),
        ReviewIssue(level: 'pass', message: '格式规范检查通过', location: '全文'),
        ReviewIssue(level: 'pass', message: '条款逻辑一致性检查通过', location: '全文'),
        ReviewIssue(level: 'warn', message: '占位符未填充: {{甲方名称}}', location: '第一章 合同双方'),
        ReviewIssue(level: 'warn', message: '建议增加"保密条款"章节', location: '常见合同条款建议'),
      ],
    );
  }
}
