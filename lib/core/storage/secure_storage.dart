import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken = 'auth_token';
  static const _keyUser  = 'auth_user';

  static Future<void> saveToken(String token) async =>
      await _storage.write(key: _keyToken, value: token);

  static Future<String?> getToken() async =>
      await _storage.read(key: _keyToken);

  static Future<void> saveUser(String userJson) async =>
      await _storage.write(key: _keyUser, value: userJson);

  static Future<String?> getUser() async =>
      await _storage.read(key: _keyUser);

  static Future<void> clear() async =>
      await _storage.deleteAll();

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}