import '../../../core/api/api_client.dart';
import '../../../core/utils/device_util.dart';
import '../models/exam_model.dart';
import '../models/session_model.dart';

class ExamRepository {
  Future<List<ExamModel>> getAvailableExams() async {
    final res = await ApiClient.get('/participant/exams');
    return (res.data as List)
        .map((e) => ExamModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SessionModel> startExam(int examId, String token) async {
    final fingerprint = await DeviceUtil.getFingerprint();
    final platform    = DeviceUtil.getPlatform();

    final res = await ApiClient.post(
      '/participant/exams/$examId/start',
      data: {
        'token':            token,
        'fingerprint_hash': fingerprint,
        'platform':         platform,
      },
    );

    return SessionModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> saveAnswer(
    String sessionToken,
    int questionId,
    int selectedOptionId,
  ) async {
    await ApiClient.post(
      '/participant/session/$sessionToken/answer',
      data: {
        'question_id':        questionId,
        'selected_option_id': selectedOptionId,
      },
    );
  }

  Future<double> submitExam(String sessionToken) async {
  final res = await ApiClient.post(
    '/participant/session/$sessionToken/submit',
  );

  return ((res.data as Map<String, dynamic>)['score'] as num?)?.toDouble() ?? 0.0;
}

  Future<void> sendHeartbeat(String sessionToken) async {
    try {
      await ApiClient.post('/participant/session/$sessionToken/heartbeat');
    } catch (_) {}
  }

  Future<void> reportViolation(
    String sessionToken,
    String type,
  ) async {
    try {
      await ApiClient.post(
        '/participant/session/$sessionToken/violation',
        data: {
          'type':   type,
          'detail': {'reported_at': DateTime.now().toIso8601String()},
        },
      );
    } catch (_) {}
  }
}