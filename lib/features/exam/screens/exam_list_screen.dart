import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/exam_bloc.dart';
import '../models/exam_model.dart';
import '../repository/exam_repository.dart';
import '../../auth/repository/auth_repository.dart';
import '../../../core/theme/app_theme.dart';

class ExamListScreen extends StatelessWidget {
  const ExamListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExamBloc(ExamRepository())..add(ExamListRequested()),
      child: const _ExamListView(),
    );
  }
}

class _ExamListView extends StatefulWidget {
  const _ExamListView();

  @override
  State<_ExamListView> createState() => _ExamListViewState();
}

class _ExamListViewState extends State<_ExamListView> {
  String _userName  = '';
  String _userClass = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthRepository().getCurrentUser();
    if (!mounted) return;
    setState(() {
      _userName  = user?.name ?? '';
      _userClass = user?.className ?? '-';
    });
  }

  void _showTokenDialog(BuildContext context, ExamModel exam) {
    final tokenCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'Token Ujian',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exam.title,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tokenCtrl,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontFamily: 'monospace',
                fontSize: 20,
                letterSpacing: 6,
                fontWeight: FontWeight.bold,
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              decoration: const InputDecoration(
                hintText: 'XXXXXX',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final token = tokenCtrl.text.trim().toUpperCase();
              if (token.isEmpty) return;
              Navigator.pop(ctx);
              context.go('/exam', extra: {
                'examId':    exam.id,
                'examTitle': exam.title,
                'token':     token,
              });
            },
            child: const Text('Mulai'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await AuthRepository().logout();
    if (!context.mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'MARSA CBT',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            onPressed: () =>
                context.read<ExamBloc>().add(ExamListRequested()),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          // User info bar
          if (_userName.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              color: AppTheme.surface,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    color: AppTheme.primary,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Kelas $_userClass',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: BlocBuilder<ExamBloc, ExamState>(
              builder: (context, state) {
                if (state is ExamLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ExamError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off,
                              color: AppTheme.danger, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context
                                .read<ExamBloc>()
                                .add(ExamListRequested()),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is ExamListLoaded) {
                  if (state.exams.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              color: AppTheme.textSecondary, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Tidak ada ujian aktif.',
                            style:
                                TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hubungi pengawas untuk informasi jadwal.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.exams.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final exam = state.exams[i];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        color: AppTheme.surface,
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              child: Icon(
                                Icons.quiz_outlined,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exam.title,
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      _chip('${exam.questionCount} soal'),
                                      _chip('${exam.durationMinutes} menit'),
                                      _chip('KKM ${exam.passingScore.toInt()}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () =>
                                  _showTokenDialog(context, exam),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: const Text('MULAI'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    color: AppTheme.background,
    child: Text(
      text,
      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
    ),
  );
}