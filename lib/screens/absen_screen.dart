import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:async';
import '../services/api_service.dart';

class AbsenScreen extends StatefulWidget {
  final String tipe;
  final Position? posisi;
  const AbsenScreen({super.key, required this.tipe, this.posisi});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen>
    with WidgetsBindingObserver {
  CameraController? _cam;
  FaceDetector?     _detector;

  bool   _isReady   = false;
  bool   _mengirim  = false;
  bool   _validasi  = false;
  bool   _memproses = false;
  int    _lastMs    = 0;
  File?  _foto;
  String _pesan     = '';
  String _instruksi = 'Arahkan wajah ke kamera';

  // Liveness — threshold longgar
  bool _mataSiap    = false; // mata terbuka minimal beberapa frame
  bool _kedipMulai  = false; // mata mulai menutup
  bool _kedipOk     = false; // kedip selesai
  int  _frameMata   = 0;

  // Threshold longgar
  static const double _mataButaThr  = 0.25; // mata dianggap tertutup
  static const double _mataBukaThr  = 0.55; // mata dianggap terbuka
  static const int    _minFrameMata = 3;    // minimal frame mata buka

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initCam();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    _detector?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cam?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCam();
    }
  }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _pesan = 'Kamera tidak tersedia');
        return;
      }
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );

      // Coba veryHigh + bgra8888 dulu
      try {
        _cam = CameraController(
          cam, ResolutionPreset.veryHigh,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.bgra8888,
        );
        await _cam!.initialize();
      } catch (_) {
        // Fallback ke high tanpa paksa format
        _cam = CameraController(
          cam, ResolutionPreset.high,
          enableAudio: false,
        );
        await _cam!.initialize();
      }

      if (!mounted) return;
      setState(() => _isReady = true);
      _cam!.startImageStream(_onFrame);
    } catch (e) {
      setState(() => _pesan = 'Error kamera: $e');
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_memproses || _kedipOk || _foto != null || !mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 300) return;
    _lastMs    = now;
    _memproses = true;

    try {
      final input = _toInput(img);
      if (input == null) { _memproses = false; return; }

      final faces = await _detector!.processImage(input);
      if (!mounted) { _memproses = false; return; }

      if (faces.isEmpty) {
        setState(() {
          _instruksi = 'Arahkan wajah ke kamera';
          _mataSiap  = false;
          _kedipMulai = false;
          _frameMata  = 0;
        });
        _memproses = false;
        return;
      }

      final face   = faces.first;
      final eulerY = face.headEulerAngleY ?? 0.0;
      final eulerX = face.headEulerAngleX ?? 0.0;
      final mata   = ((face.leftEyeOpenProbability  ?? 1.0) +
                      (face.rightEyeOpenProbability ?? 1.0)) / 2;

      // Kepala tidak boleh terlalu miring — threshold longgar
      if (eulerY.abs() > 35 || eulerX.abs() > 30) {
        setState(() => _instruksi = 'Hadapkan wajah ke depan');
        _memproses = false;
        return;
      }

      // Step 1: tunggu mata terbuka stabil
      if (!_mataSiap) {
        if (mata > _mataBukaThr) {
          _frameMata++;
          setState(() => _instruksi = 'Wajah terdeteksi 👤');
          if (_frameMata >= _minFrameMata) {
            setState(() {
              _mataSiap  = true;
              _instruksi = '👁️ Kedipkan mata';
            });
          }
        } else {
          _frameMata = 0;
        }
        _memproses = false;
        return;
      }

      // Step 2: deteksi kedip
      if (!_kedipMulai && mata < _mataButaThr) {
        // Mata mulai menutup
        setState(() {
          _kedipMulai = true;
          _instruksi  = '👁️ Buka mata...';
        });
      } else if (_kedipMulai && mata > _mataBukaThr) {
        // Mata terbuka lagi → kedip selesai!
        setState(() {
          _kedipOk   = true;
          _instruksi = '✅ Mengambil foto...';
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
      });

      await _validasiFoto(File(file.path));
    } catch (e) {
      setState(() => _pesan = 'Gagal foto: $e');
      _ulangi();
    }
  }

  Future<void> _validasiFoto(File file) async {
    try {
      final input = InputImage.fromFile(file);
      final faces = await _detector!.processImage(input);
      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _pesan    = 'Wajah tidak terdeteksi di foto. Coba lagi.';
          _validasi = false;
        });
        await Future.delayed(const Duration(seconds: 2));
        _ulangi();
      } else {
        setState(() {
          _validasi  = false;
          _instruksi = '✅ Wajah valid, mengirim...';
        });
        await Future.delayed(const Duration(milliseconds: 300));
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
    if (!mounted) return;

    if (res['status'] == true) {
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
      _foto       = null;
      _pesan      = '';
      _mataSiap   = false;
      _kedipMulai = false;
      _kedipOk    = false;
      _validasi   = false;
      _frameMata  = 0;
      _instruksi  = 'Arahkan wajah ke kamera';
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
      // Gunakan plane pertama saja (works untuk bgra8888 & nv21)
      final plane = img.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(img.width.toDouble(), img.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
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
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(label),
        centerTitle: true,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: !_isReady
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
        // Preview fullscreen
        CameraPreview(_cam!),

        // Gradient atas
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 160,
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

        // Oval panduan
        Center(
          child: Container(
            width: 230, height: 290,
            decoration: BoxDecoration(
              border: Border.all(
                color: _kedipOk
                    ? Colors.green
                    : _mataSiap
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
          top: 55, left: 20, right: 20,
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
                style: TextStyle(
                  color: _kedipOk ? Colors.green : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        // Step indicator bawah
        Positioned(
          bottom: 40, left: 0, right: 0,
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
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Widget _buildSteps(Color color) {
    final steps = [
      {'label': 'Wajah', 'icon': Icons.face,
       'done': _mataSiap || _kedipOk},
      {'label': 'Kedip', 'icon': Icons.remove_red_eye,
       'done': _kedipOk},
      {'label': 'Foto',  'icon': Icons.camera_alt,
       'done': false},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Container(
            width: 36, height: 2,
            color: (steps[i ~/ 2]['done'] as bool)
                ? color : Colors.white24,
          );
        }
        final s    = steps[i ~/ 2];
        final done = s['done'] as bool;
        final idx  = i ~/ 2;
        final curr = !done && (
          idx == 0 ? !_mataSiap :
          idx == 1 ? _mataSiap && !_kedipOk :
          _kedipOk
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: done ? color : curr
                    ? color.withOpacity(0.25) : Colors.white12,
                shape: BoxShape.circle,
                border: Border.all(
                    color: done || curr ? color : Colors.white24,
                    width: 2),
              ),
              child: Icon(s['icon'] as IconData,
                color: done ? Colors.white : curr
                    ? Colors.white70 : Colors.white30,
                size: 22),
            ),
            const SizedBox(height: 4),
            Text(s['label'] as String,
                style: TextStyle(
                    fontSize: 11,
                    color: done || curr
                        ? Colors.white : Colors.white38)),
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