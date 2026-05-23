class LoginRequest {
  final String identifier;
  final String password;

  LoginRequest({required this.identifier, required this.password});

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'password': password,
      };
}

class SetupProfileRequest {
  final String username;
  final String? email;
  final String? password;

  SetupProfileRequest({
    required this.username,
    this.email,
    this.password,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'username': username};
    if (email != null) map['email'] = email;
    if (password != null) map['password'] = password;
    return map;
  }
}

class SetPasswordRequest {
  final String password;
  final String code;

  SetPasswordRequest({required this.password, required this.code});

  Map<String, dynamic> toJson() => {'password': password, 'code': code};
}

class AuthResponse {
  final String token;
  final UserDto user;
  final bool isNewUser;

  AuthResponse({
    required this.token,
    required this.user,
    this.isNewUser = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['access_token'] as String,
        user: UserDto.fromJson(json['user'] as Map<String, dynamic>),
        isNewUser: json['is_new_user'] as bool? ?? false,
      );
}

class UserDto {
  final String id;
  final String? userid;
  final String username;
  final String? email;
  final String? phone;
  final String role;

  UserDto({
    required this.id,
    this.userid,
    required this.username,
    this.email,
    this.phone,
    required this.role,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
        id: json['id'] as String,
        userid: json['userid'] as String?,
        username: json['username'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String,
      );
}
