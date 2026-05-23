import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';

enum AuthStatus { initial, restoring, loading, authenticated, unauthenticated, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final String? token;
  final String? errorMessage;
  final bool isNewUser;
  final bool needsOnboarding;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.token,
    this.errorMessage,
    this.isNewUser = false,
    this.needsOnboarding = false,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading || status == AuthStatus.restoring;
  bool get isRestoring => status == AuthStatus.restoring;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? token,
    String? errorMessage,
    bool? isNewUser,
    bool? needsOnboarding,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        token: token ?? this.token,
        errorMessage: errorMessage ?? this.errorMessage,
        isNewUser: isNewUser ?? this.isNewUser,
        needsOnboarding: needsOnboarding ?? this.needsOnboarding,
      );

  @override
  List<Object?> get props => [status, user, token, errorMessage, isNewUser, needsOnboarding];
}
