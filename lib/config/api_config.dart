class ApiConfig {
  static const String baseUrl =
      'https://chat.marsa9.com/present/public/index.php';

  static const String login        = '$baseUrl/api/auth/login';
  static const String profile      = '$baseUrl/api/auth/profile';
  static const String logout       = '$baseUrl/api/auth/logout';
  static const String pegawaiProfil= '$baseUrl/api/pegawai/profil';
  static const String absenHariIni = '$baseUrl/api/absen/hari-ini';
  static const String absenMasuk   = '$baseUrl/api/absen/masuk';
  static const String absenKeluar  = '$baseUrl/api/absen/keluar';
  static const String absenRiwayat = '$baseUrl/api/absen/riwayat';

  static const String cekLokasi = '$baseUrl/api/absen/cek-lokasi';

  static const String tokenKey     = 'api_token';
  static const String userKey      = 'user_data';
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