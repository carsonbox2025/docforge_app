import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../iap/channel_detector.dart';

class UpdateInfo {
  final bool hasUpdate;
  final bool isForce;
  final String? versionName;
  final int? size;
  final String? newFeatures;
  final String? error;

  const UpdateInfo({
    required this.hasUpdate,
    this.isForce = false,
    this.versionName,
    this.size,
    this.newFeatures,
    this.error,
  });
}

class AppUpdateService {
  static const _channel = MethodChannel('com.docforge.app/iap');

  static final AppUpdateService instance = AppUpdateService._();
  AppUpdateService._();

  Future<UpdateInfo> checkUpdate() async {
    final channel = ChannelDetector.detect();

    if (channel == IapChannel.huawei) {
      return _checkUpdateHuawei();
    }

    return const UpdateInfo(hasUpdate: false);
  }

  Future<void> performUpdate() async {
    final channel = ChannelDetector.detect();

    if (channel == IapChannel.huawei) {
      await _performUpdateHuawei();
    } else if (!kIsWeb && Platform.isAndroid) {
      await _launchStore(channel);
    } else if (!kIsWeb && Platform.isIOS) {
      await _launchAppStore();
    }
  }

  /// 在启动时调用：检查更新并自动弹出提示（非阻塞）
  Future<void> checkAndPrompt() async {
    try {
      final info = await checkUpdate();
      if (!info.hasUpdate) return;

      await performUpdate();
    } catch (e) {
      debugPrint('[AppUpdate] checkAndPrompt failed: $e');
    }
  }

  // ---- 华为 HMS SDK ----

  Future<UpdateInfo> _checkUpdateHuawei() async {
    try {
      final Map? result = await _channel.invokeMethod('checkUpdate', {
        'channel': 'huawei',
      });
      if (result == null) return const UpdateInfo(hasUpdate: false);

      return UpdateInfo(
        hasUpdate: result['hasUpdate'] as bool? ?? false,
        isForce: result['isForce'] as bool? ?? false,
        versionName: result['versionName'] as String?,
        size: result['size'] as int?,
        newFeatures: result['newFeatures'] as String?,
        error: result['error'] as String?,
      );
    } on PlatformException catch (e) {
      debugPrint('[AppUpdate] Huawei checkUpdate failed: ${e.message}');
      return UpdateInfo(hasUpdate: false, error: e.message);
    }
  }

  Future<void> _performUpdateHuawei() async {
    try {
      await _channel.invokeMethod('performUpdate', {
        'channel': 'huawei',
      });
    } on PlatformException catch (e) {
      debugPrint('[AppUpdate] Huawei performUpdate failed: ${e.message}');
    }
  }

  // ---- 跳转各厂商商店 ----

  Future<void> _launchStore(IapChannel channel) async {
    final storeUrl = _storeUrlForChannel(channel);
    if (storeUrl == null) return;

    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _storeUrlForChannel(IapChannel channel) {
    switch (channel) {
      case IapChannel.xiaomi:
        return 'mimarket://details?id=com.docforge.app.xiaomi';
      case IapChannel.oppo:
        return 'oppomarket://details?packagename=com.docforge.app.oppo';
      case IapChannel.vivo:
        return 'vivomarket://details?id=com.docforge.app.vivo';
      case IapChannel.honor:
        return 'honorappmarket://details?id=com.docforge.app.honor';
      case IapChannel.huawei:
        // 华为走 HMS SDK，不跳转商店
        return null;
      case IapChannel.official:
        return null;
    }
  }

  Future<void> _launchAppStore() async {
    // TODO: 替换为实际 App Store ID
    const appStoreUrl = 'https://apps.apple.com/app/idYOUR_APP_ID';
    final uri = Uri.parse(appStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
