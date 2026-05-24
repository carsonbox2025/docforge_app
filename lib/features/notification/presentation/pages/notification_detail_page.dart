import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/notification_models.dart';
import '../../data/notification_data_source.dart';
import '../../domain/providers/notification_provider.dart';

class NotificationDetailPage extends ConsumerStatefulWidget {
  final int notificationId;
  const NotificationDetailPage({super.key, required this.notificationId});

  @override
  ConsumerState<NotificationDetailPage> createState() =>
      _NotificationDetailPageState();
}

class _NotificationDetailPageState
    extends ConsumerState<NotificationDetailPage> {
  NotificationItem? _item;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotification();
  }

  Future<void> _loadNotification() async {
    try {
      final ds = NotificationDataSource();
      final data = await ds.getNotificationById(widget.notificationId);
      if (!mounted) return;

      if (data != null) {
        final item = NotificationItem.fromApi(data);
        await ds.markAsRead(item.id);
        ref.invalidate(unreadCountProvider);
        setState(() { _item = item; _isLoading = false; });
      } else {
        setState(() { _error = '通知不存在'; _isLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = '加载失败'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('通知详情', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () { setState(() { _isLoading = true; _error = null; }); _loadNotification(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('重试'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('返回通知列表', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final item = _item!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeHeader(item),
          const SizedBox(height: AppSpacing.lg),
          _buildTitle(item),
          const SizedBox(height: AppSpacing.sm),
          _buildMeta(item),
          const SizedBox(height: AppSpacing.xl),
          _buildDivider(),
          const SizedBox(height: AppSpacing.xl),
          _buildDetailByType(item),
          if (_hasAction(item)) ...[
            const SizedBox(height: AppSpacing.xxl),
            _buildActionButton(item),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildTypeHeader(NotificationItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: item.type.bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.type.icon, size: 16, color: item.type.color),
          const SizedBox(width: 6),
          Text(
            item.type.label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: item.type.color),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(NotificationItem item) {
    return Text(
      item.title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.4),
    );
  }

  Widget _buildMeta(NotificationItem item) {
    return Row(
      children: [
        const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(item.time, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        if (!item.isRead) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('未读', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 1, color: AppColors.border);
  }

  Widget _buildDetailByType(NotificationItem item) {
    return switch (item.type) {
      NotificationType.docGenerated ||
      NotificationType.docPolished ||
      NotificationType.docTranslated =>
        _buildDocDetail(item),
      NotificationType.processFailed => _buildFailedDetail(item),
      NotificationType.quotaWarning => _buildQuotaDetail(item),
      NotificationType.system => _buildSystemDetail(item),
      NotificationType.friendRegistered => _buildFriendDetail(item),
      NotificationType.newTemplate => _buildTemplateDetail(item),
    };
  }

  Widget _buildDocDetail(NotificationItem item) {
    return _DetailCard(
      icon: Icons.description_outlined,
      iconColor: item.type.color,
      title: '文档处理完成',
      children: [
        if (item.description.isNotEmpty)
          Text(item.description, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 20, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('处理状态', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      item.type == NotificationType.docGenerated
                          ? '已生成完毕'
                          : item.type == NotificationType.docPolished
                              ? '已精修完毕'
                              : '已翻译完毕',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFailedDetail(NotificationItem item) {
    return _DetailCard(
      icon: Icons.error_outline,
      iconColor: AppColors.error,
      title: '处理失败',
      children: [
        if (item.description.isNotEmpty)
          Text(item.description, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.errorBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 20, color: AppColors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '文档处理过程中出现异常，请检查内容后重试',
                  style: const TextStyle(fontSize: 13, color: AppColors.error, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuotaDetail(NotificationItem item) {
    return _DetailCard(
      icon: Icons.warning_amber,
      iconColor: AppColors.warn,
      title: '配额提醒',
      children: [
        if (item.description.isNotEmpty)
          Text(item.description, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warnBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.warn.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.card_membership, size: 20, color: AppColors.warn),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '升级会员可获取更多生成次数，解锁全部文档模板',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemDetail(NotificationItem item) {
    return _DetailCard(
      icon: Icons.info_outline,
      iconColor: AppColors.primary,
      title: '系统通知',
      children: [
        Text(
          item.description.isNotEmpty ? item.description : '暂无详细内容',
          style: TextStyle(
            fontSize: 14,
            color: item.description.isNotEmpty ? AppColors.textSecondary : AppColors.textMuted,
            height: 1.8,
          ),
        ),
      ],
    );
  }

  Widget _buildFriendDetail(NotificationItem item) {
    return _DetailCard(
      icon: Icons.person_add,
      iconColor: const Color(0xFF06B6D4),
      title: '好友动态',
      children: [
        if (item.description.isNotEmpty)
          Text(item.description, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x0F06B6D4),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.share_outlined, size: 20, color: Color(0xFF06B6D4)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '邀请更多好友注册，共同体验智能文档服务',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateDetail(NotificationItem item) {
    return _DetailCard(
      icon: Icons.dashboard_customize,
      iconColor: AppColors.primary,
      title: '新模板上线',
      children: [
        if (item.description.isNotEmpty)
          Text(item.description, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '前往模板中心查看全部可用模板',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasAction(NotificationItem item) {
    if (item.actionRoute != null) return true;
    return switch (item.type) {
      NotificationType.docGenerated ||
      NotificationType.docPolished ||
      NotificationType.docTranslated =>
        true,
      NotificationType.processFailed => true,
      NotificationType.quotaWarning => true,
      NotificationType.newTemplate => true,
      NotificationType.system => false,
      NotificationType.friendRegistered => false,
    };
  }

  Widget _buildActionButton(NotificationItem item) {
    final (label, icon, route) = _getActionConfig(item);
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () {
          if (route != null) context.push(route);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          elevation: 0,
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }

  (String, IconData, String?) _getActionConfig(NotificationItem item) {
    if (item.actionRoute != null) {
      return (item.actionLabel ?? '查看详情', Icons.arrow_forward, item.actionRoute);
    }
    return switch (item.type) {
      NotificationType.docGenerated ||
      NotificationType.docPolished ||
      NotificationType.docTranslated =>
        ('查看文档', Icons.description_outlined, '/documents'),
      NotificationType.processFailed => ('重新生成', Icons.refresh, '/generate'),
      NotificationType.quotaWarning => ('查看会员', Icons.card_membership, '/subscription'),
      NotificationType.newTemplate => ('查看模板', Icons.dashboard_customize, '/templates'),
      NotificationType.system => ('确定', Icons.check, null),
      NotificationType.friendRegistered => ('确定', Icons.check, null),
    };
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  const _DetailCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}
