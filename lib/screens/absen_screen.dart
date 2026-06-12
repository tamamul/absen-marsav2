import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import '../services/api_service.dart';

class AbsenScreen extends StatefulWidget {
  final String tipe;
  final Position? posisi;
  const AbsenScreen({super.key, required this.tipe, this.posisi});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  CameraController? _cam;
  FaceDetector?     _detector;

  bool   _loading   = true;
  bool   _ambil     = false; // sedang proses takePicture
  bool   _validasi  = false; // sedang validasi wajah
  bool   _mengirim  = false;
  File?  _foto;
  String _pesan     = '';
  String _instruksi = 'Posisikan wajah di dalam oval';

  @override
  void initState() {
    super.initState();
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _initCam();
  }

  @override
  void dispose() {
    _cam?.dispose();
    _detector?.close();
    super.dispose();
  }

  Future<void> _initCam() async {
    setState(() => _loading = true);
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() { _loading = false; _pesan = 'Kamera tidak tersedia'; });
        return;
      }
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      _cam = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cam!.initialize();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _pesan = 'Error kamera: $e'; });
    }
  }

  Future<void> _ambilFoto() async {
    if (_cam == null || _ambil) return;
    setState(() {
      _ambil    = true;
      _instruksi = 'Mengambil foto...';
      _pesan    = '';
    });

    try {
      final file = await _cam!.takePicture();
      final foto = File(file.path);

      setState(() {
        _foto    = foto;
        _ambil   = false;
        _validasi = true;
        _instruksi = 'Memvalidasi wajah...';
      });

      // Deteksi wajah dari file foto
      final input = InputImage.fromFile(foto);
      final faces = await _detector!.processImage(input);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _validasi  = false;
          _foto      = null;
          _pesan     = 'Wajah tidak terdeteksi.\nPastikan wajah terlihat jelas.';
          _instruksi = 'Posisikan wajah di dalam oval';
        });
      } else {
        setState(() {
          _validasi  = false;
          _instruksi = '✅ Wajah terdeteksi, mengirim...';
        });
        await Future.delayed(const Duration(milliseconds: 300));
        _kirimAbsen();
      }
    } catch (e) {
      setState(() {
        _ambil    = false;
        _validasi = false;
        _foto     = null;
        _pesan    = 'Gagal: $e';
        _instruksi = 'Posisikan wajah di dalam oval';
      });
    }
  }

  Future<void> _kirimAbsen() async {
    if (_foto == null) return;
    setState(() { _mengirim = true; _pesan = ''; });

    final lat = widget.posisi?.latitude  ?? 0.0;
    final lng = widget.posisi?.longitude ?? 0.0;

    final res = widget.tipe == 'masuk'
        ? await ApiService.absenMasuk(lat, lng, fotoFile: _foto)
        : await ApiService.absenKeluar(lat, lng, fotoFile: _foto);

    setState(() => _mengirim = false);
    if (!mounted) return;

    if (res['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Absen berhasil'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context, true);
    } else {
      setState(() {
        _foto      = null;
        _instruksi = 'Posisikan wajah di dalam oval';
        _pesan     = res['messages']?['error'] ??
            res['message'] ?? 'Absen gagal';
      });
    }
  }

  void _ulangi() {
    setState(() {
      _foto      = null;
      _pesan     = '';
      _ambil     = false;
      _validasi  = false;
      _mengirim  = false;
      _instruksi = 'Posisikan wajah di dalam oval';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMasuk = widget.tipe == 'masuk';
    final color   = isMasuk ? const Color(0xFF1B5E20) : Colors.blue[700]!;
    final label   = isMasuk ? 'Absen Masuk' : 'Absen Keluar';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(label),
        centerTitle: true,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : _foto != null
              ? _buildKonfirmasi(color, label)
              : _buildKamera(color),
    );
  }

  Widget _buildKamera(Color color) {
    final bool sibuk = _ambil || _validasi;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Preview fullscreen
        if (_cam != null) CameraPreview(_cam!),

        // Gradient atas
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),

        // Gradient bawah
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),

        // Oval panduan wajah
        Center(
          child: Container(
            width: 240, height: 300,
            decoration: BoxDecoration(
              border: Border.all(
                color: sibuk ? Colors.orange : color,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(140),
            ),
          ),
        ),

        // Instruksi atas
        Positioned(
          top: 60, left: 20, right: 20,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                _instruksi,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),

        // Error
        if (_pesan.isNotEmpty)
          Positioned(
            top: 130, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red[900]!.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _pesan,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13),
              ),
            ),
          ),

        // Tombol foto bawah
        Positioned(
          bottom: 50, left: 0, right: 0,
          child: Center(
            child: GestureDetector(
              onTap: sibuk ? null : _ambilFoto,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: sibuk
                      ? Colors.grey
                      : color,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: sibuk
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3),
                      )
                    : const Icon(Icons.camera_alt,
                        color: Colors.white, size: 36),
              ),
            ),
          ),
        ),

        // Label tombol
        Positioned(
          bottom: 20, left: 0, right: 0,
          child: Center(
            child: Text(
              sibuk ? 'Memproses...' : 'Tap untuk foto',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKonfirmasi(Color color, String label) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_foto!, fit: BoxFit.cover),

        if (_validasi || _mengirim)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _validasi
                        ? 'Memvalidasi wajah...'
                        : 'Mengirim $label...',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ),

        if (!_validasi && !_mengirim) ...[
          if (_pesan.isNotEmpty)
            Positioned(
              bottom: 120, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red[900],
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_pesan,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: ElevatedButton.icon(
              onPressed: _ulangi,
              icon: const Icon(Icons.refresh),
              label: const Text('Ulangi Foto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}