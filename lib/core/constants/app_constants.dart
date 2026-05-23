import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const String appName = '稿搭子';
  static const String appSlogan = '智能文档工坊';
  static const String appKey = 'docforge';
  static const String appVersion = '1.0.0';

  // 联系方式
  static const String officialWebsite = 'https://docforge.app';
  static const String supportEmail = 'support@docforge.app';
  static const String wechatAccount = 'DocForge_AI';

  // 通过 --dart-define=API_HOST=xxx 覆盖，否则按平台自动推断
  static const String _envHost = String.fromEnvironment('API_HOST');

  /// 后端服务 origin（scheme + host + port）
  static String get apiOrigin {
    if (_envHost.isNotEmpty) return _envHost;
    if (kIsWeb) return 'http://localhost:8000';
    if (!kReleaseMode && Platform.isAndroid) return 'http://10.0.2.2:8000';
    if (kReleaseMode) return 'http://61.132.52.22:8084';
    return 'http://localhost:8000';
  }

  // DocForge API 路径前缀
  static String get apiBasePath => '$apiOrigin/aistudio/service/docforge';

  // data source 使用：baseUrl 已包含完整路径，此处返回空字符串
  static const String apiBaseUrl = '';

  // BFF auth 路由：走 /aistudio/service/app/docforge/...
  static String get apiLoginUrl =>
      '$apiOrigin/aistudio/service/app/$appKey/auth/login';
  static String get apiRegisterUrl =>
      '$apiOrigin/aistudio/service/app/$appKey/auth/register';
  static String get apiGetMeUrl =>
      '$apiOrigin/aistudio/service/app/$appKey/auth/me';
  static String get apiSmsSendCodeUrl =>
      '$apiOrigin/aistudio/service/app/$appKey/sms/send-code';
  static String get apiSmsVerifyLoginUrl =>
      '$apiOrigin/aistudio/service/app/$appKey/sms/verify-login';

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String themeKey = 'app_theme';

  // Legal API (relative paths for Dio baseUrl)
  static String legalUrl(String type) => '/legal/$type';

  // Doc types
  static const List<String> docTypes = [
    'contract', 'bid', 'official', 'resume', 'paper', 'report', 'minutes', 'proposal',
  ];

  // Languages
  static const List<Map<String, String>> languages = [
    {'code': 'zh-CN', 'name': '中文'},
    {'code': 'en-US', 'name': 'English'},
    {'code': 'ja-JP', 'name': '日本語'},
    {'code': 'ko-KR', 'name': '한국어'},
    {'code': 'fr-FR', 'name': 'Français'},
    {'code': 'de-DE', 'name': 'Deutsch'},
  ];

  // Scene APIs
  static String get scenesListUrl => '$apiBasePath/scenes/list';
  static String sceneDetailUrl(String id) => '$apiBasePath/scenes/$id';
  static String sceneGenerateUrl(String id) =>
      '$apiBasePath/scenes/$id/generate';

  // Payment APIs (unified module)
  static String get paymentBase => '$apiOrigin/aistudio/service/payment';
  static String paymentProductsUrl(String channel) =>
      '$paymentBase/products?app_key=$appKey&channel=$channel';
  static String get paymentOrdersUrl => '$paymentBase/orders';
  static String paymentOrderUrl(String orderNo) =>
      '$paymentBase/orders/$orderNo';
  static String paymentOrderVerifyUrl(String orderNo) =>
      '$paymentBase/orders/$orderNo/verify';
  static String get paymentRestoreUrl => '$paymentBase/restore';
  static String get quotasMeUrl => '$apiBasePath/payment/quotas/me';

  // Quota APIs (relative paths for Dio baseUrl)
  static const String quotaUsageUrl = '/quota/usage';
  static const String quotaStatsUrl = '/quota/stats';

  // Notification APIs (relative paths for Dio baseUrl)
  static const String notificationsListUrl = '/notifications/list';
  static const String notificationsUnreadCountUrl = '/notifications/unread-count';
  static const String notificationsReadAllUrl = '/notifications/read-all';
  static String notificationReadUrl(int id) => '/notifications/$id/read';
  static String notificationDetailUrl(int id) => '/notifications/$id';

  // Feedback APIs
  static const String feedbackSubmitUrl = '/feedbacks';
  static const String feedbackListUrl = '/feedbacks/list';

  // Glossary APIs (relative paths for Dio baseUrl)
  static const String glossaryListUrl = '/glossary/list';
  static const String glossaryAddUrl = '/glossary/add';
  static String glossaryUpdateUrl(int id) => '/glossary/$id';
  static String glossaryDeleteUrl(int id) => '/glossary/$id';
}
