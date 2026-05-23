import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/auth_remote_data_source.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

enum _Step { inputPhone, resetPassword, success }

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dataSource = AuthRemoteDataSource();

  _Step _step = _Step.inputPhone;
  int _countdown = 0;
  Timer? _timer;
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      _showError('请输入正确的手机号');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _dataSource.sendForgotPasswordCode(phone);
      if (mounted) {
        _showSuccess('验证码已发送');
        setState(() {
          _countdown = 60;
          _step = _Step.resetPassword;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          setState(() {
            _countdown--;
          });
          if (_countdown <= 0) t.cancel();
        });
      }
    } catch (e) {
      if (mounted) _showError('发送失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (code.isEmpty || code.length != 6) {
      _showError('请输入6位验证码');
      return;
    }
    if (password.length < 6) {
      _showError('密码至少6位');
      return;
    }
    if (password != confirm) {
      _showError('两次密码不一致');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _dataSource.resetPassword(phone, code, password);
      if (mounted) setState(() => _step = _Step.success);
    } catch (e) {
      if (mounted) _showError('重置失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.text,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '忘记密码',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _step == _Step.success ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text('重置密码', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          _step == _Step.inputPhone ? '输入注册手机号，获取验证码' : '输入验证码并设置新密码',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 32),

        const Text('手机号', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          enabled: _step == _Step.inputPhone,
          decoration: const InputDecoration(hintText: '请输入注册手机号', counterText: ''),
        ),
        const SizedBox(height: 16),

        if (_step == _Step.resetPassword) ...[
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
                    _countdown > 0 ? '${_countdown}s' : '重新发送',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _countdown > 0 ? AppColors.textMuted : AppColors.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('新密码', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              hintText: '请输入新密码（至少6位）',
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('确认密码', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              hintText: '请再次输入新密码',
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : (_step == _Step.inputPhone ? _sendCode : _resetPassword),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_step == _Step.inputPhone ? '获取验证码' : '重置密码', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const SizedBox(height: 60),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline, size: 40, color: AppColors.success),
        ),
        const SizedBox(height: 20),
        const Text('密码重置成功', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('请使用新密码登录', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('返回登录', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
