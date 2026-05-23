import '../../../core/network/api_client.dart';

class SearchDataSource {
  Future<Map<String, dynamic>> searchDocuments({
    required String query,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await ApiClient.instance.get(
      '/document/search',
      queryParameters: {
        'q': query,
        'page': page,
        'page_size': pageSize,
      },
    );
    return response.data['data'] as Map<String, dynamic>? ?? {};
  }
}
