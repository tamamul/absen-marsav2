import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../repository/auth_repository.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  int _failCount = 0;
bool _isPenalty = false;
Timer? _penaltyTimer;

  @override
void dispose() {
  _usernameCtrl.dispose();
  _passwordCtrl.dispose();
  _penaltyTimer?.cancel();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(AuthRepository()),
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
  if (state is AuthSuccess) {
    context.go('/exams');
  }
  if (state is AuthFailure) {
    setState(() => _failCount++);
    if (_failCount >= 1) {
      _startPenalty();
    }
  }
},
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),

                    // Logo
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            color: AppTheme.primary,
                            child: const Icon(
                              Icons.quiz_outlined,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'MARSA CBT',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Masuk untuk mulai ujian',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Error
                    if (state is AuthFailure) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppTheme.danger,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.message,
                              style: TextStyle(
                                color: AppTheme.danger,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Username
                    Text(
                      'USERNAME / NIS',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _usernameCtrl,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Masukkan username',
                      ),
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 16),

                    // Password
                    Text(
                      'PASSWORD',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Masukkan password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppTheme.textSecondary,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onSubmitted: (_) => _submit(context),
                    ),

                    const SizedBox(height: 32),

                    // Button
                    SizedBox(
  height: 50,
  child: ElevatedButton(
    onPressed: (state is AuthLoading || _isPenalty)
        ? null
        : () => _submit(context),
    style: ElevatedButton.styleFrom(
      backgroundColor: _isPenalty ? AppTheme.danger : AppTheme.primary,
    ),
    child: state is AuthLoading
        ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
          )
        : _isPenalty
            ? const Text(
                'TUNGGU 1 MENIT...',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              )
            : const Text(
                'MASUK',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
  ),
),

                    const SizedBox(height: 24),

                    Center(
                      child: Text(
                        'SMK Ma\'arif 9 Kebumen',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  void _startPenalty() {
  _penaltyTimer?.cancel();

  setState(() => _isPenalty = true);

  _penaltyTimer = Timer(
    const Duration(minutes: 1),
    () {
      if (mounted) {
        setState(() {
          _isPenalty = false;
          _failCount = 0;
        });
      }
    },
  );
}

void _submit(BuildContext context) {
  final username = _usernameCtrl.text.trim();
  final password = _passwordCtrl.text;

  if (username.isEmpty || password.isEmpty) return;

  context.read<AuthBloc>().add(
    AuthLoginRequested(
      username: username,
      password: password,
    ),
  );
}
}