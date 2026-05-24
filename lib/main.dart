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

Future<void> _withTimeout(Future<void> Function() fn, String label, {Duration timeout = const Duration(seconds: 3)}) async {
  try {
    debugPrint('[Main] $label start');
    await fn().timeout(timeout);
    debugPrint('[Main] $label done');
  } catch (e) {
    debugPrint('[Main] $label failed: $e');
  }
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await _withTimeout(() => CrashReporter.init(), 'CrashReporter');
    await _withTimeout(() => AnalyticsService.init(), 'Analytics');

    await _withTimeout(() => LocalCache.instance.init(), 'LocalCache');

    await _withTimeout(() => ChannelDetector.init(), 'ChannelDetector');

    ApiClient.instance.init();

    final paymentDs = PaymentDataSource();
    IapReceiptQueue.init((orderNo, receiptData) async {
      try {
        final order = await paymentDs.verifyOrder(orderNo, receiptData);
        return order.isPaid;
      } catch (_) {
        return false;
      }
    });
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
