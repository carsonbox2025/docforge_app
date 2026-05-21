import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/storage/local_cache.dart';
import 'core/network/api_client.dart';
import 'core/providers/core_providers.dart';
import 'core/iap/channel_detector.dart';
import 'features/auth/domain/providers/auth_provider.dart';
import 'app/app.dart';

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('=== FlutterError: ${details.exceptionAsString()} ===');
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
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

    runApp(const ProviderScope(child: _EagerInit(child: DocForgeApp())));
  }, (error, stack) {
    debugPrint('=== Uncaught Error: $error ===');
    debugPrint(stack.toString());
    FlutterError.presentError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
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
