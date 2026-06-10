class PegawaiModel {
  final String id;
  final String nama;
  final String nip;
  final String foto;
  final String noHandphone;
  final String jabatan;
  final String namaLokasi;
  final double latitude;
  final double longitude;
  final int radius;
  final String jamMasuk;
  final String jamPulang;
  final String jamPulangMaksimal;
  final String modeAbsen;
  final bool faceRecognition;
  final bool faceRequired;

  PegawaiModel({
    required this.id,
    required this.nama,
    required this.nip,
    required this.foto,
    required this.noHandphone,
    required this.jabatan,
    required this.namaLokasi,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.jamMasuk,
    required this.jamPulang,
    required this.jamPulangMaksimal,
    required this.modeAbsen,
    required this.faceRecognition,
    required this.faceRequired,
  });

  factory PegawaiModel.fromJson(Map<String, dynamic> json) {
    return PegawaiModel(
      id:               json['id']?.toString() ?? '',
      nama:             json['nama'] ?? '',
      nip:              json['nip'] ?? '',
      foto:             json['foto'] ?? '',
      noHandphone:      json['no_handphone'] ?? '',
      jabatan:          json['jabatan'] ?? '',
      namaLokasi:       json['nama_lokasi'] ?? '',
      latitude:         double.tryParse(json['latitude'].toString()) ?? 0.0,
      longitude:        double.tryParse(json['longitude'].toString()) ?? 0.0,
      radius:           int.tryParse(json['radius'].toString()) ?? 0,
      jamMasuk:         json['jam_masuk'] ?? '',
      jamPulang:        json['jam_pulang'] ?? '',
      jamPulangMaksimal:json['jam_pulang_maksimal'] ?? '',
      modeAbsen:        json['mode_absen'] ?? '',
      faceRecognition:  json['face_recognition'].toString() == '1',
      faceRequired:     json['face_required'].toString() == '1',
    );
  }
}