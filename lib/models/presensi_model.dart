class PresensiModel {
  final String id;
  final String idPegawai;
  final String tanggalMasuk;
  final String jamMasuk;
  final String fotoMasuk;
  final String tanggalKeluar;
  final String jamKeluar;
  final String fotoKeluar;

  PresensiModel({
    required this.id,
    required this.idPegawai,
    required this.tanggalMasuk,
    required this.jamMasuk,
    required this.fotoMasuk,
    required this.tanggalKeluar,
    required this.jamKeluar,
    required this.fotoKeluar,
  });

  factory PresensiModel.fromJson(Map<String, dynamic> json) {
    return PresensiModel(
      id:             json['id']?.toString() ?? '',
      idPegawai:      json['id_pegawai']?.toString() ?? '',
      tanggalMasuk:   json['tanggal_masuk'] ?? '',
      jamMasuk:       json['jam_masuk'] ?? '',
      fotoMasuk:      json['foto_masuk'] ?? '',
      tanggalKeluar:  json['tanggal_keluar'] ?? '',
      jamKeluar:      json['jam_keluar'] ?? '',
      fotoKeluar:     json['foto_keluar'] ?? '',
    );
  }

  bool get sudahMasuk => jamMasuk.isNotEmpty && jamMasuk != '00:00:00';
  bool get sudahKeluar => jamKeluar.isNotEmpty && jamKeluar != '00:00:00';
}