import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/storage/local_cache.dart';
import 'core/network/api_client.dart';
import 'core/providers/core_providers.dart';
import 'core/iap/channel_detector.dart';
import 'core/iap/iap_receipt_queue.dart';
import 'core/analytics/crash_reporter.dart';
import 'core/analytics/analytics_service.dart';
import 'features/auth/domain/providers/auth_provider.dart';
import 'features/payment/data/payment_data_source.dart';
import 'app/app.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await CrashReporter.init();
    await AnalyticsService.init();

    try {
      await LocalCache.instance.init();
    } catch (e, st) {
      debugPrint('[Main] LocalCache init failed: $e\n$st');
    }

    try {
      await ChannelDetector.init();
    } catch (e, st) {
      debugPrint('[Main] ChannelDetector init failed: $e\n$st');
    }

    ApiClient.instance.init();

    // 初始化 IAP 掉单补偿队列，注入验票回调
    final paymentDs = PaymentDataSource();
    IapReceiptQueue.init((orderNo, receiptData) async {
      try {
        final order = await paymentDs.verifyOrder(orderNo, receiptData);
        return order.isPaid;
      } catch (_) {
        return false;
      }
    });
    // 启动后自动补单
    IapReceiptQueue.instance.processPendingQueue();

    FlutterError.onError = (details) {
      CrashReporter.recordFlutterError(details);
    };

    runApp(const ProviderScope(child: _EagerInit(child: DocForgeApp())));
  }, (error, stack) {
    debugPrint('=== Uncaught Error: $error ===');
    CrashReporter.recordError(error, stack);
  });
}

class _EagerInit extends ConsumerStatefulWidget {
  final Widget child;
  const _EagerInit({required this.child});

  @override
  ConsumerState<_EagerInit> createState() => _EagerInitState();
}

class _EagerInitState extends ConsumerState<_EagerInit> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ApiClient.instance.setUnauthorizedCallback(() {
        if (mounted) {
          ref.read(authProvider.notifier).forceClearSession();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(apiClientProvider);
    return widget.child;
  }
}
