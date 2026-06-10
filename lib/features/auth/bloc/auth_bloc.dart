import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/user_model.dart';
import '../repository/auth_repository.dart';

// Events
abstract class AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String username;
  final String password;
  AuthLoginRequested({required this.username, required this.password});
}

class AuthLogoutRequested extends AuthEvent {}

// States
abstract class AuthState {}

class AuthInitial    extends AuthState {}
class AuthLoading    extends AuthState {}
class AuthSuccess    extends AuthState {
  final UserModel user;
  AuthSuccess(this.user);
}
class AuthFailure    extends AuthState {
  final String message;
  AuthFailure(this.message);
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;

  AuthBloc(this._repo) : super(AuthInitial()) {
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _repo.login(event.username, event.password);
      emit(AuthSuccess(user));
    } catch (e) {
      emit(AuthFailure('Username atau password salah.'));
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repo.logout();
    emit(AuthInitial());
  }
}