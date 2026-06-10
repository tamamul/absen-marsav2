import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/pegawai_model.dart';
import '../models/presensi_model.dart';
import 'absen_screen.dart';
import 'login_screen.dart';
import 'riwayat_screen.dart';
import 'dart:convert';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  PegawaiModel? _pegawai;
  PresensiModel? _presensi;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Absen MARSA'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProfileCard(),
                    const SizedBox(height: 16),
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildAbsenButtons(),
                    const SizedBox(height: 16),
                    _buildRiwayatButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFF1B5E20),
              child: Text(
                _pegawai?.nama.isNotEmpty == true
                    ? _pegawai!.nama[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_pegawai?.nama ?? '-',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(_pegawai?.jabatan ?? '-',
                      style: const TextStyle(color: Colors.grey)),
                  Text(_pegawai?.namaLokasi ?? '-',
                      style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final sudahMasuk  = _presensi?.sudahMasuk ?? false;
    final sudahKeluar = _presensi?.sudahKeluar ?? false;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status Hari Ini',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            Row(
              children: [
                _buildStatusItem(
                  icon: Icons.login,
                  label: 'Masuk',
                  value: sudahMasuk ? _presensi!.jamMasuk : '-',
                  color: sudahMasuk ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 16),
                _buildStatusItem(
                  icon: Icons.logout,
                  label: 'Keluar',
                  value: sudahKeluar ? _presensi!.jamKeluar : '-',
                  color: sudahKeluar ? Colors.blue : Colors.grey,
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500)),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsenButtons() {
    final sudahMasuk  = _presensi?.sudahMasuk ?? false;
    final sudahKeluar = _presensi?.sudahKeluar ?? false;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: sudahMasuk
                ? null
                : () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AbsenScreen(tipe: 'masuk')),
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
            onPressed: (!sudahMasuk || sudahKeluar)
                ? null
                : () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AbsenScreen(tipe: 'keluar')),
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

  Widget _buildRiwayatButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RiwayatScreen()),
        ),
        icon: const Icon(Icons.history),
        label: const Text('Riwayat Absensi'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}