class LoginRequest {
  final String identifier;
  final String password;

  LoginRequest({required this.identifier, required this.password});

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'password': password,
      };
}

class RegisterRequest {
  final String username;
  final String email;
  final String phone;
  final String password;

  RegisterRequest({
    required this.username,
    required this.email,
    required this.phone,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
      };
}

class AuthResponse {
  final String token;
  final UserDto user;
  final String? currentWorkshopId;
  final String? workshopRole;

  AuthResponse({
    required this.token,
    required this.user,
    this.currentWorkshopId,
    this.workshopRole,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['access_token'] as String,
        user: UserDto.fromJson(json['user'] as Map<String, dynamic>),
        currentWorkshopId: json['current_workshop_id'] as String?,
        workshopRole: json['workshop_role'] as String?,
      );
}

class UserDto {
  final String id;
  final String? userid;
  final String username;
  final String email;
  final String? phone;
  final String role;

  UserDto({
    required this.id,
    this.userid,
    required this.username,
    required this.email,
    this.phone,
    required this.role,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
        id: json['id'] as String,
        userid: json['userid'] as String?,
        username: json['username'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        role: json['role'] as String,
      );
}
