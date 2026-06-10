import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart';

class AbsenScreen extends StatefulWidget {
  final String tipe;
  final Position? posisi;
  const AbsenScreen({super.key, required this.tipe, this.posisi});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  CameraController? _cameraController;
  bool _cameraReady  = false;
  bool _loading      = true;
  bool _mengirim     = false;
  File? _foto;
  String _pesan      = '';

  @override
  void initState() {
    super.initState();
    _initKamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initKamera() async {
    setState(() => _loading = true);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _loading = false;
          _pesan   = 'Kamera tidak tersedia';
        });
        return;
      }

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

      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _loading     = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _pesan   = 'Gagal buka kamera: $e';
      });
    }
  }

  Future<void> _ambilFoto() async {
    if (_cameraController == null || !_cameraReady) return;
    try {
      final file = await _cameraController!.takePicture();
      setState(() => _foto = File(file.path));
    } catch (e) {
      setState(() => _pesan = 'Gagal ambil foto: $e');
    }
  }

  void _ulangi() {
    setState(() {
      _foto  = null;
      _pesan = '';
    });
  }

  Future<void> _kirimAbsen() async {
    if (_foto == null) return;

    setState(() {
      _mengirim = true;
      _pesan    = '';
    });

    Map<String, dynamic> res;
    final lat = widget.posisi?.latitude ?? 0.0;
final lng = widget.posisi?.longitude ?? 0.0;

if (widget.tipe == 'masuk') {
  res = await ApiService.absenMasuk(lat, lng, fotoFile: _foto);
} else {
  res = await ApiService.absenKeluar(lat, lng, fotoFile: _foto);
}

    setState(() => _mengirim = false);

    if (res['status'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Absen berhasil'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context, true);
    } else {
      setState(() {
        _pesan = res['messages']?['error'] ??
            res['message'] ??
            'Absen gagal';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMasuk = widget.tipe == 'masuk';
    final color   = isMasuk ? const Color(0xFF1B5E20) : Colors.blue[700]!;
    final label   = isMasuk ? 'Absen Masuk' : 'Absen Keluar';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: Text(label),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : !_cameraReady
              ? Center(
                  child: Text(_pesan,
                      style: const TextStyle(color: Colors.white)))
              : _foto == null
                  ? _buildKamera(color)
                  : _buildKonfirmasi(color, label),
    );
  }

  // Tampilan kamera live
  Widget _buildKamera(Color color) {
    return Stack(
      children: [
        // Preview kamera fullscreen
        SizedBox.expand(
          child: CameraPreview(_cameraController!),
        ),

        // Label atas
        Positioned(
          top: 16, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Posisikan wajah di tengah',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),

        // Tombol foto bawah
        Positioned(
          bottom: 48, left: 0, right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _ambilFoto,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const Icon(Icons.camera_alt,
                    size: 40, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Tampilan konfirmasi setelah foto
  Widget _buildKonfirmasi(Color color, String label) {
    return Column(
      children: [
        // Preview foto
        Expanded(
          child: Image.file(_foto!, fit: BoxFit.cover,
              width: double.infinity),
        ),

        // Error
        if (_pesan.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.red[900],
            width: double.infinity,
            child: Text(_pesan,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center),
          ),

        // Tombol bawah
        Container(
          color: Colors.black,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Ulangi
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _mengirim ? null : _ulangi,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Ulangi',
                      style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Kirim
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _mengirim ? null : _kirimAbsen,
                  icon: _mengirim
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(_mengirim ? 'Mengirim...' : label),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}