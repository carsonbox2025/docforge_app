class User {
  final String id;
  final String? userid;
  final String username;
  final String email;
  final String? phone;
  final String role;

  const User({
    required this.id,
    this.userid,
    required this.username,
    required this.email,
    this.phone,
    required this.role,
  });

  bool get isAdmin => role == 'admin';
}
