import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../auth/domain/providers/auth_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _pushNotification = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.text,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '设置',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppColors.borderLight, height: 0.5),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildSection([
            _SettingsTile(
              icon: Icons.person_outline,
              title: '编辑资料',
              trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
              onTap: () => context.push('/profile-setup'),
            ),
            _SettingsTile(
              icon: Icons.language,
              title: '语言',
              trailing: _trailingText('中文'),
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.dark_mode_outlined,
              title: '深色模式',
              trailing: _buildSwitch(
                ref.watch(themeModeProvider) == ThemeMode.dark,
                (v) => ref.read(themeModeProvider.notifier).setMode(
                  v ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: '推送通知',
              trailing: _buildSwitch(_pushNotification, (v) => setState(() => _pushNotification = v)),
            ),
          ]),
          const SizedBox(height: 12),
          _buildSection([
            _SettingsTile(
              icon: Icons.cleaning_services_outlined,
              title: '清除缓存',
              trailing: _trailingText('12.3 MB'),
              onTap: () {
                _showClearCacheDialog(context);
              },
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: '关于',
              trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
              onTap: () => context.push('/about'),
            ),
          ]),
          const SizedBox(height: 32),
          _buildSection([
            _SettingsTile(
              icon: Icons.delete_forever_outlined,
              title: '注销账号',
              titleColor: AppColors.error,
              trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
              onTap: () => _showDeleteAccountDialog(context),
            ),
          ]),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('注销账号', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
        content: const Text(
          '确定要注销账号吗？\n\n'
          '注销后：\n'
          '• 文档数据将被清除\n'
          '• 会员权益将失效\n'
          '• 30天内可恢复\n'
          '• 超30天不可恢复\n\n'
          '此操作不可撤销，请谨慎决定。',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).deleteAccount();
            },
            child: const Text('确认注销', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(List<Widget> tiles) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Container(height: 0.5, color: AppColors.borderLight),
              ),
          ],
        ],
      ),
    );
  }

  Widget _trailingText(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
      ],
    );
  }

  Widget _buildSwitch(bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      height: 28,
      child: FittedBox(
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text(
          '清除缓存',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        content: const Text(
          '确定要清除所有缓存数据吗？',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('缓存已清除'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('确定', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? AppColors.text,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
