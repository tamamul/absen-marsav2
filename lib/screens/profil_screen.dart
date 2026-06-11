import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../models/pegawai_model.dart';

class ProfilScreen extends StatefulWidget {
  final PegawaiModel? pegawai;
  const ProfilScreen({super.key, this.pegawai});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  File? _fotoProfil;
  static const String _fotoKey = 'foto_profil_lokal';

  @override
  void initState() {
    super.initState();
    _loadFotoLokal();
  }

  Future<void> _loadFotoLokal() async {
    final prefs = await SharedPreferences.getInstance();
    final path  = prefs.getString(_fotoKey);
    if (path != null && File(path).existsSync()) {
      setState(() => _fotoProfil = File(path));
    }
  }

  Future<void> _gantiFoto() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Ganti Foto Profil',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF1B5E20),
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text('Ambil dari Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pilihFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pilihFoto(ImageSource.gallery);
              },
            ),
            if (_fotoProfil != null)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                title: const Text('Hapus Foto',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _hapusFoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pilihFoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 400,
    );
    if (picked == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fotoKey, picked.path);
    setState(() => _fotoProfil = File(picked.path));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Foto profil berhasil diperbarui'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _hapusFoto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fotoKey);
    setState(() => _fotoProfil = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pegawai;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Profil Saya'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header hijau dengan foto
            Container(
              width: double.infinity,
              color: const Color(0xFF1B5E20),
              padding: const EdgeInsets.only(
                  top: 20, bottom: 40, left: 16, right: 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _gantiFoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.white,
                          backgroundImage: _fotoProfil != null
                              ? FileImage(_fotoProfil!)
                              : null,
                          child: _fotoProfil == null
                              ? Text(
                                  p?.nama.isNotEmpty == true
                                      ? p!.nama[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontSize: 44,
                                      color: Color(0xFF1B5E20),
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 18, color: Color(0xFF1B5E20)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(p?.nama ?? '-',
                      style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  Text(p?.jabatan ?? '-',
                      style: const TextStyle(
                          color: Colors.white70)),
                ],
              ),
            ),

            // Info cards
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildInfoCard('Informasi Pegawai', [
                      _buildInfoRow(Icons.badge, 'NIP', p?.nip ?? '-'),
                      _buildInfoRow(Icons.work, 'Jabatan', p?.jabatan ?? '-'),
                      _buildInfoRow(
                          Icons.phone, 'No. HP', p?.noHandphone ?? '-'),
                    ]),
                    const SizedBox(height: 12),
                    _buildInfoCard('Lokasi Presensi', [
                      _buildInfoRow(
                          Icons.location_on, 'Lokasi', p?.namaLokasi ?? '-'),
                      _buildInfoRow(Icons.radar, 'Radius',
                          '${p?.radius ?? 0} meter'),
                      _buildInfoRow(
                          Icons.login, 'Jam Masuk', p?.jamMasuk ?? '-'),
                      _buildInfoRow(
                          Icons.logout, 'Jam Pulang', p?.jamPulang ?? '-'),
                      _buildInfoRow(Icons.access_time, 'Maks Pulang',
                          p?.jamPulangMaksimal ?? '-'),
                      _buildInfoRow(Icons.tune, 'Mode',
                          (p?.modeAbsen ?? '-').toUpperCase()),
                    ]),
                    const SizedBox(height: 12),
                    _buildInfoCard('Fitur Keamanan', [
                      _buildInfoRowBool(Icons.face, 'Face Recognition',
                          p?.faceRecognition ?? false),
                      _buildInfoRowBool(Icons.verified_user, 'Face Required',
                          p?.faceRequired ?? false),
                    ]),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> rows) {
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20))),
            const Divider(height: 16),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text('$label  ',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowBool(IconData icon, String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: value
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value ? 'Aktif' : 'Nonaktif',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: value ? Colors.green : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}