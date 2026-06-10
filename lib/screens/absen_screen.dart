import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../services/api_service.dart';

class AbsenScreen extends StatefulWidget {
  final String tipe;
  const AbsenScreen({super.key, required this.tipe});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  bool _loadingGps   = false;
  bool _loadingAbsen = false;
  Position? _position;
  String _statusGps  = 'Belum ambil lokasi';
  String _pesanError = '';
  File? _foto;
  CameraController? _cameraController;
  bool _cameraReady  = false;
  bool _showCamera   = false;

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _ambilLokasi() async {
    setState(() {
      _loadingGps = true;
      _statusGps  = 'Mengambil lokasi...';
      _pesanError = '';
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _statusGps  = 'Izin lokasi ditolak';
            _loadingGps = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _statusGps  = 'Izin lokasi ditolak permanen.\nBuka pengaturan HP.';
          _loadingGps = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _position  = pos;
        _statusGps = 'Lat: ${pos.latitude.toStringAsFixed(6)}\n'
            'Lng: ${pos.longitude.toStringAsFixed(6)}\n'
            'Akurasi: ${pos.accuracy.toStringAsFixed(0)}m';
        _loadingGps = false;
      });
    } catch (e) {
      setState(() {
        _statusGps  = 'Gagal ambil lokasi: $e';
        _loadingGps = false;
      });
    }
  }

  Future<void> _bukaKamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() => _pesanError = 'Kamera tidak tersedia');
      return;
    }

    // Pakai kamera depan jika ada
    final kamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      kamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    setState(() {
      _cameraReady = true;
      _showCamera  = true;
    });
  }

  Future<void> _ambilFoto() async {
    if (_cameraController == null || !_cameraReady) return;
    try {
      final file = await _cameraController!.takePicture();
      await _cameraController!.dispose();
      setState(() {
        _foto       = File(file.path);
        _showCamera = false;
        _cameraReady = false;
      });
    } catch (e) {
      setState(() => _pesanError = 'Gagal ambil foto: $e');
    }
  }

  Future<void> _kirimAbsen() async {
    if (_position == null) {
      setState(() => _pesanError = 'Ambil lokasi dulu!');
      return;
    }
    if (_foto == null) {
      setState(() => _pesanError = 'Ambil foto dulu!');
      return;
    }

    setState(() {
      _loadingAbsen = true;
      _pesanError   = '';
    });

    Map<String, dynamic> res;
    if (widget.tipe == 'masuk') {
      res = await ApiService.absenMasuk(
          _position!.latitude, _position!.longitude, fotoFile: _foto);
    } else {
      res = await ApiService.absenKeluar(
          _position!.latitude, _position!.longitude, fotoFile: _foto);
    }

    setState(() => _loadingAbsen = false);

    if (res['status'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Absen berhasil'),
        backgroundColor: Colors.green,
      ));
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

    // Tampilan kamera fullscreen
    if (_showCamera && _cameraReady) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            SizedBox.expand(child: CameraPreview(_cameraController!)),
            Positioned(
              bottom: 40,
              left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _ambilFoto,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 4),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 36, color: Colors.black),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 48, left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () async {
                  await _cameraController?.dispose();
                  setState(() {
                    _showCamera  = false;
                    _cameraReady = false;
                  });
                },
              ),
            ),
          ],
        ),
      );
    }

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
            // Info waktu
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Icon(icon, size: 56, color: color),
                  const SizedBox(height: 8),
                  Text(label,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text(TimeOfDay.now().format(context),
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),

            const SizedBox(height: 12),

            // GPS + Foto berdampingan
            Row(children: [
              // GPS
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Icon(Icons.location_on,
                          color: _position != null
                              ? Colors.green
                              : Colors.grey,
                          size: 32),
                      const SizedBox(height: 4),
                      Text(
                        _position != null ? 'Lokasi OK' : 'Belum',
                        style: TextStyle(
                            color: _position != null
                                ? Colors.green
                                : Colors.grey,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _loadingGps ? null : _ambilLokasi,
                          child: _loadingGps
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Text('Ambil GPS',
                                  style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Foto
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      _foto != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_foto!,
                                  height: 60,
                                  width: double.infinity,
                                  fit: BoxFit.cover),
                            )
                          : const Icon(Icons.face,
                              size: 32, color: Colors.grey),
                      const SizedBox(height: 4),
                      Text(
                        _foto != null ? 'Foto OK' : 'Belum',
                        style: TextStyle(
                            color: _foto != null
                                ? Colors.green
                                : Colors.grey,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _bukaKamera,
                          child: const Text('Ambil Foto',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 12),

            // Error
            if (_pesanError.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
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
              onPressed: (_position == null ||
                      _foto == null ||
                      _loadingAbsen)
                  ? null
                  : _kirimAbsen,
              icon: _loadingAbsen
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(icon),
              label: Text(
                  _loadingAbsen ? 'Mengirim...' : label,
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