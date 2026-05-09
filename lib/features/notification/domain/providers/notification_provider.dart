import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_models.dart';

class NotificationState {
  final NotificationCategory activeCategory;
  final List<NotificationItem> notifications;
  final bool isLoading;

  const NotificationState({
    this.activeCategory = NotificationCategory.all,
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
      case NotificationCategory.all:
        return notifications;
      case NotificationCategory.document:
        return notifications.where((n) =>
            n.type == NotificationType.docGenerated ||
            n.type == NotificationType.docPolished ||
            n.type == NotificationType.docTranslated ||
            n.type == NotificationType.processFailed
        ).toList();
      case NotificationCategory.system:
        return notifications.where((n) =>
            n.type == NotificationType.quotaWarning ||
            n.type == NotificationType.system
        ).toList();
      case NotificationCategory.activity:
        return notifications.where((n) =>
            n.type == NotificationType.friendRegistered ||
            n.type == NotificationType.newTemplate
        ).toList();
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
  NotificationNotifier() : super(const NotificationState()) {
    _loadMockData();
  }

  void setCategory(NotificationCategory category) {
    state = state.copyWith(activeCategory: category);
  }

  void markAsRead(int id) {
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (n.id == id) return n.copyWith(isRead: true);
        return n;
      }).toList(),
    );
  }

  void markAllAsRead() {
    state = state.copyWith(
      notifications: state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
    );
  }

  void _loadMockData() {
    state = state.copyWith(
      notifications: [
        // 今天
        NotificationItem(
          id: 1,
          type: NotificationType.docGenerated,
          title: '文档生成完成',
          description: '您的合同文档《技术开发合同_v2》已生成完毕，共 2,340 字，点击查看详情。',
          time: '10 分钟前',
          isRead: false,
          actionLabel: '查看文档',
          actionRoute: '/history/1',
          group: NotificationGroup.today,
        ),
        NotificationItem(
          id: 2,
          type: NotificationType.docPolished,
          title: '文档精修完成',
          description: '您的文档《项目可行性报告》润色完成，共优化 12 处，建议查看修订对比。',
          time: '30 分钟前',
          isRead: false,
          actionLabel: '查看修订',
          actionRoute: '/history/2',
          group: NotificationGroup.today,
        ),
        NotificationItem(
          id: 3,
          type: NotificationType.quotaWarning,
          title: '配额即将用尽',
          description: '您本月免费生成次数仅剩 1 次，升级 Pro 可解锁无限次生成。',
          time: '1 小时前',
          isRead: false,
          actionLabel: '升级 Pro',
          actionRoute: '/subscription',
          group: NotificationGroup.today,
        ),
        NotificationItem(
          id: 4,
          type: NotificationType.newTemplate,
          title: '新模板上线',
          description: '新增「招投标文件」模板，适用于政府采购和工程项目投标。',
          time: '2 小时前',
          isRead: true,
          actionLabel: '查看模板',
          actionRoute: '/templates',
          group: NotificationGroup.today,
        ),
        // 昨天
        NotificationItem(
          id: 5,
          type: NotificationType.docTranslated,
          title: '翻译任务完成',
          description: '您的文档翻译任务已完成：中文 → English，《技术规格说明书》共翻译 5,200 字。',
          time: '昨天 16:30',
          isRead: true,
          actionLabel: '查看翻译',
          actionRoute: '/history/3',
          group: NotificationGroup.yesterday,
        ),
        NotificationItem(
          id: 6,
          type: NotificationType.friendRegistered,
          title: '好友注册奖励',
          description: '您邀请的好友「李明」已成功注册，您获得 2 次额外生成额度。',
          time: '昨天 11:20',
          isRead: true,
          group: NotificationGroup.yesterday,
        ),
        // 更早
        NotificationItem(
          id: 7,
          type: NotificationType.processFailed,
          title: '文档处理失败',
          description: '您的文档《年度总结报告》在精修过程中遇到错误，请检查文档格式后重试。',
          time: '3天前',
          isRead: true,
          actionLabel: '重试',
          actionRoute: '/polish',
          group: NotificationGroup.earlier,
        ),
        NotificationItem(
          id: 8,
          type: NotificationType.system,
          title: '系统维护通知',
          description: '系统将于本周六 02:00-04:00 进行例行维护，届时服务将短暂不可用。',
          time: '5天前',
          isRead: true,
          group: NotificationGroup.earlier,
        ),
      ],
    );
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier();
});
