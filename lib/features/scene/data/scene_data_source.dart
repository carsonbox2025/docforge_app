import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import 'models/scene_models.dart';

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

/// 场景 API 数据源
class SceneDataSource {
  final Dio _dio = ApiClient.instance.dio;

  /// 获取场景列表（带重试，应对首次请求后端冷启动）
  Future<List<SceneConfig>> listScenes() async {
    _log('[SceneDataSource] listScenes: requesting ${AppConstants.scenesListUrl}');
    const maxRetries = 3;
    DioException? lastError;

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await _dio.get(AppConstants.scenesListUrl);

        if (response.data is! Map<String, dynamic>) {
          throw Exception('场景接口返回非 JSON 数据，请检查后端路由配置');
        }

        final code = response.data['code'];
        if (code != null && code != 200 && code != 0) {
          throw Exception(response.data['message'] ?? '获取场景列表失败');
        }

        final data = response.data['data'];
        if (data is List) {
          final scenes = data
              .map((e) => SceneConfig.fromJson(e as Map<String, dynamic>))
              .toList();
          _log('[SceneDataSource] listScenes success: ${scenes.length} scenes loaded (attempt $attempt)');
          for (final s in scenes) {
            _log('[SceneDataSource]   - ${s.sceneId}: ${s.name} (docType=${s.docType}, layer=${s.layer})');
          }
          return scenes;
        }

        _log('[SceneDataSource] listScenes WARNING: response data is not a List, got ${data.runtimeType}');
        return [];
      } on DioException catch (e) {
        lastError = e;
        _log('[SceneDataSource] listScenes attempt $attempt/$maxRetries failed: '
            '${e.type}, statusCode=${e.response?.statusCode}');

        if (attempt < maxRetries) {
          final delay = Duration(seconds: attempt * 2);
          _log('[SceneDataSource] retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      } catch (e, st) {
        _log('[SceneDataSource] listScenes unexpected error (attempt $attempt): $e\n$st');
        if (attempt == maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    // 所有重试都失败
    _log('[SceneDataSource] listScenes exhausted all $maxRetries retries');
    throw lastError ?? Exception('获取场景列表失败');
  }

  /// 获取场景详情
  Future<SceneConfig?> getScene(String sceneId) async {
    _log('[SceneDataSource] getScene: sceneId=$sceneId');
    try {
      final response = await _dio.get(AppConstants.sceneDetailUrl(sceneId));

      if (response.data is! Map<String, dynamic>) {
        _log('[SceneDataSource] getScene ERROR: response is not JSON, got ${response.data.runtimeType}');
        throw Exception('场景详情接口返回非 JSON 数据');
      }

      final code = response.data['code'];
      if (code == 404) {
        _log('[SceneDataSource] getScene: scene $sceneId not found (404)');
        return null;
      }
      if (code != null && code != 200 && code != 0) {
        _log('[SceneDataSource] getScene FAILED: code=$code, message=${response.data['message']}');
        throw Exception(response.data['message'] ?? '获取场景详情失败');
      }
      final data = response.data['data'];
      if (data == null) return null;
      final scene = SceneConfig.fromJson(data as Map<String, dynamic>);
      _log('[SceneDataSource] getScene success: ${scene.sceneId} (${scene.name})');
      return scene;
    } on DioException catch (e) {
      _log('[SceneDataSource] getScene DioException: ${e.type}, statusCode=${e.response?.statusCode}');
      rethrow;
    } catch (e, st) {
      _log('[SceneDataSource] getScene unexpected error: $e\n$st');
      rethrow;
    }
  }
}
