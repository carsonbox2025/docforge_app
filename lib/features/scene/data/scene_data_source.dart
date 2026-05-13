import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import 'models/scene_models.dart';

/// 场景 API 数据源
class SceneDataSource {
  final Dio _dio = ApiClient.instance.dio;

  /// 获取场景列表
  Future<List<SceneConfig>> listScenes() async {
    final response = await _dio.get(AppConstants.scenesListUrl);
    final code = response.data['code'];
    if (code != null && code != 200 && code != 0) {
      throw Exception(response.data['message'] ?? '获取场景列表失败');
    }
    final data = response.data['data'];
    if (data is List) {
      return data
          .map((e) => SceneConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 获取场景详情
  Future<SceneConfig?> getScene(String sceneId) async {
    final response = await _dio.get(AppConstants.sceneDetailUrl(sceneId));
    final code = response.data['code'];
    if (code == 404) return null;
    if (code != null && code != 200 && code != 0) {
      throw Exception(response.data['message'] ?? '获取场景详情失败');
    }
    final data = response.data['data'];
    if (data == null) return null;
    return SceneConfig.fromJson(data as Map<String, dynamic>);
  }
}
