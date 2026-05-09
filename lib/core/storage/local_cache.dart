import 'package:hive_flutter/hive_flutter.dart';

class LocalCache {
  LocalCache._();
  static final LocalCache instance = LocalCache._();

  static const _boxName = 'docforge_cache';

  late Box _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  T? get<T>(String key) => _box.get(key) as T?;

  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    if (ttl != null) {
      final wrapper = {
        'value': value,
        'expires_at': DateTime.now().add(ttl).millisecondsSinceEpoch,
      };
      await _box.put(key, wrapper);
    } else {
      await _box.put(key, value);
    }
  }

  T? getWithTtl<T>(String key) {
    final raw = _box.get(key);
    if (raw is Map && raw.containsKey('expires_at')) {
      final expiresAt = raw['expires_at'] as int;
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        _box.delete(key);
        return null;
      }
      return raw['value'] as T?;
    }
    return raw as T?;
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  Future<void> clear() => _box.clear();
}
