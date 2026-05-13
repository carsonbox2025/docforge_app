import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_cache.dart';
import '../../data/scene_data_source.dart';
import '../../data/models/scene_models.dart';

const _cacheKey = 'scene_list';
const _cacheTtl = Duration(hours: 1);

/// 场景列表 Provider（带本地缓存，TTL 1小时）
final sceneListProvider =
    FutureProvider.autoDispose<List<SceneConfig>>((ref) async {
  // 尝试从本地缓存读取
  final cached = LocalCache.instance.getWithTtl<List<dynamic>>(_cacheKey);
  if (cached != null && cached.isNotEmpty) {
    try {
      return cached
          .map((e) => SceneConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // 缓存数据损坏，清除后重新请求
      await LocalCache.instance.delete(_cacheKey);
    }
  }

  final scenes = await SceneDataSource().listScenes();

  // 写入本地缓存
  try {
    await LocalCache.instance.set(
      _cacheKey,
      scenes.map((s) => s.toJson()).toList(),
      ttl: _cacheTtl,
    );
  } catch (_) {}

  return scenes;
});

/// 单个场景 Provider
final sceneDetailProvider =
    FutureProvider.autoDispose.family<SceneConfig?, String>(
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
