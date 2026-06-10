import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/exam_model.dart';
import '../models/session_model.dart';
import '../repository/exam_repository.dart';

// Events
abstract class ExamEvent {}

class ExamListRequested extends ExamEvent {}

class ExamStartRequested extends ExamEvent {
  final int    examId;
  final String token;
  ExamStartRequested({required this.examId, required this.token});
}

class ExamAnswerSaved extends ExamEvent {
  final int questionId;
  final int selectedOptionId;
  ExamAnswerSaved({
    required this.questionId,
    required this.selectedOptionId,
  });
}

class ExamSubmitRequested extends ExamEvent {}

class ExamHeartbeatSent extends ExamEvent {}

class ExamViolationReported extends ExamEvent {
  final String type;
  ExamViolationReported(this.type);
}

// States
abstract class ExamState {}

class ExamInitial      extends ExamState {}
class ExamLoading      extends ExamState {}
class ExamListLoaded   extends ExamState {
  final List<ExamModel> exams;
  ExamListLoaded(this.exams);
}
class ExamSessionActive extends ExamState {
  final SessionModel      session;
  final Map<int, int>     answers;
  final int               currentIndex;
  final int               remainingSeconds;

  ExamSessionActive({
    required this.session,
    required this.answers,
    required this.currentIndex,
    required this.remainingSeconds,
  });

  ExamSessionActive copyWith({
    Map<int, int>? answers,
    int? currentIndex,
    int? remainingSeconds,
  }) => ExamSessionActive(
    session:          session,
    answers:          answers          ?? this.answers,
    currentIndex:     currentIndex     ?? this.currentIndex,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
  );
}
class ExamSubmitted extends ExamState {
  final double score;
  ExamSubmitted(this.score);
}
class ExamError extends ExamState {
  final String message;
  ExamError(this.message);
}

class ExamTicked extends ExamEvent {}

class ExamQuestionChanged extends ExamEvent {
  final int index;

  ExamQuestionChanged(this.index);
}

// Bloc
class ExamBloc extends Bloc<ExamEvent, ExamState> {
  final ExamRepository _repo;

  ExamBloc(this._repo) : super(ExamInitial()) {
  on<ExamListRequested>(_onListRequested);
  on<ExamStartRequested>(_onStartRequested);
  on<ExamAnswerSaved>(_onAnswerSaved);
  on<ExamSubmitRequested>(_onSubmitRequested);
  on<ExamHeartbeatSent>(_onHeartbeat);
  on<ExamViolationReported>(_onViolation);



  on<ExamTicked>(_onTicked);
  on<ExamQuestionChanged>(_onQuestionChanged);
}

  Future<void> _onListRequested(
    ExamListRequested event,
    Emitter<ExamState> emit,
  ) async {
    emit(ExamLoading());
    try {
      final exams = await _repo.getAvailableExams();
      emit(ExamListLoaded(exams));
    } catch (e) {
      emit(ExamError('Gagal memuat ujian. Periksa koneksi internet.'));
    }
  }

  Future<void> _onStartRequested(
    ExamStartRequested event,
    Emitter<ExamState> emit,
  ) async {
    emit(ExamLoading());
    try {
      final session = await _repo.startExam(event.examId, event.token);
      emit(ExamSessionActive(
        session:          session,
        answers:          {},
        currentIndex:     0,
        remainingSeconds: session.remainingSeconds,
      ));
    } catch (e) {
      emit(ExamError('Token tidak valid atau ujian sudah berakhir.'));
    }
  }

  Future<void> _onAnswerSaved(
    ExamAnswerSaved event,
    Emitter<ExamState> emit,
  ) async {
    final current = state;
    if (current is! ExamSessionActive) return;

    final updatedAnswers = Map<int, int>.from(current.answers)
      ..[event.questionId] = event.selectedOptionId;

    emit(current.copyWith(answers: updatedAnswers));

    // Autosave ke server
    try {
      await _repo.saveAnswer(
        current.session.sessionToken,
        event.questionId,
        event.selectedOptionId,
      );
    } catch (_) {}
  }

  Future<void> _onSubmitRequested(
    ExamSubmitRequested event,
    Emitter<ExamState> emit,
  ) async {
    final current = state;
    if (current is! ExamSessionActive) return;

    emit(ExamLoading());
    try {
      final score = await _repo.submitExam(current.session.sessionToken);
      emit(ExamSubmitted(score));
    } catch (e) {
      emit(ExamError('Gagal submit ujian.'));
    }
  }

  Future<void> _onHeartbeat(
    ExamHeartbeatSent event,
    Emitter<ExamState> emit,
  ) async {
    final current = state;
    if (current is! ExamSessionActive) return;
    await _repo.sendHeartbeat(current.session.sessionToken);
  }

  Future<void> _onViolation(
    ExamViolationReported event,
    Emitter<ExamState> emit,
  ) async {
    final current = state;
    if (current is! ExamSessionActive) return;

    await _repo.reportViolation(
      current.session.sessionToken,
      event.type,
    );
  }

  Future<void> _onTicked(
    ExamTicked event,
    Emitter<ExamState> emit,
  ) async {
    final current = state;

    if (current is! ExamSessionActive) {
      return;
    }

    emit(
      current.copyWith(
        remainingSeconds: current.remainingSeconds - 1,
      ),
    );
  }

  Future<void> _onQuestionChanged(
    ExamQuestionChanged event,
    Emitter<ExamState> emit,
  ) async {
    final current = state;

    if (current is! ExamSessionActive) {
      return;
    }

    emit(
      current.copyWith(
        currentIndex: event.index,
      ),
    );
  }
}