part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object> get props => [];
}

class AuthSignUp extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final String phone;
  final String? documentType;
  final String? documentNumber;
  final String? nationality;

  const AuthSignUp({
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
    this.documentType,
    this.documentNumber,
    this.nationality,
  });
}

class AuthLogin extends AuthEvent {
  final String email;
  final String password;

  const AuthLogin({
    required this.email,
    required this.password,
  });
}

class AuthSignOut extends AuthEvent {}

class AuthIsUserLoggedIn extends AuthEvent {}
