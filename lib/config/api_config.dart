class ApiConfig {
  static const String baseUrl =
      'https://smk-maarif9kebumen.com/present/public/index.php';

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
static const String galeri = '$baseUrl/api/absen/galeri';
static const String pengumuman = '$baseUrl/api/pengumuman';
}