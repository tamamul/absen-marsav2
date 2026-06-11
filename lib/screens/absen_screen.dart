import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
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

  bool   _loading       = true;
  bool   _mengirim      = false;
  bool   _validasi      = false;
  bool   _wajahTerdeteksi = false;
  File?  _foto;
  String _pesan         = '';
  String _instruksi     = 'Arahkan wajah ke kamera';

  // Liveness: kedip
  bool _kedipSiap   = false; // mata sudah terbuka
  bool _kedipDeteksi = false; // mata sedang tertutup
  bool _kedipOk     = false; // kedip selesai
  bool _memproses   = false;
  int  _lastMs      = 0;
  int  _frameMata   = 0;

  @override
  void initState() {
    super.initState();
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
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
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cam!.initialize();
      if (!mounted) return;
      setState(() { _loading = false; });
      _cam!.startImageStream(_onFrame);
    } catch (e) {
      setState(() { _loading = false; _pesan = 'Error kamera: $e'; });
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_memproses || _kedipOk || _foto != null || !mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 250) return;
    _lastMs   = now;
    _memproses = true;

    try {
      final input = _toInput(img);
      if (input == null) { _memproses = false; return; }

      final faces = await _detector!.processImage(input);
      if (!mounted) { _memproses = false; return; }

      if (faces.isEmpty) {
        setState(() {
          _instruksi    = 'Arahkan wajah ke kamera';
          _kedipSiap    = false;
          _kedipDeteksi = false;
          _frameMata    = 0;
        });
        _memproses = false;
        return;
      }

      final face   = faces.first;
      final mata   = ((face.leftEyeOpenProbability  ?? 1.0) +
                      (face.rightEyeOpenProbability ?? 1.0)) / 2;
      final eulerY = face.headEulerAngleY ?? 0.0;
      final eulerX = face.headEulerAngleX ?? 0.0;

      // Cek arah wajah
      if (eulerY.abs() > 30 || eulerX.abs() > 25) {
        setState(() => _instruksi = 'Hadapkan wajah ke depan');
        _memproses = false;
        return;
      }

      // Mata harus terbuka stabil dulu
      if (!_kedipSiap) {
        if (mata > 0.7) {
          _frameMata++;
          setState(() => _instruksi = 'Wajah terdeteksi, buka mata lebar...');
          if (_frameMata >= 3) {
            setState(() {
              _kedipSiap = true;
              _instruksi = '👁️ Kedipkan mata sekali';
            });
          }
        } else {
          _frameMata = 0;
        }
        _memproses = false;
        return;
      }

      // Deteksi kedip: terbuka → tertutup → terbuka
      if (!_kedipDeteksi && mata < 0.2) {
        setState(() {
          _kedipDeteksi = true;
          _instruksi    = '👁️ Buka mata...';
        });
      } else if (_kedipDeteksi && mata > 0.6) {
        // Kedip selesai → ambil foto
        setState(() {
          _kedipOk   = true;
          _instruksi = '✅ Kedip terdeteksi! Mengambil foto...';
        });
        _ambilFoto();
      }
    } catch (_) {}

    _memproses = false;
  }

  Future<void> _ambilFoto() async {
    try {
      await _cam!.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 300));
      final file = await _cam!.takePicture();
      if (!mounted) return;

      setState(() {
        _foto     = File(file.path);
        _validasi = true;
        _instruksi = 'Memvalidasi wajah...';
      });

      // Deteksi wajah pada foto hasil capture
      await _validasiFoto(File(file.path));
    } catch (e) {
      setState(() { _pesan = 'Gagal ambil foto: $e'; });
      _ulangi();
    }
  }

  Future<void> _validasiFoto(File file) async {
    try {
      final input = InputImage.fromFile(file);
      final faces = await _detector!.processImage(input);

      if (!mounted) return;

      if (faces.isEmpty) {
        // Tidak ada wajah di foto → ulangi
        setState(() {
          _pesan    = 'Wajah tidak terdeteksi di foto. Coba lagi.';
          _validasi = false;
        });
        await Future.delayed(const Duration(seconds: 2));
        _ulangi();
      } else {
        // Ada wajah → kirim
        setState(() {
          _wajahTerdeteksi = true;
          _validasi        = false;
          _instruksi       = '✅ Wajah valid, mengirim...';
        });
        await Future.delayed(const Duration(milliseconds: 500));
        _kirimAbsen();
      }
    } catch (e) {
      setState(() { _pesan = 'Validasi gagal: $e'; _validasi = false; });
      _ulangi();
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
            res['message'] ?? 'Absen gagal';
      });
      _ulangi();
    }
  }

  void _ulangi() {
    setState(() {
      _foto             = null;
      _pesan            = '';
      _kedipSiap        = false;
      _kedipDeteksi     = false;
      _kedipOk          = false;
      _wajahTerdeteksi  = false;
      _validasi         = false;
      _frameMata        = 0;
      _instruksi        = 'Arahkan wajah ke kamera';
    });
    _cam?.startImageStream(_onFrame);
  }

  InputImage? _toInput(CameraImage img) {
    try {
      final cam      = _cam!.description;
      final rotation = InputImageRotationValue.fromRawValue(
              cam.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(img.format.raw);
      if (format == null) return null;

      if (img.planes.length == 1) {
        return InputImage.fromBytes(
          bytes: img.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(img.width.toDouble(), img.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: img.planes[0].bytesPerRow,
          ),
        );
      } else {
        final buf = WriteBuffer();
        for (final p in img.planes) buf.putUint8List(p.bytes);
        return InputImage.fromBytes(
          bytes: buf.done().buffer.asUint8List(),
          metadata: InputImageMetadata(
            size: Size(img.width.toDouble(), img.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: img.planes[0].bytesPerRow,
          ),
        );
      }
    } catch (_) {
      return null;
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
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : _foto != null
              ? _buildKonfirmasi(color, label)
              : _buildKamera(color),
    );
  }

  Widget _buildKamera(Color color) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Preview kamera
        CameraPreview(_cam!),

        // Gradient atas
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 140,
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
            height: 180,
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
            width: 230, height: 290,
            decoration: BoxDecoration(
              border: Border.all(
                color: _kedipOk
                    ? Colors.green
                    : _kedipSiap
                        ? color
                        : Colors.white54,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(130),
            ),
          ),
        ),

        // Instruksi atas
        Positioned(
          top: 28, left: 20, right: 20,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                _instruksi,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _kedipOk ? Colors.green : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        // Step indicator bawah
        Positioned(
          bottom: 40, left: 20, right: 20,
          child: _buildSteps(color),
        ),

        // Error
        if (_pesan.isNotEmpty)
          Positioned(
            bottom: 110, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[900],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_pesan,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Widget _buildSteps(Color color) {
    final steps = [
      {'label': 'Wajah',  'icon': Icons.face,             'done': _kedipSiap || _kedipOk},
      {'label': 'Kedip',  'icon': Icons.remove_red_eye,   'done': _kedipOk},
      {'label': 'Foto',   'icon': Icons.camera_alt,       'done': false},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Container(
            width: 36, height: 2,
            color: (steps[i ~/ 2]['done'] as bool)
                ? color
                : Colors.white24,
          );
        }
        final s    = steps[i ~/ 2];
        final done = s['done'] as bool;
        final curr = !done && (i == 0
            ? !_kedipSiap
            : i == 2
                ? _kedipSiap && !_kedipOk
                : _kedipOk);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: done
                    ? color
                    : curr
                        ? color.withOpacity(0.25)
                        : Colors.white12,
                shape: BoxShape.circle,
                border: Border.all(
                    color: done || curr ? color : Colors.white24,
                    width: 2),
              ),
              child: Icon(
                s['icon'] as IconData,
                color: done
                    ? Colors.white
                    : curr
                        ? Colors.white70
                        : Colors.white30,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(s['label'] as String,
                style: TextStyle(
                    fontSize: 10,
                    color: done || curr
                        ? Colors.white
                        : Colors.white38)),
          ],
        );
      }),
    );
  }

  Widget _buildKonfirmasi(Color color, String label) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_foto!, fit: BoxFit.cover),

        // Loading validasi / kirim
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
                        color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

        // Error + tombol ulangi
        if (!_validasi && !_mengirim) ...[
          if (_pesan.isNotEmpty)
            Positioned(
              bottom: 110, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.red[900],
                    borderRadius: BorderRadius.circular(10)),
                child: Text(_pesan,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: ElevatedButton.icon(
              onPressed: _ulangi,
              icon: const Icon(Icons.refresh),
              label: const Text('Ulangi'),
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