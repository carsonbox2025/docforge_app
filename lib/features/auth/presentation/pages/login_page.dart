import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/storage/secure_storage.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _showSmsLogin = false;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _mockCode;
  bool _codeSent = false;
  final _passwordFocus = FocusNode();
  int _countdown = 0;
  Timer? _timer;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final (identifier, password) = await SecureStorage.instance.getSavedCredentials();
    if (identifier != null && password != null) {
      _identifierController.text = identifier;
      _passwordController.text = password;
      if (mounted) setState(() => _rememberMe = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      _showTip('请输入正确的手机号');
      return;
    }
    try {
      final resp = await ref.read(authProvider.notifier).sendSmsCode(phone);
      if (resp['mock_code'] != null) {
        setState(() { _mockCode = resp['mock_code'] as String; });
      }
      setState(() { _codeSent = true; _countdown = 60; });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() { _countdown--; });
        if (_countdown <= 0) t.cancel();
      });
    } catch (e) {
      if (mounted) _showTip('发送失败: $e');
    }
  }

  Future<void> _login() async {
    if (_showSmsLogin) {
      final phone = _phoneController.text.trim();
      final code = _codeController.text.trim();
      if (phone.isEmpty) {
        _showTip('请输入手机号');
        return;
      }
      if (!_codeSent) {
        _showTip('请先获取验证码');
        return;
      }
      if (code.isEmpty) {
        _showTip('请输入验证码');
        return;
      }
      if (code.length < 6) {
        _showTip('验证码为 6 位数字');
        return;
      }
      await ref.read(authProvider.notifier).loginWithSms(phone, code);
    } else {
      final identifier = _identifierController.text.trim();
      final pwd = _passwordController.text;
      if (identifier.isEmpty || pwd.isEmpty) return;
      await ref.read(authProvider.notifier).loginWithPassword(identifier, pwd);
    }
  }

  Future<void> _persistCredentials() async {
    if (_rememberMe && !_showSmsLogin) {
      final id = _identifierController.text.trim();
      final pwd = _passwordController.text;
      if (id.isNotEmpty && pwd.isNotEmpty) {
        await SecureStorage.instance.saveCredentials(id, pwd);
      }
    } else {
      await SecureStorage.instance.clearCredentials();
    }
  }

  void _showTip(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        debugPrint('[Login] authenticated: isNewUser=${next.isNewUser}');
        _persistCredentials();
        if (next.isNewUser) {
          context.go('/profile-setup');
        } else {
          context.go('/');
        }
      } else if (next.status == AuthStatus.error && next.errorMessage != null) {
        _showTip(next.errorMessage!);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildBrand(),
              const SizedBox(height: 40),
              if (!_showSmsLogin) _buildPasswordForm(isLoading),
              if (_showSmsLogin) _buildSmsForm(isLoading),
              const SizedBox(height: 24),
              _buildFooter(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          width: 72, height: 72,
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
        const Text('文档工坊',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text('AI 驱动的专业文档生成平台',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSmsForm(bool isLoading) {
    return Column(
      children: [
        if (_mockCode != null) _buildMockBanner(),
        if (_mockCode != null) const SizedBox(height: 16),
        _buildFieldLabel('手机号'),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _codeFocus.requestFocus(),
          decoration: const InputDecoration(
            hintText: '请输入手机号',
            counterText: '',
            prefixIcon: Icon(Icons.phone_android, size: 20, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 16),
        _buildFieldLabel('验证码'),
        const SizedBox(height: 6),
        TextField(
          controller: _codeController,
          focusNode: _codeFocus,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
          decoration: InputDecoration(
            hintText: '请输入6位验证码',
            counterText: '',
            prefixIcon: const Icon(Icons.shield_outlined, size: 20, color: AppColors.textMuted),
            suffixIcon: _buildSendCodeButton(),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _login,
            child: isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('登录 / 注册'),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _showSmsLogin = false),
          child: Text(
            '使用密码登录',
            style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordForm(bool isLoading) {
    return Column(
      children: [
        _buildFieldLabel('账号'),
        const SizedBox(height: 6),
        TextField(
          controller: _identifierController,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          decoration: const InputDecoration(
            hintText: '用户名 / 手机号 / 邮箱',
            prefixIcon: Icon(Icons.person_outline, size: 20, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 16),
        _buildFieldLabel('密码'),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
          decoration: const InputDecoration(
            hintText: '请输入密码',
            prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppColors.textMuted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              SizedBox(
                width: 18, height: 18,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Text('记住密码',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
        // 忘记密码
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => context.push('/forgot-password'),
            child: const Text('忘记密码？',
                style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _login,
            child: isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('登 录'),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _showSmsLogin = true),
          child: Text(
            '手机验证码登录',
            style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Text(
            '登录即代表同意',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              _buildLegalLink('《用户协议》', 'terms'),
              Text(' 和 ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              _buildLegalLink('《隐私协议》', 'privacy'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }

  Widget _buildSendCodeButton() {
    final enabled = _countdown <= 0;
    return GestureDetector(
      onTap: enabled ? _sendCode : null,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, top: 16, bottom: 16),
        child: Text(
          _countdown > 0 ? '${_countdown}s' : '获取验证码',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildLegalLink(String text, String type) {
    return GestureDetector(
      onTap: () => context.push('/legal/$type'),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildMockBanner() {
    final code = _mockCode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warn.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: AppColors.warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              code != null
                  ? '测试模式：验证码 $code'
                  : '测试模式：请先获取验证码',
              style: TextStyle(fontSize: 12, color: AppColors.warn, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
