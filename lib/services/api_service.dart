import 'dart:io';
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
    double lat, double lng, {File? fotoFile}) async {
  try {
    final headers = await _authHeader();
    FormData formData = FormData.fromMap({
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      if (fotoFile != null)
        'foto': await MultipartFile.fromFile(
          fotoFile.path,
          filename: 'foto_masuk.png',
        ),
    });
    final res = await _dio.post(
      ApiConfig.absenMasuk,
      data: formData,
      options: Options(headers: {
        'X-Api-Token': headers['X-Api-Token'],
      }),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}

// ABSEN KELUAR
static Future<Map<String, dynamic>> absenKeluar(
    double lat, double lng, {File? fotoFile}) async {
  try {
    final headers = await _authHeader();
    FormData formData = FormData.fromMap({
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      if (fotoFile != null)
        'foto': await MultipartFile.fromFile(
          fotoFile.path,
          filename: 'foto_keluar.png',
        ),
    });
    final res = await _dio.post(
      ApiConfig.absenKeluar,
      data: formData,
      options: Options(headers: {
        'X-Api-Token': headers['X-Api-Token'],
      }),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}

// CEK LOKASI
static Future<Map<String, dynamic>> cekLokasi(
    double lat, double lng) async {
  try {
    final headers = await _authHeader();
    final res = await _dio.post(
      ApiConfig.cekLokasi,
      data: {'latitude': lat.toString(), 'longitude': lng.toString()},
      options: Options(headers: {
        'X-Api-Token': headers['X-Api-Token'],
      }),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}


static Future<Map<String, dynamic>> getGaleriHadir({
  required String tanggal,
}) async {
  try {
    final res = await _dio.get(
      '${ApiConfig.galeri}?tanggal=$tanggal',
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
      '${ApiConfig.absenRiwayat}?limit=365',
      options: Options(headers: await _authHeader()),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}

// PENGUMUMAN
static Future<Map<String, dynamic>> getPengumuman({
  String filter = 'semua', int limit = 20, int offset = 0,
}) async {
  try {
    final res = await _dio.get(
      '${ApiConfig.pengumuman}?filter=$filter&limit=$limit&offset=$offset',
      options: Options(headers: await _authHeader()),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}

static Future<Map<String, dynamic>> buatPengumuman({
  required String judul,
  required String isi,
  String emoji = '📢',
  String? tanggalEvent,
}) async {
  try {
    final headers = await _authHeader();
    final res = await _dio.post(
      ApiConfig.pengumuman,
      data: {
        'judul':         judul,
        'isi':           isi,
        'emoji':         emoji,
        'tanggal_event': tanggalEvent,
      },
      options: Options(headers: headers),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}

static Future<Map<String, dynamic>> hapusPengumuman(int id) async {
  try {
    final res = await _dio.delete(
      '${ApiConfig.pengumuman}/$id',
      options: Options(headers: await _authHeader()),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}

static Future<Map<String, dynamic>> getKomentar(int id) async {
  try {
    final res = await _dio.get(
      '${ApiConfig.pengumuman}/$id/komentar',
      options: Options(headers: await _authHeader()),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}

static Future<Map<String, dynamic>> kirimKomentar(
    int id, String isi) async {
  try {
    final headers = await _authHeader();
    final res = await _dio.post(
      '${ApiConfig.pengumuman}/$id/komentar',
      data: {'isi': isi},
      options: Options(headers: headers),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}
// PENGUMUMAN
static Future<Map<String, dynamic>> getPengumuman({
  String filter = 'semua', int limit = 20, int offset = 0,
}) async {
  try {
    final res = await _dio.get(
      '${ApiConfig.pengumuman}?filter=$filter&limit=$limit&offset=$offset',
      options: Options(headers: await _authHeader()),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}

static Future<Map<String, dynamic>> buatPengumuman({
  required String judul,
  required String isi,
  String emoji = '📢',
  String? tanggalEvent,
}) async {
  try {
    final headers = await _authHeader();
    final res = await _dio.post(
      ApiConfig.pengumuman,
      data: {
        'judul':         judul,
        'isi':           isi,
        'emoji':         emoji,
        'tanggal_event': tanggalEvent,
      },
      options: Options(headers: headers),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}

static Future<Map<String, dynamic>> hapusPengumuman(int id) async {
  try {
    final res = await _dio.delete(
      '${ApiConfig.pengumuman}/$id',
      options: Options(headers: await _authHeader()),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}

static Future<Map<String, dynamic>> getKomentar(int id) async {
  try {
    final res = await _dio.get(
      '${ApiConfig.pengumuman}/$id/komentar',
      options: Options(headers: await _authHeader()),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}

static Future<Map<String, dynamic>> kirimKomentar(
    int id, String isi) async {
  try {
    final headers = await _authHeader();
    final res = await _dio.post(
      '${ApiConfig.pengumuman}/$id/komentar',
      data: {'isi': isi},
      options: Options(headers: headers),
    );
    return res.data;
  } on DioException catch (e) {
    return e.response?.data ?? {'status': false, 'message': 'Koneksi gagal'};
  }
}
}