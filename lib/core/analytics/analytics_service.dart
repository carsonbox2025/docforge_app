import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();

  // ignore: prefer_const_declarations
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    if (kDebugMode) {
      debugPrint('[Analytics] Debug mode — events logged locally only');
      _initialized = true;
      return;
    }

    final appKey = const String.fromEnvironment('UMENG_APPKEY');
    if (appKey.isEmpty) return;

    // 友盟 SDK 初始化通过 --dart-define=UMENG_APPKEY=xxx 注入
    // Release 构建时必须提供有效的 AppKey
    try {
      // umeng_common_sdk 会在 pubspec 中引入后实际调用
      // UmengSdk.init(appKey, channel: 'official');
      _initialized = true;
    } catch (_) {}
  }

  /// 追踪自定义事件
  static void track(String eventName, {Map<String, String>? properties}) {
    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('[Analytics] $eventName ${properties ?? {}}');
      }
      return;
    }

    try {
      // UmengSdk.onEvent(eventName, properties);
      if (kDebugMode) {
        debugPrint('[Analytics] $eventName ${properties ?? {}}');
      }
    } catch (_) {}
  }

  /// 追踪页面进入
  static void trackPageView(String pageName) {
    track('page_view', properties: {'page': pageName});
  }

  // ─── 业务事件快捷方法 ───

  static void generateStart(String sceneId, String docType, int layer) {
    track('generate_start', properties: {
      'scene_id': sceneId,
      'doc_type': docType,
      'layer': '$layer',
    });
  }

  static void generateComplete(String sceneId, int durationMs, int wordCount) {
    track('generate_complete', properties: {
      'scene_id': sceneId,
      'duration_ms': '$durationMs',
      'word_count': '$wordCount',
    });
  }

  static void polishStart(String docType, String level) {
    track('polish_start', properties: {
      'doc_type': docType,
      'polish_level': level,
    });
  }

  static void polishComplete(int durationMs) {
    track('polish_complete', properties: {
      'duration_ms': '$durationMs',
    });
  }

  static void translateStart(String sourceLang, String targetLang, String mode) {
    track('translate_start', properties: {
      'source_lang': sourceLang,
      'target_lang': targetLang,
      'mode': mode,
    });
  }

  static void translateComplete(int durationMs, int wordCount) {
    track('translate_complete', properties: {
      'duration_ms': '$durationMs',
      'word_count': '$wordCount',
    });
  }

  static void paymentView() {
    track('payment_view');
  }

  static void paymentSuccess(String channel, String amount, String planType) {
    track('payment_success', properties: {
      'channel': channel,
      'amount': amount,
      'plan_type': planType,
    });
  }
}
