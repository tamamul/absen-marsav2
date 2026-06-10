class OptionModel {
  final int id;
  final String label;
  final String content;

  const OptionModel({
    required this.id,
    required this.label,
    required this.content,
  });

  factory OptionModel.fromJson(Map<String, dynamic> json) => OptionModel(
        id: json['id'] as int,
        label: json['label'] as String,
        content: json['content'] as String,
      );
}

class QuestionModel {
  final int id;
  final String content;
  final String type;
  final String? imagePath;
  final double points;
  final List<OptionModel> options;

  const QuestionModel({
    required this.id,
    required this.content,
    required this.type,
    this.imagePath,
    required this.points,
    required this.options,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
        id: json['id'] as int,
        content: json['content'] as String,
        type: json['type'] as String,
        imagePath: json['image_path'] as String?,
        points: (json['points'] as num?)?.toDouble() ?? 1.0,
        options: (json['options'] as List)
            .map((o) => OptionModel.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}