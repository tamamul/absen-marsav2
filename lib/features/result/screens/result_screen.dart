import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class ResultScreen extends StatelessWidget {
  final int    totalAnswered;
  final int    totalQuestions;
  final String examTitle;
  final bool   auto;

  const ResultScreen({
    super.key,
    required this.totalAnswered,
    required this.totalQuestions,
    required this.examTitle,
    this.auto = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),

                // Icon selesai
                Container(
                  width: 80, height: 80,
                  color: AppTheme.success,
                  child: const Icon(
                    Icons.task_alt,
                    color: Colors.white,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'UJIAN SELESAI',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  examTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),

                if (auto) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    child: Text(
                      'Disubmit otomatis — waktu habis',
                      style: TextStyle(
                          color: AppTheme.warning, fontSize: 12),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  color: AppTheme.surface,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: AppTheme.success,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Jawaban kamu telah berhasil\ndikirim ke server.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nilai akan diumumkan oleh guru.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Stat terjawab
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.quiz_outlined,
                          color: AppTheme.textSecondary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Terjawab: $totalAnswered dari $totalQuestions soal',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => context.go('/exams'),
                    child: const Text(
                      'KEMBALI KE DAFTAR UJIAN',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'SMK Ma\'arif 9 Kebumen',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}