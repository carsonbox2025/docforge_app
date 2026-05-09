import 'package:flutter/material.dart';

/// 消息类型枚举
enum NotificationType {
  docGenerated('doc_generated', '文档生成完成', Icons.description_outlined, Color(0xFF10B981), Color(0x0F10B981)),
  docPolished('doc_polished', '文档精修完成', Icons.auto_fix_high, Color(0xFF2563EB), Color(0x0F2563EB)),
  docTranslated('doc_translated', '翻译任务完成', Icons.translate, Color(0xFFF97316), Color(0x0FF97316)),
  quotaWarning('quota_warning', '配额提醒', Icons.warning_amber, Color(0xFFF59E0B), Color(0x0FF59E0B)),
  friendRegistered('friend_registered', '好友注册', Icons.person_add, Color(0xFF06B6D4), Color(0x0F06B6D4)),
  newTemplate('new_template', '新模板上线', Icons.dashboard_customize, Color(0xFF2563EB), Color(0x0F2563EB)),
  processFailed('process_failed', '处理失败', Icons.error_outline, Color(0xFFEF4444), Color(0x0FEF4444)),
  system('system', '系统通知', Icons.info_outline, Color(0xFF2563EB), Color(0x0F2563EB));

  const NotificationType(this.code, this.label, this.icon, this.color, this.bgColor);

  final String code;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
}

/// 消息分类 Tab
enum NotificationCategory {
  all('全部'),
  document('文档'),
  system('系统'),
  activity('活动');

  const NotificationCategory(this.label);
  final String label;
}

/// 时间分组
enum NotificationGroup {
  today('今天'),
  yesterday('昨天'),
  earlier('更早');

  const NotificationGroup(this.label);
  final String label;
}

/// 消息模型
class NotificationItem {
  final int id;
  final NotificationType type;
  final String title;
  final String description;
  final String time;
  final bool isRead;
  final String? actionLabel;
  final String? actionRoute;
  final NotificationGroup group;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.time,
    this.isRead = false,
    this.actionLabel,
    this.actionRoute,
    required this.group,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      description: description,
      time: time,
      isRead: isRead ?? this.isRead,
      actionLabel: actionLabel,
      actionRoute: actionRoute,
      group: group,
    );
  }
}
