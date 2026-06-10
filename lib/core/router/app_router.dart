import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/exam/screens/exam_list_screen.dart';
import '../../features/exam/screens/exam_room_screen.dart';
import '../../features/result/screens/result_screen.dart';
import '../storage/secure_storage.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Text(
          'Halaman tidak ditemukan.',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
    redirect: (context, state) async {
      final isLoggedIn = await SecureStorage.isLoggedIn();
      final isAuthRoute = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/';

      if (isSplash) return null;
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/exams';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/exams',
        builder: (_, __) => const ExamListScreen(),
      ),
      GoRoute(
        path: '/exam',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          return ExamRoomScreen(
            examId: args['examId'] as int,
            examTitle: args['examTitle'] as String,
            token: args['token'] as String,
          );
        },
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          return ResultScreen(
            totalAnswered: args['totalAnswered'] as int,
            totalQuestions: args['totalQuestions'] as int,
            examTitle: args['examTitle'] as String,
            auto: args['auto'] as bool? ?? false,
          );
        },
      ),
    ],
  );
}
