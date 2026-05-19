import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';

class NotificationDataSource {
  Future<Map<String, dynamic>> getNotifications({
    String category = 'all',
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await ApiClient.instance.get(
      AppConstants.notificationsListUrl,
      queryParameters: {
        'category': category,
        'page': page,
        'page_size': pageSize,
      },
    );
    return response.data['data'] as Map<String, dynamic>? ?? {};
  }

  Future<int> getUnreadCount() async {
    try {
      final response =
          await ApiClient.instance.get(AppConstants.notificationsUnreadCountUrl);
      return response.data['data']['unread_count'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAsRead(int id) async {
    await ApiClient.instance.post(AppConstants.notificationReadUrl(id));
  }

  Future<void> markAllAsRead() async {
    await ApiClient.instance.post(AppConstants.notificationsReadAllUrl);
  }
}
