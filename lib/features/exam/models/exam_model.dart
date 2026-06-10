class ExamModel {
  final int id;
  final String title;
  final int durationMinutes;
  final int questionCount;
  final double passingScore;

  const ExamModel({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.questionCount,
    required this.passingScore,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) => ExamModel(
        id: json['id'] as int,
        title: json['title'] as String,
        durationMinutes: json['duration_minutes'] as int,
        questionCount: json['question_count'] as int,
        passingScore:
            (json['passing_score'] as num?)?.toDouble() ?? 75.0,
      );
}