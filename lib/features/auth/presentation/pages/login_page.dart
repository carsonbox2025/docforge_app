import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
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
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
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
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的手机号')),
      );
      return;
    }
    try {
      await ref.read(authProvider.notifier).sendSmsCode(phone);
      setState(() { _countdown = 60; });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() { _countdown--; });
        if (_countdown <= 0) t.cancel();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }

  Future<void> _login() async {
    if (_showSmsLogin) {
      final phone = _phoneController.text.trim();
      final code = _codeController.text.trim();
      if (phone.isEmpty || code.isEmpty) return;
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

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        _persistCredentials();
        context.go('/');
      } else if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
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
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: const Center(
            child: Icon(Icons.bolt, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 16),
        const Text('稿搭子', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text('AI 驱动的专业文档生成平台', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildPasswordForm(bool isLoading) {
    return Column(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('账号', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _identifierController,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              decoration: const InputDecoration(hintText: '用户名 / 手机号 / 邮箱'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('密码', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              decoration: const InputDecoration(hintText: '请输入密码'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
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
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _login,
            child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('登 录'),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _showSmsLogin = true),
          child: const Text(
            '手机验证码登录',
            style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildSmsForm(bool isLoading) {
    return Column(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('手机号', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('验证码', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                suffixIcon: GestureDetector(
                  onTap: _countdown > 0 ? null : _sendCode,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12, top: 16, bottom: 16),
                    child: Text(
                      _countdown > 0 ? '${_countdown}s' : '获取验证码',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _countdown > 0 ? AppColors.textMuted : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _login,
            child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('登 录'),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _showSmsLogin = false),
          child: const Text(
            '密码登录',
            style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('还没有账号？', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        GestureDetector(
          onTap: () => context.go('/register'),
          child: const Text('立即注册', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
