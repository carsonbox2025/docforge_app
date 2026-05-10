import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const String appName = '稿搭子';
  static const String appSlogan = '智能文档工坊';
  static const String appKey = 'docforge';

  // 通过 --dart-define=API_HOST=xxx 覆盖，否则按平台自动推断
  static const String _envHost = String.fromEnvironment('API_HOST');

  static String get apiSchemeAndHost {
    if (kIsWeb) return '';
    if (_envHost.isNotEmpty) return _envHost;
    // Android 模拟器用 10.0.2.2 访问宿主机
    if (!kReleaseMode && Platform.isAndroid) return 'http://10.0.2.2';
    if (kReleaseMode) return 'https://your-production-host.com';
    return 'http://localhost';
  }

  static const String apiBasePath = '/aistudio/service/docforge';

  // data source 使用：baseUrl 已包含完整路径，此处返回空字符串
  static const String apiBaseUrl = '';

  // BFF auth 路由：POST /aistudio/service/app/{appKey}/auth/login
  //                POST /aistudio/service/app/{appKey}/sms/send-code
  //                POST /aistudio/service/app/{appKey}/sms/verify-login
  static String get _appPrefix =>
      kIsWeb ? '/aistudio/service/app' : '$apiSchemeAndHost/aistudio/service/app';

  static String get apiLoginUrl => '$_appPrefix/$appKey/auth/login';
  static String get apiSmsSendCodeUrl => '$_appPrefix/$appKey/sms/send-code';
  static String get apiSmsVerifyLoginUrl => '$_appPrefix/$appKey/sms/verify-login';

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String themeKey = 'app_theme';

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
}
