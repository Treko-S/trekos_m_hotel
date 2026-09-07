import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:trekos_m_hotel/core/services/email_notification_service.dart';
import 'package:trekos_m_hotel/features/auth/domain/entities/user.dart';
import 'package:trekos_m_hotel/features/auth/domain/repository/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository})
      : super(AuthInitial()) {
    on<AuthSignUp>(_onAuthSignUp);
    on<AuthLogin>(_onAuthLogin);
    on<AuthSignOut>(_onAuthSignOut);
    on<AuthIsUserLoggedIn>(_isUserLoggedIn);
  }

  void _onAuthSignUp(AuthSignUp event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final res = await authRepository.signUpWithEmailPassword(
      name: event.name,
      email: event.email,
      password: event.password,
      phone: event.phone,
      documentType: event.documentType,
      documentNumber: event.documentNumber,
      nationality: event.nationality,
    );

    res.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) {
        // Sincronizar contacto en Brevo y enviar bienvenida oficial
        EmailNotificationService.syncContactWithBrevo(
          email: user.email,
          name: user.name,
          phone: event.phone,
        );
        EmailNotificationService.sendWelcomeEmail(
          recipientEmail: user.email,
          guestName: user.name,
        );
        emit(AuthSuccess(user));
      },
    );
  }

  void _onAuthLogin(AuthLogin event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final res = await authRepository.loginWithEmailPassword(
      email: event.email,
      password: event.password,
    );

    res.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthSuccess(user)),
    );
  }

  void _onAuthSignOut(AuthSignOut event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final res = await authRepository.signOut();
    res.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (_) => emit(AuthInitial()),
    );
  }

  void _isUserLoggedIn(AuthIsUserLoggedIn event, Emitter<AuthState> emit) async {
    final res = await authRepository.currentUser();

    res.fold(
      (_) => emit(AuthInitial()),
      (user) => emit(AuthSuccess(user)),
    );
  }
}
