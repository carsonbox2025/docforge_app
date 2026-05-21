import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum IapChannel { huawei, xiaomi, oppo, vivo, honor, official }

abstract class ChannelDetector {
  static const _channel = MethodChannel('com.docforge.app/iap');
  static IapChannel? _cached;
  static Completer<void>? _initCompleter;

  static Future<void> init() async {
    if (_cached != null) return;
    if (_initCompleter != null) return await _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      if (!kIsWeb && Platform.isAndroid) {
        const buildChannel = String.fromEnvironment('CHANNEL');
        if (buildChannel.isNotEmpty) {
          _cached = IapChannel.values.firstWhere(
            (c) => c.name == buildChannel,
            orElse: () => IapChannel.official,
          );
        } else {
          try {
            final String? installer = await _channel.invokeMethod<String>('getInstallerPackageName');
            _cached = _mapInstaller(installer);
          } catch (_) {
            _cached = IapChannel.official;
          }
        }
      } else {
        _cached = IapChannel.official;
      }
      _initCompleter!.complete();
    } catch (e) {
      _cached = IapChannel.official;
      _initCompleter!.complete();
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
