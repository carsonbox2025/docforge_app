import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_models.dart';
import '../../data/notification_data_source.dart';

class NotificationState {
  final NotificationCategory activeCategory;
  final List<NotificationItem> notifications;
  final bool isLoading;

  const NotificationState({
    this.activeCategory = NotificationCategory.unread,
    this.notifications = const [],
    this.isLoading = false,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  int get categoryBadgeCount {
    if (activeCategory == NotificationCategory.all) return unreadCount;
    return filteredNotifications.where((n) => !n.isRead).length;
  }

  List<NotificationItem> get filteredNotifications {
    switch (activeCategory) {
      case NotificationCategory.unread:
        return notifications.where((n) => !n.isRead).toList();
      case NotificationCategory.read:
        return notifications.where((n) => n.isRead).toList();
      case NotificationCategory.all:
        return notifications;
    }
  }

  Map<NotificationGroup, List<NotificationItem>> get groupedNotifications {
    final filtered = filteredNotifications;
    final map = <NotificationGroup, List<NotificationItem>>{};
    for (final group in NotificationGroup.values) {
      final items = filtered.where((n) => n.group == group).toList();
      if (items.isNotEmpty) {
        map[group] = items;
      }
    }
    return map;
  }

  NotificationState copyWith({
    NotificationCategory? activeCategory,
    List<NotificationItem>? notifications,
    bool? isLoading,
  }) {
    return NotificationState(
      activeCategory: activeCategory ?? this.activeCategory,
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationDataSource _dataSource;
  final Ref _ref;

  NotificationNotifier(this._dataSource, this._ref) : super(const NotificationState()) {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _dataSource.getNotifications(pageSize: 100);
      final items = (result['items'] as List? ?? [])
          .map((e) => NotificationItem.fromApi(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      state = state.copyWith(notifications: items, isLoading: false);
      _syncUnreadCount();
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  void setCategory(NotificationCategory category) {
    state = state.copyWith(activeCategory: category);
  }

  Future<void> markAsRead(int id) async {
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (n.id == id) return n.copyWith(isRead: true);
        return n;
      }).toList(),
    );
    try { await _dataSource.markAsRead(id); } catch (_) {}
    _syncUnreadCount();
  }

  Future<void> markAllAsRead() async {
    state = state.copyWith(
      notifications: state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
    );
    try { await _dataSource.markAllAsRead(); } catch (_) {}
    _syncUnreadCount();
  }

  void _syncUnreadCount() {
    _ref.invalidate(unreadCountProvider);
  }
}

// 全局未读数量 Provider（非 autoDispose）
final unreadCountProvider = FutureProvider<int>((ref) async {
  final ds = NotificationDataSource();
  return ds.getUnreadCount();
});

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(NotificationDataSource(), ref);
});
