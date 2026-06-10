import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // Ambil token dari storage
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ApiConfig.tokenKey);
  }

  // Simpan token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConfig.tokenKey, token);
  }

  // Hapus token (logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConfig.tokenKey);
    await prefs.remove(ApiConfig.userKey);
  }

  // Header dengan token
  static Future<Map<String, String>> _authHeader() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'X-Api-Token': token ?? '',
    };
  }

  // LOGIN
  static Future<Map<String, dynamic>> login(
      String login, String password) async {
    try {
      final res = await _dio.post(
        ApiConfig.login,
        data: {'login': login, 'password': password},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      return res.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
    }
  }

  // PROFIL PEGAWAI
  static Future<Map<String, dynamic>> getPegawaiProfil() async {
    try {
      final res = await _dio.get(
        ApiConfig.pegawaiProfil,
        options: Options(headers: await _authHeader()),
      );
      return res.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
    }
  }

  // ABSEN HARI INI
  static Future<Map<String, dynamic>> getAbsenHariIni() async {
    try {
      final res = await _dio.get(
        ApiConfig.absenHariIni,
        options: Options(headers: await _authHeader()),
      );
      return res.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
    }
  }

  // ABSEN MASUK
  static Future<Map<String, dynamic>> absenMasuk(
      double lat, double lng) async {
    try {
      final res = await _dio.post(
        ApiConfig.absenMasuk,
        data: {'latitude': lat, 'longitude': lng},
        options: Options(headers: await _authHeader()),
      );
      return res.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
    }
  }

  // ABSEN KELUAR
  static Future<Map<String, dynamic>> absenKeluar(
      double lat, double lng) async {
    try {
      final res = await _dio.post(
        ApiConfig.absenKeluar,
        data: {'latitude': lat, 'longitude': lng},
        options: Options(headers: await _authHeader()),
      );
      return res.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
    }
  }

  // RIWAYAT ABSEN
  static Future<Map<String, dynamic>> getRiwayat() async {
    try {
      final res = await _dio.get(
        ApiConfig.absenRiwayat,
        options: Options(headers: await _authHeader()),
      );
      return res.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
    }
  }
}