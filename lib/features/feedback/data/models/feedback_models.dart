import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

enum FeedbackType { suggestion, bug, other }

class FeedbackTypeOption {
  final FeedbackType type;
  final String label;
  final IconData icon;
  const FeedbackTypeOption(this.type, this.label, this.icon);
}

const feedbackTypeOptions = [
  FeedbackTypeOption(FeedbackType.suggestion, '功能建议', Icons.lightbulb_outline),
  FeedbackTypeOption(FeedbackType.bug, 'Bug反馈', Icons.bug_report_outlined),
  FeedbackTypeOption(FeedbackType.other, '其他', Icons.more_horiz),
];

class FeedbackRecord {
  final int id;
  final String type;
  final String content;
  final String? contact;
  final String status;
  final String? adminReply;
  final String? createdAt;

  const FeedbackRecord({
    required this.id,
    required this.type,
    required this.content,
    this.contact,
    this.status = 'pending',
    this.adminReply,
    this.createdAt,
  });

  String get statusLabel => const {
        'pending': '待处理',
        'processing': '处理中',
        'resolved': '已解决',
        'closed': '已关闭',
      }[status] ??
      status;

  Color get statusColor => const {
        'pending': AppColors.warn,
        'processing': AppColors.primary,
        'resolved': AppColors.success,
        'closed': AppColors.textMuted,
      }[status] ??
      AppColors.textMuted;

  Color get statusBgColor => const {
        'pending': AppColors.warnBg,
        'processing': AppColors.primaryBg,
        'resolved': AppColors.successBg,
        'closed': AppColors.borderLight,
      }[status] ??
      AppColors.borderLight;

  factory FeedbackRecord.fromJson(Map<String, dynamic> json) => FeedbackRecord(
        id: json['id'] as int,
        type: json['type'] as String? ?? 'suggestion',
        content: json['content'] as String? ?? '',
        contact: json['contact'] as String?,
        status: json['status'] as String? ?? 'pending',
        adminReply: json['admin_reply'] as String?,
        createdAt: json['created_at'] as String?,
      );
}
