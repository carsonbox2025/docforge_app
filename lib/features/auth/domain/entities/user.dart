class User {
  final String id;
  final String? userid;
  final String username;
  final String? email;
  final String? phone;
  final String role;

  const User({
    required this.id,
    this.userid,
    required this.username,
    this.email,
    this.phone,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  /// 是否为自动注册的临时账号（以 user_ 开头且无邮箱）
  bool get needsProfileSetup =>
      username.startsWith('user_') && (email == null || email!.isEmpty);
}
