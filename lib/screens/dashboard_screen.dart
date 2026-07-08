import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'dart:async';
import '../services/api_service.dart';
import '../models/pegawai_model.dart';
import '../models/presensi_model.dart';
import '../helpers/hari_besar.dart';
import '../helpers/hari_besar_custom.dart';
import '../helpers/cache_manager.dart';
import 'absen_screen.dart';
import 'login_screen.dart';
import 'riwayat_screen.dart';
import 'galeri_screen.dart';
import 'profil_screen.dart';
import 'kalender_screen.dart';
import 'pengumuman_screen.dart';
import 'absensi_siswa_screen.dart';
import 'rekap_siswa_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  PegawaiModel?  _pegawai;
  PresensiModel? _presensi;
  bool   _loading      = true;
  bool   _cekLokasi    = false;
  bool?  _didalam;
  String _pesanLokasi  = '';
  Position? _posisi;
  int    _navIndex     = 0;
  File?  _fotoProfil;
  int?   _myUserId;

  late DateTime _now;

  List<HariBesar>       _hariBesarHariIni = [];
  List<HariBesarCustom> _customHariIni    = [];
  List<HariBesarCustom> _customMendatang  = [];

  List<String> _bgUrls = [];
  int _bgIndex         = 0;
  final PageController _bgCtrl = PageController();

  static const Color _primary = Color(0xFF1B5E20);
  Timer? _autoSlideTimer; 

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _loadFotoProfil();
    _loadUserId();
    _loadData();
    _loadBgGaleri();
    AppCacheManager.autoCleanup();
    Future.delayed(const Duration(minutes: 1), _tickWaktu);
    // Timer auto-slide akan dimulai setelah _loadBgGaleri selesai
  }

  @override
  void dispose() {
    _stopAutoSlide(); // hentikan timer
    _bgCtrl.dispose();
    super.dispose();
  }
  
  void _startAutoSlide() {
    _stopAutoSlide();
    if (_bgUrls.length > 1) {
      _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (_bgCtrl.hasClients && mounted) {
          int next = (_bgIndex + 1) % _bgUrls.length;
          _bgCtrl.animateToPage(
            next,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  // Hentikan auto-slide
  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
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

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('user_data');
    if (raw != null) {
      final user = jsonDecode(raw);
      setState(() => _myUserId =
          int.tryParse(user['id'].toString()));
    }
  }

  Future<void> _loadBgGaleri() async {
  try {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final tanggalHariIni =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final tanggalKemarin =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    // Ambil data untuk dua tanggal secara paralel
    final results = await Future.wait([
      ApiService.getGaleriHadir(tanggal: tanggalHariIni),
      ApiService.getGaleriHadir(tanggal: tanggalKemarin),
    ]);

    final urls = <String>[];

    // Fungsi ekstrak URL dari response
    void extractUrls(Map<String, dynamic> res) {
      if (res['status'] == true) {
        final list = List<Map<String, dynamic>>.from(res['data'] ?? []);
        for (final item in list) {
          final masuk = item['foto_masuk'] ?? '';
          final keluar = item['foto_keluar'] ?? '';
          if (masuk.isNotEmpty) {
            urls.add(
                'https://smk-maarif9kebumen.com/present/public/assets/img/foto_presensi/masuk/$masuk');
          }
          if (keluar.isNotEmpty) {
            urls.add(
                'https://smk-maarif9kebumen.com/present/public/assets/img/foto_presensi/keluar/$keluar');
          }
        }
      }
    }

    extractUrls(results[0]); // hari ini
    extractUrls(results[1]); // kemarin

    urls.shuffle();
    if (mounted) {
      setState(() {
        _bgUrls = urls.take(10).toList();
      });
      _startAutoSlide();
    }
  } catch (_) {
    // Jika gagal, biarkan kosong atau tampilkan default
    if (mounted) {
      setState(() {
        _bgUrls = [];
      });
    }
  }
}

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final resPegawai  = await ApiService.getPegawaiProfil();
      final resPresensi = await ApiService.getAbsenHariIni();
      final now         = DateTime.now();
      final allCustom   = await HariBesarCustomDb.getAll();

      setState(() {
        if (resPegawai['status'] == true) {
          _pegawai = PegawaiModel.fromJson(resPegawai['data']);
        }
        if (resPresensi['status'] == true &&
            resPresensi['data'] != null) {
          _presensi =
              PresensiModel.fromJson(resPresensi['data']);
        }
        _hariBesarHariIni = HariBesarHelper.getHariIni(now);
        _customHariIni =
            allCustom.where((h) => h.cocokDengan(now)).toList();
        _customMendatang = allCustom;
        _loading         = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
    await _validasiLokasi();
  }

  Future<void> _validasiLokasi() async {
    setState(() { _cekLokasi = true; _didalam = null; });
    try {
      LocationPermission perm =
          await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _cekLokasi   = false;
          _didalam     = false;
          _pesanLokasi = 'Izin lokasi ditolak';
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _posisi = pos;
      final res =
          await ApiService.cekLokasi(pos.latitude, pos.longitude);
      setState(() {
        _cekLokasi   = false;
        _didalam     = res['didalam'] == true;
        _pesanLokasi = res['message'] ?? '';
      });
    } catch (_) {
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
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _showProfilMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(
            vertical: 20, horizontal: 16),
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
            CircleAvatar(
              radius: 42,
              backgroundColor: _primary,
              backgroundImage: _fotoProfil != null
                  ? FileImage(_fotoProfil!) : null,
              child: _fotoProfil == null
                  ? Text(
                      _pegawai?.nama.isNotEmpty == true
                          ? _pegawai!.nama[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 36,
                          color: Colors.white,
                          fontWeight: FontWeight.bold))
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
                        builder: (_) =>
                            ProfilScreen(pegawai: _pegawai)));
                _loadFotoProfil();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.logout, color: Colors.red),
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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
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
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _toolItem(Icons.calendar_month, 'Kalender',
                    _primary, () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const KalenderScreen()));
                }),
                _toolItem(Icons.how_to_reg, 'Absensi\nSiswa',
                    Colors.teal, () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AbsensiSiswaScreen()));
                }),
                _toolItem(Icons.bar_chart, 'Rekap\nSiswa',
                    Colors.indigo, () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const RekapSiswaScreen()));
                }),
                _toolItem(Icons.campaign, 'Pengumuman',
                    Colors.orange, () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const PengumumanScreen()));
                }),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _toolItem(IconData icon, String label, Color color,
      VoidCallback onTap) {
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

  // ========== METHOD UNTUK AGENDA MENDATANG ==========
  List<Map<String, dynamic>> _getAgendaMendatang() {
    final mendatang = HariBesarHelper.getMendatang(_now, hari: 30);
    final agenda = <Map<String, dynamic>>[];
    for (final h in mendatang) {
      agenda.add({
        'tanggal': h.tanggal,
        'nama': h.nama,
        'emoji': h.emoji ?? '📅',
      });
    }
    for (final h in _customMendatang) {
      final dt = DateTime(
        h.tahunan ? _now.year : h.tanggalYear,
        h.tanggalMonth, h.tanggalDay,
      );
      if (dt.isAfter(_now) && dt.isBefore(_now.add(const Duration(days: 30)))) {
        agenda.add({
          'tanggal': dt,
          'nama': h.nama,
          'emoji': h.emoji,
        });
      }
    }
    agenda.sort((a, b) => (a['tanggal'] as DateTime).compareTo(b['tanggal'] as DateTime));
    return agenda;
  }

  // ========== STATUS RINGKAS (BOX DI SAMPING NAMA) ==========
  Widget _buildStatusRingkas() {
    final sudahMasuk = _presensi?.sudahMasuk ?? false;
    final sudahKeluar = _presensi?.sudahKeluar ?? false;
    String statusText;
    Color statusColor;
    IconData statusIcon;
    if (sudahMasuk && sudahKeluar) {
      statusText = 'Lengkap';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (sudahMasuk) {
      statusText = 'Masuk ${_presensi?.jamMasuk ?? ''}';
      statusColor = Colors.orange;
      statusIcon = Icons.login;
    } else {
      statusText = 'Belum';
      statusColor = Colors.grey;
      statusIcon = Icons.access_time;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sudahMasuk  = _presensi?.sudahMasuk  ?? false;
    final sudahKeluar = _presensi?.sudahKeluar ?? false;
    final bolehAbsen  = _didalam == true;

    return Scaffold(
  backgroundColor: const Color(0xFFF0F4F0),
  appBar: AppBar(
    backgroundColor: _primary,
    foregroundColor: Colors.white,
    elevation: 0,
    title: Row(
      children: [
        Image.asset(
          'assets/logo.png',
          width: 41,
          height: 41,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 10),
        const Text(
          'Absen-MARSA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
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
                    ? FileImage(_fotoProfil!) : null,
                child: _fotoProfil == null
                    ? Text(
                        _pegawai?.nama.isNotEmpty == true
                            ? _pegawai!.nama[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: _navIndex == 0
          ? _buildBeranda(sudahMasuk, sudahKeluar, bolehAbsen)
          : _navIndex == 1
              ? const RiwayatScreen()
              : const GaleriScreen(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ========== BERANDA ==========
  Widget _buildBeranda(
      bool sudahMasuk, bool sudahKeluar, bool bolehAbsen) {
    return Column(
      children: [
        _buildHeader(),
        const Spacer(),
        _buildBottomAbsen(sudahMasuk, sudahKeluar, bolehAbsen),
      ],
    );
  }

  // ========== HEADER (diperbesar, tata letak baru) ==========
 Widget _buildHeader() {
    final hijri = HijriCalendar.fromDate(_now);
    final agenda = _getAgendaMendatang();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _bgUrls.isEmpty
              ? Container(color: Colors.grey.shade900)
              : PageView.builder(
                  controller: _bgCtrl,
                  itemCount: _bgUrls.length,
                  onPageChanged: (i) {
                    setState(() => _bgIndex = i);
                    // reset timer saat user geser manual (opsional)
                    // _startAutoSlide(); // jika ingin reset timer saat interaksi manual
                  },
                  itemBuilder: (_, i) => CachedNetworkImage(
                    imageUrl: _bgUrls[i],
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 500),
                    placeholder: (_, __) => Container(color: Colors.grey.shade900),
                    errorWidget: (_, __, ___) => Container(color: Colors.grey.shade900),
                  ),
                ),
          // blur & overlay tetap ...
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.45),
                  ],
                ),
              ),
            ),
          ),
          // Konten
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ===== BAGIAN ATAS: TANGGAL & JAM + AGENDA =====
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                HariBesarHelper.namaHari(_now),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 15),
                              ),
                              Text(
                                '${_now.day} ${HariBesarHelper.namaBulan(_now.month)} ${_now.year}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${hijri.hDay} ${HariBesarHelper.namaBulanHijri(hijri.hMonth)} ${hijri.hYear} H',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_now.hour.toString().padLeft(2,'0')}:${_now.minute.toString().padLeft(2,'0')}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const KalenderScreen())),
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
          // Agenda mendatang (horizontal)
if (agenda.isNotEmpty) ...[
  const SizedBox(height: 8),
  SizedBox(
    height: 50,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: agenda.length,
      itemBuilder: (_, i) {
        final e = agenda[i];
        final dt = e['tanggal'] as DateTime;
        final selisih = dt.difference(_now).inDays;
        return GestureDetector(
          onTap: () {
            // Navigasi ke halaman pengumuman
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PengumumanScreen(),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Text(e['emoji'] as String,
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  e['nama'] as String,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 4),
                Text(
                  '${selisih}h',
                  style: TextStyle(
                    color: selisih <= 3
                        ? Colors.red[300]
                        : Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ),
],
                // ===== BAGIAN BAWAH: NAMA + STATUS BOX + PAGINATION =====
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            _pegawai?.nama ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusRingkas(),
                        ],
                      ),
                    ),
                    if (_bgUrls.length > 1)
                      Row(
                        children: List.generate(
                          _bgUrls.length > 5 ? 5 : _bgUrls.length,
                          (i) => Container(
                            width: i == _bgIndex ? 12 : 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i == _bgIndex
                                  ? Colors.white
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== BOTTOM ABSEN (tetap) ==========
  Widget _buildBottomAbsen(
      bool sudahMasuk, bool sudahKeluar, bool bolehAbsen) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lokasi inline
            Row(
              children: [
                _cekLokasi
                    ? SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange))
                    : Icon(
                        _didalam == true
                            ? Icons.location_on
                            : Icons.location_off,
                        size: 14,
                        color: _didalam == true
                            ? Colors.green
                            : Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _cekLokasi
                        ? 'Mengecek lokasi...'
                        : _pesanLokasi,
                    style: TextStyle(
                        fontSize: 11,
                        color: _didalam == true
                            ? Colors.green[700]
                            : Colors.red[700]),
                  ),
                ),
                GestureDetector(
                  onTap:
                      _cekLokasi ? null : _validasiLokasi,
                  child: const Icon(Icons.refresh,
                      size: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Tombol absen
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (sudahMasuk || !bolehAbsen)
                        ? null
                        : () async {
                            final r = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AbsenScreen(
                                        tipe: 'masuk',
                                        posisi: _posisi)));
                            if (r == true) _loadData();
                          },
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Absen Masuk'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.grey[200],
                      disabledForegroundColor:
                          Colors.grey[400],
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (!sudahMasuk ||
                            sudahKeluar ||
                            !bolehAbsen)
                        ? null
                        : () async {
                            final r = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AbsenScreen(
                                        tipe: 'keluar',
                                        posisi: _posisi)));
                            if (r == true) _loadData();
                          },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Absen Keluar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.grey[200],
                      disabledForegroundColor:
                          Colors.grey[400],
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========== BOTTOM NAVIGASI (tetap) ==========
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
              _navItem(0, Icons.home_outlined,
                  Icons.home, 'Beranda'),
              _navItem(1, Icons.history_outlined,
                  Icons.history, 'Riwayat'),
              _navItem(2, Icons.photo_library_outlined,
                  Icons.photo_library, 'Galeri'),
              Expanded(
                child: GestureDetector(
                  onTap: _showToolsMenu,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.apps,
                            color: _primary, size: 22),
                      ),
                      const SizedBox(height: 2),
                      const Text('Tools',
                          style: TextStyle(
                              fontSize: 10,
                              color: _primary,
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

  Widget _navItem(int index, IconData iconOff,
      IconData iconOn, String label) {
    final active = _navIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _navIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? iconOn : iconOff,
              color: active ? _primary : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: active ? _primary : Colors.grey,
                    fontWeight: active
                        ? FontWeight.bold
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}