import 'package:flutter/foundation.dart';

class CrashReporter {
  CrashReporter._();

  // ignore: prefer_const_declarations
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    if (kDebugMode) return;

    final dsn = const String.fromEnvironment('SENTRY_DSN');
    if (dsn.isEmpty) {
      debugPrint('[CrashReporter] SENTRY_DSN not set — skipping');
      return;
    }

    try {
      // sentry_flutter SDK 初始化
      // 需要在 pubspec.yaml 中引入 sentry_flutter: ^8.14.0
      // await SentryFlutter.init(
      //   (options) {
      //     options.dsn = dsn;
      //     options.tracesSampleRate = 1.0;
      //     options.profilesSampleRate = 0.3;
      //   },
      // );
      _initialized = true;
      debugPrint('[CrashReporter] Initialized');
    } catch (e) {
      debugPrint('[CrashReporter] Init failed: $e');
    }
  }

  /// 记录 Flutter 框架错误
  static void recordFlutterError(FlutterErrorDetails details) {
    debugPrint('=== FlutterError: ${details.exceptionAsString()} ===');
    FlutterError.presentError(details);
    if (_initialized) {
      // Sentry.captureException(details.exception, stackTrace: details.stack);
    }
  }

  /// 记录未捕获错误
  static void recordError(Object error, StackTrace? stack) {
    debugPrint('=== Uncaught Error: $error ===');
    if (stack != null) debugPrint(stack.toString());
    if (_initialized) {
      // Sentry.captureException(error, stackTrace: stack);
    }
  }
}
