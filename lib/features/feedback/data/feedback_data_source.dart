import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import 'models/feedback_models.dart';

class FeedbackDataSource {
  Future<void> submit({
    required String type,
    required String content,
    String? contact,
  }) async {
    await ApiClient.instance.post(
      AppConstants.feedbackSubmitUrl,
      data: {
        'type': type,
        'content': content,
        if (contact != null) 'contact': contact,
      },
    );
  }

  Future<List<FeedbackRecord>> getMyFeedbacks({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await ApiClient.instance.get(
      AppConstants.feedbackListUrl,
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final items = data['items'] as List? ?? [];
    return items
        .map((e) => FeedbackRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
