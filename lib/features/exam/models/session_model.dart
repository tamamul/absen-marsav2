import 'question_model.dart';

class SessionModel {
  final String              sessionToken;
  final DateTime            expiresAt;
  final List<QuestionModel> questions;

  const SessionModel({
    required this.sessionToken,
    required this.expiresAt,
    required this.questions,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) => SessionModel(
    sessionToken: json['session_token'] as String,
    expiresAt:    DateTime.parse(json['expires_at'] as String).toLocal(),
    questions:    (json['questions'] as List)
        .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
        .toList(),
  );

  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }
}