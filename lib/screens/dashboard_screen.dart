import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hijri/hijri_calendar.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../models/pegawai_model.dart';
import '../models/presensi_model.dart';
import '../helpers/hari_besar.dart';
import 'absen_screen.dart';
import 'login_screen.dart';
import 'riwayat_screen.dart';
import 'galeri_screen.dart';
import 'profil_screen.dart';
import 'kalender_screen.dart';
import 'absensi_siswa_screen.dart';
import 'rekap_siswa_screen.dart';
import 'pengumuman_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  PegawaiModel? _pegawai;
  PresensiModel? _presensi;
  bool _loading       = true;
  bool _cekLokasi     = false;
  bool? _didalam      = null;
  String _pesanLokasi = '';
  Position? _posisi;
  int _navIndex       = 0;
  File? _fotoProfil;

  // Waktu realtime
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _loadFotoProfil();
    _loadData();
    // Update jam tiap menit
    Future.delayed(const Duration(minutes: 1), _tickWaktu);
  }

  void _tickWaktu() {
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    Future.delayed(const Duration(minutes: 1), _tickWaktu);
  }

  Future<void> _loadFotoProfil() async {
    final prefs = await SharedPreferences.getInstance();
    final path  = prefs.getString('foto_profil_lokal');
    if (path != null && File(path).existsSync()) {
      setState(() => _fotoProfil = File(path));
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final resPegawai  = await ApiService.getPegawaiProfil();
      final resPresensi = await ApiService.getAbsenHariIni();
      setState(() {
        if (resPegawai['status'] == true) {
          _pegawai = PegawaiModel.fromJson(resPegawai['data']);
        }
        if (resPresensi['status'] == true && resPresensi['data'] != null) {
          _presensi = PresensiModel.fromJson(resPresensi['data']);
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
    await _validasiLokasi();
  }

  Future<void> _validasiLokasi() async {
    setState(() {
      _cekLokasi   = true;
      _pesanLokasi = 'Mengecek lokasi...';
      _didalam     = null;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _cekLokasi   = false;
          _pesanLokasi = 'Izin lokasi ditolak';
          _didalam     = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _posisi = pos;
      final res = await ApiService.cekLokasi(pos.latitude, pos.longitude);
      setState(() {
        _cekLokasi   = false;
        _didalam     = res['didalam'] == true;
        _pesanLokasi = res['message'] ?? '';
      });
    } catch (e) {
      setState(() {
        _cekLokasi   = false;
        _pesanLokasi = 'Gagal cek lokasi';
        _didalam     = false;
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _showProfilMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Avatar besar
            CircleAvatar(
              radius: 42,
              backgroundColor: const Color(0xFF1B5E20),
              backgroundImage:
                  _fotoProfil != null ? FileImage(_fotoProfil!) : null,
              child: _fotoProfil == null
                  ? Text(
                      _pegawai?.nama.isNotEmpty == true
                          ? _pegawai!.nama[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 36,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(_pegawai?.nama ?? '-',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(_pegawai?.jabatan ?? '-',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil Saya'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProfilScreen(pegawai: _pegawai)),
                );
                _loadFotoProfil(); // refresh foto setelah kembali
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Keluar',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showToolsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Tools',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Grid tools
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _toolItem(
                  icon: Icons.calendar_month,
                  label: 'Kalender',
                  color: const Color(0xFF1B5E20),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const KalenderScreen()),
                    );
                  },
                ),
                // Placeholder tools berikutnya
                _toolItem(
  icon: Icons.how_to_reg,
  label: 'Absensi\nSiswa',
  color: Colors.teal,
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const AbsensiSiswaScreen()),
    );
  },
),
_toolItem(
  icon: Icons.bar_chart,
  label: 'Rekap\nSiswa',
  color: Colors.indigo,
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const RekapSiswaScreen()),
    );
  },
),

                _toolItem(
                  icon: Icons.qr_code_scanner,
                  label: 'QR Scan',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Segera hadir')),
                    );
                  },
                ),
                _toolItem(
                  icon: Icons.qr_code,
                  label: 'QR Buat',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Segera hadir')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _toolItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school,
                  size: 20, color: Color(0xFF1B5E20)),
            ),
            const SizedBox(width: 10),
            const Text('Absen MARSA',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _showProfilMenu,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: _fotoProfil != null
                    ? FileImage(_fotoProfil!)
                    : null,
                child: _fotoProfil == null
                    ? Text(
                        _pegawai?.nama.isNotEmpty == true
                            ? _pegawai!.nama[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: _navIndex == 0
          ? _buildBeranda()
          : _navIndex == 1
              ? const RiwayatScreen()
              : const GaleriScreen(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _navItem(0, Icons.home_outlined, Icons.home, 'Beranda'),
              _navItem(1, Icons.history_outlined, Icons.history, 'Riwayat'),
              _navItem(2, Icons.photo_library_outlined,
                  Icons.photo_library, 'Galeri'),
              // Tombol Tools
              Expanded(
                child: GestureDetector(
                  onTap: _showToolsMenu,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.apps,
                            color: Color(0xFF1B5E20), size: 22),
                      ),
                      const SizedBox(height: 2),
                      const Text('Tools',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF1B5E20),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
      int index, IconData iconOff, IconData iconOn, String label) {
    final active = _navIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _navIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? iconOn : iconOff,
              color: active
                  ? const Color(0xFF1B5E20)
                  : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: active
                        ? const Color(0xFF1B5E20)
                        : Colors.grey,
                    fontWeight: active
                        ? FontWeight.bold
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildBeranda() {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTanggalCard(),
                  const SizedBox(height: 12),
                  _buildProfileCard(),
                  const SizedBox(height: 12),
                  _buildLokasiCard(),
                  const SizedBox(height: 12),
                  _buildStatusCard(),
                  const SizedBox(height: 12),
                  _buildAbsenButtons(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
  }

  Widget _buildTanggalCard() {
    final hijri      = HijriCalendar.fromDate(_now);
    final hariBesar  = HariBesarHelper.getHariIni(_now);
    final mendatang  = HariBesarHelper.getMendatang(_now, hari: 14);

    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          HariBesarHelper.namaHari(_now),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13),
                        ),
                        Text(
                          '${_now.day} ${HariBesarHelper.namaBulan(_now.month)} ${_now.year}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${hijri.hDay} ${HariBesarHelper.namaBulanHijri(hijri.hMonth)} ${hijri.hYear} H',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Jam
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const KalenderScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_month,
                                  color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('Kalender',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Hari besar hari ini
              if (hariBesar.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: hariBesar.map((h) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(h.emoji ?? '📅',
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(h.nama,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
                ),
              ],

              // Mendatang dalam 14 hari
              if (mendatang.isNotEmpty && hariBesar.isEmpty) ...[
                const SizedBox(height: 10),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
  Icons.event,
  color: Colors.white70,
  size: 14,
),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${mendatang.first.emoji ?? ''} ${mendatang.first.nama} — ${mendatang.first.tanggal.difference(DateTime.now()).inDays} hari lagi',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF1B5E20),
              backgroundImage: _fotoProfil != null
                  ? FileImage(_fotoProfil!)
                  : null,
              child: _fotoProfil == null
                  ? Text(
                      _pegawai?.nama.isNotEmpty == true
                          ? _pegawai!.nama[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_pegawai?.nama ?? '-',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  Text(_pegawai?.jabatan ?? '-',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13)),
                  Text(_pegawai?.namaLokasi ?? '-',
                      style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.w500,
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLokasiCard() {
    Color color;
    IconData icon;
    if (_cekLokasi) {
      color = Colors.orange;
      icon  = Icons.location_searching;
    } else if (_didalam == true) {
      color = Colors.green;
      icon  = Icons.location_on;
    } else {
      color = Colors.red;
      icon  = Icons.location_off;
    }

    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: _cekLokasi
                  ? SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color))
                  : Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _cekLokasi
                        ? 'Mengecek lokasi...'
                        : _didalam == true
                            ? 'Dalam Area Presensi'
                            : 'Di Luar Area Presensi',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color),
                  ),
                  Text(_pesanLokasi,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _cekLokasi ? null : _validasiLokasi,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final sudahMasuk  = _presensi?.sudahMasuk  ?? false;
    final sudahKeluar = _presensi?.sudahKeluar ?? false;

    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Status Hari Ini',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (sudahMasuk && sudahKeluar)
                        ? Colors.green.withOpacity(0.1)
                        : sudahMasuk
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (sudahMasuk && sudahKeluar)
                        ? 'Lengkap'
                        : sudahMasuk
                            ? 'Belum Keluar'
                            : 'Belum Absen',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: (sudahMasuk && sudahKeluar)
                            ? Colors.green
                            : sudahMasuk
                                ? Colors.orange
                                : Colors.grey),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    icon: Icons.login,
                    label: 'Masuk',
                    value: sudahMasuk ? _presensi!.jamMasuk : '-',
                    color: sudahMasuk ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatusItem(
                    icon: Icons.logout,
                    label: 'Keluar',
                    value: sudahKeluar ? _presensi!.jamKeluar : '-',
                    color: sudahKeluar ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAbsenButtons() {
    final sudahMasuk  = _presensi?.sudahMasuk  ?? false;
    final sudahKeluar = _presensi?.sudahKeluar ?? false;
    final bolehAbsen  = _didalam == true;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (sudahMasuk || !bolehAbsen)
                ? null
                : () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AbsenScreen(
                              tipe: 'masuk', posisi: _posisi)),
                    );
                    if (result == true) _loadData();
                  },
            icon: const Icon(Icons.login),
            label: const Text('Absen Masuk'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (!sudahMasuk || sudahKeluar || !bolehAbsen)
                ? null
                : () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AbsenScreen(
                              tipe: 'keluar', posisi: _posisi)),
                    );
                    if (result == true) _loadData();
                  },
            icon: const Icon(Icons.logout),
            label: const Text('Absen Keluar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}