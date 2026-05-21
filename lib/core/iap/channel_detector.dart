import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum IapChannel { huawei, xiaomi, oppo, vivo, honor, official }

abstract class ChannelDetector {
  static const _channel = MethodChannel('com.docforge.app/iap');
  static IapChannel? _cached;

  static Future<void> init() async {
    if (_cached != null) return;

    if (!kIsWeb && Platform.isAndroid) {
      // 1. 优先读打包时注入的渠道标记
      const buildChannel = String.fromEnvironment('CHANNEL');
      if (buildChannel.isNotEmpty) {
        _cached = IapChannel.values.firstWhere(
          (c) => c.name == buildChannel,
          orElse: () => IapChannel.official,
        );
        return;
      }

      // 2. 通过 Platform Channel 检测安装来源
      try {
        final String? installer = await _channel.invokeMethod<String>('getInstallerPackageName');
        _cached = _mapInstaller(installer);
      } catch (_) {
        _cached = IapChannel.official;
      }
    } else {
      _cached = IapChannel.official;
    }
  }

  static IapChannel detect() {
    return _cached ?? IapChannel.official;
  }

  static IapChannel _mapInstaller(String? installer) {
    if (installer == null || installer.isEmpty) return IapChannel.official;
    final map = {
      'com.huawei.appmarket': IapChannel.huawei,
      'com.xiaomi.market': IapChannel.xiaomi,
      'com.heytap.market': IapChannel.oppo,
      'com.bbk.appstore': IapChannel.vivo,
      'com.hihonor.appmarket': IapChannel.honor,
    };
    return map[installer] ?? IapChannel.official;
  }

  static bool get isIap => detect() != IapChannel.official;
}
