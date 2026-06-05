import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/repositories/auth_repository.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  int _countdown = 0;
  Timer? _timer;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _timer?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) return;
    try {
      await ref.read(authProvider.notifier).sendSmsCode(phone, type: 'register');
      setState(() { _countdown = 60; });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() { _countdown--; });
        if (_countdown <= 0) t.cancel();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败: $e')));
      }
    }
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || email.isEmpty || phone.isEmpty || code.isEmpty) return;
    await ref.read(authProvider.notifier).register(username, email, phone, password, code);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/');
      } else if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('注册'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('创建账号', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('注册后即可使用文档工坊的全部功能', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 32),

              const Text('用户名', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _usernameController,
                maxLength: 50,
                decoration: const InputDecoration(hintText: '请输入用户名（2-50位）', counterText: ''),
              ),
              const SizedBox(height: 16),

              const Text('邮箱', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: '请输入邮箱'),
              ),
              const SizedBox(height: 16),

              const Text('手机号', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: const InputDecoration(hintText: '请输入手机号', counterText: ''),
              ),
              const SizedBox(height: 16),

              const Text('验证码', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: '请输入6位验证码',
                  counterText: '',
                  suffixIcon: GestureDetector(
                    onTap: _countdown > 0 ? null : _sendCode,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, top: 16, bottom: 16),
                      child: Text(
                        _countdown > 0 ? '${_countdown}s' : '获取验证码',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _countdown > 0 ? AppColors.textMuted : AppColors.primary),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text('密码（可选）', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '设置登录密码（可选）'),
              ),
              const SizedBox(height: 24),

              // 隐私协议
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18, height: 18,
                    child: Checkbox(
                      value: _agreedToTerms,
                      onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                      activeColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      children: [
                        Text('我已阅读并同意', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        GestureDetector(
                          onTap: () => context.push('/legal/terms'),
                          child: Text('《用户协议》', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                        Text('和', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        GestureDetector(
                          onTap: () => context.push('/legal/privacy'),
                          child: Text('《隐私协议》', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (authState.isLoading || !_agreedToTerms) ? null : _register,
                  child: authState.isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('注 册'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
