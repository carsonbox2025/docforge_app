import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_cache.dart';
import '../../data/scene_data_source.dart';
import '../../data/models/scene_models.dart';

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

const _cacheKey = 'scene_list';
const _cacheTtl = Duration(hours: 1);

/// 场景列表 Provider（带本地缓存，TTL 1小时）
/// 注意：不用 autoDispose，避免切换 Tab 时反复销毁重建触发网络请求
final sceneListProvider =
    FutureProvider<List<SceneConfig>>((ref) async {
  // 尝试从本地缓存读取
  final cached = LocalCache.instance.getWithTtl<List<dynamic>>(_cacheKey);
  if (cached != null && cached.isNotEmpty) {
    try {
      final scenes = cached
          .map((e) => SceneConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      _log('[SceneProvider] loaded ${scenes.length} scenes from cache');
      return scenes;
    } catch (e) {
      _log('[SceneProvider] cache corrupted, clearing: $e');
      await LocalCache.instance.delete(_cacheKey);
    }
  }

  try {
    final scenes = await SceneDataSource().listScenes();

    // 写入本地缓存
    try {
      await LocalCache.instance.set(
        _cacheKey,
        scenes.map((s) => s.toJson()).toList(),
        ttl: _cacheTtl,
      );
    } catch (e) {
      _log('[SceneProvider] cache write failed: $e');
    }

    return scenes;
  } catch (e, st) {
    _log('[SceneProvider] FATAL: sceneListProvider failed: $e\n$st');
    rethrow;
  }
});

/// 单个场景 Provider
final sceneDetailProvider =
    FutureProvider.family<SceneConfig?, String>(
  (ref, sceneId) async {
    // 先从列表缓存中查找
    final list = await ref.watch(sceneListProvider.future);
    try {
      return list.firstWhere((s) => s.sceneId == sceneId);
    } catch (_) {
      return SceneDataSource().getScene(sceneId);
    }
  },
);

/// 当前选中的场景
final selectedSceneProvider = StateProvider<SceneConfig?>((ref) => null);
