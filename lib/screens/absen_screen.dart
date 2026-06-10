import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class AbsenScreen extends StatefulWidget {
  final String tipe; // 'masuk' atau 'keluar'
  const AbsenScreen({super.key, required this.tipe});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  bool _loadingGps = false;
  bool _loadingAbsen = false;
  Position? _position;
  String _statusGps = 'Belum ambil lokasi';
  String _pesanError = '';

  Future<void> _ambilLokasi() async {
    setState(() {
      _loadingGps = true;
      _statusGps = 'Mengambil lokasi...';
      _pesanError = '';
    });

    try {
      // Cek permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _statusGps = 'Izin lokasi ditolak';
            _loadingGps = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _statusGps = 'Izin lokasi ditolak permanen.\nBuka pengaturan HP.';
          _loadingGps = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _position = pos;
        _statusGps =
            'Lat: ${pos.latitude.toStringAsFixed(6)}\nLng: ${pos.longitude.toStringAsFixed(6)}\nAkurasi: ${pos.accuracy.toStringAsFixed(0)}m';
        _loadingGps = false;
      });
    } catch (e) {
      setState(() {
        _statusGps = 'Gagal ambil lokasi: $e';
        _loadingGps = false;
      });
    }
  }

  Future<void> _kirimAbsen() async {
    if (_position == null) {
      setState(() => _pesanError = 'Ambil lokasi dulu!');
      return;
    }

    setState(() {
      _loadingAbsen = true;
      _pesanError = '';
    });

    Map<String, dynamic> res;
    if (widget.tipe == 'masuk') {
      res = await ApiService.absenMasuk(_position!.latitude, _position!.longitude);
    } else {
      res = await ApiService.absenKeluar(_position!.latitude, _position!.longitude);
    }

    setState(() => _loadingAbsen = false);

    if (res['status'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Absen berhasil'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _pesanError = res['messages']?['error'] ??
            res['message'] ??
            'Absen gagal';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMasuk = widget.tipe == 'masuk';
    final color   = isMasuk ? const Color(0xFF1B5E20) : Colors.blue[700]!;
    final icon    = isMasuk ? Icons.login : Icons.logout;
    final label   = isMasuk ? 'Absen Masuk' : 'Absen Keluar';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: Text(label),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(icon, size: 64, color: color),
                    const SizedBox(height: 8),
                    Text(label,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    const SizedBox(height: 4),
                    Text(
                      TimeOfDay.now().format(context),
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // GPS Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Lokasi GPS',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_statusGps,
                        style: TextStyle(
                            color: _position != null
                                ? Colors.green[700]
                                : Colors.grey)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loadingGps ? null : _ambilLokasi,
                        icon: _loadingGps
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.my_location),
                        label: Text(_loadingGps
                            ? 'Mengambil...'
                            : 'Ambil Lokasi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Error
            if (_pesanError.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(_pesanError,
                    style: const TextStyle(color: Colors.red)),
              ),

            const Spacer(),

            // Tombol absen
            ElevatedButton.icon(
              onPressed:
                  (_position == null || _loadingAbsen) ? null : _kirimAbsen,
              icon: _loadingAbsen
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(icon),
              label: Text(_loadingAbsen ? 'Mengirim...' : label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}