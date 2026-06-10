import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/exam_bloc.dart';
import '../models/question_model.dart';
import '../repository/exam_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/security/exam_security.dart';


class ExamRoomScreen extends StatelessWidget {
  final int    examId;
  final String examTitle;
  final String token;

  const ExamRoomScreen({
    super.key,
    required this.examId,
    required this.examTitle,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExamBloc(ExamRepository())
        ..add(ExamStartRequested(examId: examId, token: token)),
      child: _ExamRoomView(examTitle: examTitle),
    );
  }
}

class _ExamRoomView extends StatefulWidget {
  final String examTitle;
  const _ExamRoomView({required this.examTitle});

  @override
  State<_ExamRoomView> createState() => _ExamRoomViewState();
}

class _ExamRoomViewState extends State<_ExamRoomView>
    with WidgetsBindingObserver {
  Timer? _countdownTimer;
  Timer? _heartbeatTimer;

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  ExamSecurity.enable(); // aktifkan semua proteksi
}

  @override
void dispose() {
  _countdownTimer?.cancel();
  _heartbeatTimer?.cancel();
  WidgetsBinding.instance.removeObserver(this);
  ExamSecurity.disable(); // nonaktifkan setelah selesai
  super.dispose();
}

  @override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.inactive) {
    // Catat pelanggaran
    context.read<ExamBloc>().add(ExamViolationReported('app_switch'));

    // Paksa kembali ke foreground via re-enable immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
}

  void _startTimers() {
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final state = context.read<ExamBloc>().state;
      if (state is! ExamSessionActive) return;
      if (state.remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        context.read<ExamBloc>().add(ExamSubmitRequested());
        return;
      }
      context.read<ExamBloc>().add(ExamTicked());
    });

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      context.read<ExamBloc>().add(ExamHeartbeatSent());
    });
  }

  void _confirmSubmit(BuildContext context, ExamSessionActive state) {
    final unanswered = state.session.questions.length - state.answers.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'Submit Ujian?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terjawab: ${state.answers.length}/${state.session.questions.length}',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            if (unanswered > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$unanswered soal belum dijawab.',
                style: TextStyle(color: AppTheme.warning, fontSize: 13),
              ),
            ],
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
              Navigator.pop(ctx);
              context.read<ExamBloc>().add(ExamSubmitRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BlocConsumer<ExamBloc, ExamState>(
        listener: (context, state) {
          if (state is ExamSessionActive &&
              _countdownTimer == null) {
            _startTimers();
          }
          if (state is ExamSubmitted) {
            _countdownTimer?.cancel();
            _heartbeatTimer?.cancel();
          }
          if (state is ExamSubmitted) {
            context.go('/result', extra: {
              'score':          state.score,
              'passingScore':   75.0,
              'totalAnswered':  0,
              'totalQuestions': 0,
              'examTitle':      widget.examTitle,
              'auto':           false,
            });
          }
        },
        builder: (context, state) {
          if (state is ExamLoading) {
            return Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Memuat soal...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is ExamError) {
            return Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          color: AppTheme.danger, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/exams'),
                        child: const Text('Kembali'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (state is! ExamSessionActive) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final questions    = state.session.questions;
          final question     = questions[state.currentIndex];
          final isWarning    = state.remainingSeconds < 300;

          return Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(
                widget.examTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: isWarning ? AppTheme.danger : AppTheme.primary,
                  child: Text(
                    _formatTime(state.remainingSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                // Progress bar
                LinearProgressIndicator(
                  value: (state.currentIndex + 1) / questions.length,
                  backgroundColor: AppTheme.border,
                  color: AppTheme.primary,
                  minHeight: 3,
                ),

                // Nomor soal navigator
                Container(
                  height: 48,
                  color: AppTheme.surface,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    itemCount: questions.length,
                    itemBuilder: (_, i) {
                      final isActive =
                          i == state.currentIndex;
                      final isAnswered =
                          state.answers.containsKey(questions[i].id);
                      return GestureDetector(
                        onTap: () {
                          final current = context
                              .read<ExamBloc>()
                              .state;
                          if (current is ExamSessionActive) {
                           context.read<ExamBloc>().add(
  ExamQuestionChanged(i),
);
                          }
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 4),
                          color: isActive
                              ? AppTheme.primary
                              : isAnswered
                                  ? AppTheme.success
                                  : AppTheme.border,
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: isActive || isAnswered
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Soal
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              color: AppTheme.primary,
                              child: Text(
                                'Soal ${state.currentIndex + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${question.points.toInt()} poin',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          question.content,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ...question.options.map(
                          (opt) => _buildOption(
                            context,
                            question,
                            opt,
                            state,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Navigation buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.surface,
                  child: Row(
                    children: [
                      if (state.currentIndex > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              final current = context
                                  .read<ExamBloc>()
                                  .state;
                              if (current is ExamSessionActive) {
                             context.read<ExamBloc>().add(
  ExamQuestionChanged(
    current.currentIndex - 1,
  ),
);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: BorderSide(color: AppTheme.border),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            child: const Text('← Sebelumnya'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: state.currentIndex < questions.length - 1
                            ? ElevatedButton(
                                onPressed: () {
                                  final current = context
                                      .read<ExamBloc>()
                                      .state;
                                  if (current is ExamSessionActive) {
                                  context.read<ExamBloc>().add(
  ExamQuestionChanged(
    current.currentIndex + 1,
  ),
);
                                  }
                                },
                                child: const Text('Selanjutnya →'),
                              )
                            : ElevatedButton(
                                onPressed: () =>
                                    _confirmSubmit(context, state),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text(
                                  'SUBMIT UJIAN ✓',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    QuestionModel question,
    OptionModel opt,
    ExamSessionActive state,
  ) {
    final isSelected = state.answers[question.id] == opt.id;
    return GestureDetector(
      onTap: () => context.read<ExamBloc>().add(
        ExamAnswerSaved(
          questionId:       question.id,
          selectedOptionId: opt.id,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.surface,
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              color: isSelected ? AppTheme.primary : AppTheme.border,
              child: Center(
                child: Text(
                  opt.label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                opt.content,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}