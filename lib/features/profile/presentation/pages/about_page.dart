import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/update/app_update_service.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _version = AppConstants.appVersion);
      }
    }
  }

  Future<void> _checkUpdate() async {
    try {
      final info = await AppUpdateService.instance.checkUpdate();
      if (!mounted) return;
      if (!info.hasUpdate) {
        final msg = info.error != null && info.error!.isNotEmpty
            ? '检查更新失败: ${info.error}'
            : '已是最新版本';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
        );
        return;
      }
      await AppUpdateService.instance.performUpdate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('关于${AppConstants.appName}'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.text,
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Logo
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.bolt, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 16),
            Text(AppConstants.appName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('版本 $_version',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 24),
            // 功能介绍
            _buildCard([
              _InfoRow(Icons.auto_awesome, '智能生成', 'AI 驱动，一键生成专业文档'),
              _InfoRow(Icons.auto_fix_high, '文档精修', '润色优化，提升文本质量'),
              _InfoRow(Icons.translate, '多语翻译', '支持中英日韩等多种语言'),
            ]),
            const SizedBox(height: 12),
            // 联系方式
            _buildCard([
              _InfoRow(Icons.language, '官网', AppConstants.officialWebsite),
              _InfoRow(Icons.email_outlined, '邮箱', AppConstants.supportEmail),
              _InfoRow(Icons.chat_outlined, '微信', AppConstants.wechatAccount),
            ]),
            const SizedBox(height: 12),
            // 法律条款
            _buildCard([
              _InfoRow(Icons.description_outlined, '用户协议', null,
                  onTap: () => context.push('/legal/terms')),
              _InfoRow(Icons.privacy_tip_outlined, '隐私协议', null,
                  onTap: () => context.push('/legal/privacy')),
            ]),
            const SizedBox(height: 12),
            _buildCard([
              _InfoRow(Icons.system_update_outlined, '检查更新', null,
                  onTap: _checkUpdate),
            ]),
            const SizedBox(height: 32),
            Text(
              '© 2026 ${AppConstants.appName} All Rights Reserved',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _launchUrl('https://beian.miit.gov.cn/'),
              child: const Text(
                '粤ICP备2026071158号',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _buildRow(rows[i]),
            if (i < rows.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Container(height: 0.5, color: AppColors.borderLight),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(_InfoRow row) {
    return InkWell(
      onTap: row.onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(row.icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(row.title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
            ),
            if (row.subtitle != null)
              Text(row.subtitle!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            if (row.onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _InfoRow(this.icon, this.title, this.subtitle, {this.onTap});
}
