import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/device_util.dart';
import '../models/user_model.dart';

class AuthRepository {
  Future<UserModel> login(String username, String password) async {
    final res = await ApiClient.post('/auth/login', data: {
      'username': username,
      'password': password,
    });

    final token = res.data['token'] as String;
    final user  = UserModel.fromJson(res.data['user'] as Map<String, dynamic>);

    await SecureStorage.saveToken(token);
    await SecureStorage.saveUser(user.toJsonString());

    // Register device di background
    _registerDevice();

    return user;
  }

  Future<void> _registerDevice() async {
    try {
      final fingerprint = await DeviceUtil.getFingerprint();
      final platform    = DeviceUtil.getPlatform();
      await ApiClient.post('/auth/register-device', data: {
        'fingerprint_hash': fingerprint,
        'platform':         platform,
        'device_info': {'platform': platform},
      });
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      await ApiClient.post('/auth/logout');
    } catch (_) {}
    await SecureStorage.clear();
  }

  Future<UserModel?> getCurrentUser() async {
    final userJson = await SecureStorage.getUser();
    if (userJson == null) return null;
    return UserModel.fromJsonString(userJson);
  }
}