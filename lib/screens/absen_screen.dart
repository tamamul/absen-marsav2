import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import '../services/api_service.dart';

class AbsenScreen extends StatefulWidget {
  final String tipe;
  final Position? posisi;
  const AbsenScreen({super.key, required this.tipe, this.posisi});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  CameraController? _cameraController;
  FaceDetector?     _faceDetector;
  bool _cameraReady    = false;
  bool _loading        = true;
  bool _mengirim       = false;
  bool _memproses      = false;
  int  _lastProcess    = 0;
  File? _foto;
  String _pesan        = '';
  String _instruksi    = 'Posisikan wajah di kotak';

  // Liveness state
  bool _livenessOk      = false;
  bool _mataTerbuka     = false;
  bool _kedipTerdeteksi = false;
  bool _wajahValid      = false;
  int  _countdown       = 0;
  int  _kedipDiminta    = 1; // random 1 atau 2
  int  _kedipCount      = 0;
  Timer? _countdownTimer;
  Timer? _prosesTimer;
  Timer? _mataTimer; // timer validasi mata terbuka

  // Anti-cheat
  int    _frameMataTerbuka   = 0; // harus terbuka minimal N frame
  double _lastEulerY         = 0;
  int    _frameWajahStabil   = 0;
  Rect?  _wajahRect;
  Size?  _previewSize;
  static const int _minFrameMataTerbuka = 5; // ~1.25 detik
  static const double _maxEulerY        = 25.0; // max miring kepala
  static const double _maxEulerX        = 20.0; // max angguk
  static const int _minFrameStabil      = 3;

  @override
  void initState() {
    super.initState();
    // Random challenge: 1 atau 2 kedip
    _kedipDiminta = Random().nextInt(2) + 1;
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        enableContours: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initKamera();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _prosesTimer?.cancel();
    _mataTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  Future<void> _initKamera() async {
  setState(() => _loading = true);
  try {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() {
        _loading = false;
        _pesan = 'Kamera tidak tersedia';
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
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _cameraController!.initialize();
    _previewSize = _cameraController!.value.previewSize;

    // Cukup auto exposure
    await _cameraController!.setExposureMode(ExposureMode.auto);

    if (!mounted) return;
    setState(() {
      _cameraReady = true;
      _loading = false;
    });
    _cameraController!.startImageStream(_prosesFrame);
  } catch (e) {
    setState(() {
      _loading = false;
      _pesan = 'Gagal buka kamera: $e';
    });
  }
}

  Future<void> _prosesFrame(CameraImage image) async {
    if (_memproses || _livenessOk || !mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcess < 250) return;
    _lastProcess = now;
    _memproses = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) { _memproses = false; return; }

      final faces = await _faceDetector!.processImage(inputImage);
      if (!mounted) { _memproses = false; return; }

      if (faces.isEmpty) {
        setState(() {
          _wajahRect           = null;
          _wajahValid          = false;
          _frameMataTerbuka    = 0;
          _frameWajahStabil    = 0;
          if (_countdown > 0) _batalkanCountdown('Wajah hilang!');
          else if (!_livenessOk) {
            _instruksi       = 'Posisikan wajah di kotak';
            _kedipTerdeteksi = false;
            _mataTerbuka     = false;
            _kedipCount      = 0;
          }
        });
        _memproses = false;
        return;
      }

      final face      = faces.first;
      final leftEye   = face.leftEyeOpenProbability  ?? 1.0;
      final rightEye  = face.rightEyeOpenProbability ?? 1.0;
      final rataEye   = (leftEye + rightEye) / 2;
      final eulerY    = face.headEulerAngleY ?? 0.0; // kiri/kanan
      final eulerX    = face.headEulerAngleX ?? 0.0; // atas/bawah

      // ── Anti-cheat 1: cek sudut kepala ──
      if (eulerY.abs() > _maxEulerY || eulerX.abs() > _maxEulerX) {
        setState(() {
          _wajahRect  = face.boundingBox;
          _instruksi  = 'Hadapkan wajah ke kamera';
          _wajahValid = false;
          _frameMataTerbuka = 0;
          if (_countdown > 0) _batalkanCountdown('Kepala terlalu miring!');
        });
        _memproses = false;
        return;
      }

      setState(() => _wajahRect = face.boundingBox);
      _lastEulerY = eulerY;

      // ── Anti-cheat 2: mata harus terbuka cukup lama ──
      if (rataEye > 0.75) {
        _frameMataTerbuka++;
      } else {
        _frameMataTerbuka = 0;
      }

      final mataSudahTerbuka =
          _frameMataTerbuka >= _minFrameMataTerbuka;

      // ── Anti-cheat 3: wajah harus stabil saat countdown ──
      if (_countdown > 0) {
        final gerak = (eulerY - _lastEulerY).abs();
        if (gerak < 5.0) {
          _frameWajahStabil++;
        } else {
          _frameWajahStabil = 0;
          _batalkanCountdown('Jangan bergerak!');
          _memproses = false;
          return;
        }
        _wajahValid = _frameWajahStabil >= _minFrameStabil;
        _memproses = false;
        return;
      }

      // ── Logika kedip ──
      if (!mataSudahTerbuka && !_mataTerbuka) {
        // Belum siap
        setState(() => _instruksi = 'Buka mata Anda lebar');
        _memproses = false;
        return;
      }

      if (!_mataTerbuka && mataSudahTerbuka) {
        setState(() {
          _mataTerbuka = true;
          _instruksi   = _kedipDiminta == 1
              ? 'Kedipkan mata 1x 👁️'
              : 'Kedipkan mata 2x 👁️👁️';
          _wajahValid  = true;
        });
      }

      if (_mataTerbuka && !_livenessOk) {
        if (rataEye < 0.2 && !_kedipTerdeteksi) {
          // Mata tertutup = mulai kedip
          setState(() => _kedipTerdeteksi = true);
        } else if (rataEye > 0.7 && _kedipTerdeteksi) {
          // Mata terbuka lagi = kedip selesai
          _kedipCount++;
          setState(() => _kedipTerdeteksi = false);

          if (_kedipCount >= _kedipDiminta) {
            // Semua kedip terpenuhi!
            setState(() {
              _livenessOk = true;
              _instruksi  = 'Verifikasi berhasil! Bersiap...';
              _countdown  = 2;
              _wajahValid = true;
            });
            _mulaiCountdown();
          } else {
            // Masih kurang kedip
            final sisa = _kedipDiminta - _kedipCount;
            setState(() => _instruksi = 'Kedip lagi $sisa kali 👁️');
          }
        }
      }
    } catch (_) {}

    _memproses = false;
  }

  void _mulaiCountdown() {
    _countdownTimer?.cancel();
    _frameWajahStabil = 0;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdown <= 0) {
        t.cancel();
        if (_wajahValid) {
          _ambilFotoOtomatis();
        } else {
          _batalkanCountdown('Wajah tidak stabil!');
        }
        return;
      }
      setState(() {
        _countdown--;
        _instruksi = 'Jangan bergerak... $_countdown';
      });
    });
  }

  Future<void> _ambilFotoOtomatis() async {
    if (_cameraController == null || !_cameraReady) return;
    try {
      await _cameraController!.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 400));
      final file = await _cameraController!.takePicture();
      if (!mounted) return;
      setState(() {
        _foto      = File(file.path);
        _instruksi = 'Foto diambil! 📸';
      });
      _prosesTimer = Timer(const Duration(milliseconds: 800), _kirimAbsen);
    } catch (e) {
      setState(() => _pesan = 'Gagal ambil foto: $e');
    }
  }

  void _batalkanCountdown(String alasan) {
    _countdownTimer?.cancel();
    setState(() {
      _countdown       = 0;
      _livenessOk      = false;
      _kedipTerdeteksi = false;
      _mataTerbuka     = false;
      _kedipCount      = 0;
      _wajahValid      = false;
      _frameMataTerbuka = 0;
      _frameWajahStabil = 0;
      _instruksi       = '⚠️ $alasan Ulangi.';
    });
  }

  void _ulangi() {
    _countdownTimer?.cancel();
    _prosesTimer?.cancel();
    _mataTimer?.cancel();
    _lastProcess = 0;
    // Random ulang challenge
    _kedipDiminta = Random().nextInt(2) + 1;
    setState(() {
      _foto             = null;
      _pesan            = '';
      _instruksi        = 'Posisikan wajah di kotak';
      _livenessOk       = false;
      _mataTerbuka      = false;
      _kedipTerdeteksi  = false;
      _kedipCount       = 0;
      _countdown        = 0;
      _wajahRect        = null;
      _wajahValid       = false;
      _frameMataTerbuka = 0;
      _frameWajahStabil = 0;
    });
    _cameraController?.startImageStream(_prosesFrame);
  }

  Future<void> _kirimAbsen() async {
    if (_foto == null) return;
    setState(() { _mengirim = true; _pesan = ''; });

    final lat = widget.posisi?.latitude  ?? 0.0;
    final lng = widget.posisi?.longitude ?? 0.0;

    Map<String, dynamic> res;
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
            res['message'] ?? 'Absen gagal';
      });
      _ulangi();
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final camera   = _cameraController!.description;
      final rotation = InputImageRotationValue.fromRawValue(
              camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
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
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: Text(label),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : !_cameraReady
              ? Center(
                  child: Text(_pesan,
                      style: const TextStyle(color: Colors.white)))
              : _foto != null
                  ? _buildKonfirmasi(color, label)
                  : _buildKamera(color),
    );
  }

  Widget _buildKamera(Color color) {
  return Column(
    children: [
      // Area preview dengan aspect ratio yang benar
      Expanded(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Preview kamera dengan aspect ratio
            if (_previewSize != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _previewSize!.width / _previewSize!.height,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              )
            else
              CameraPreview(_cameraController!),

            // Progress kedip
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: _buildKedipProgress(color),
            ),

            // Instruksi
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: _buildInstructionBubble(),
            ),

            // Countdown
            if (_countdown > 0)
              _buildCountdownCircle(color),

            // Error
            if (_pesan.isNotEmpty)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: _buildErrorBubble(),
              ),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildKedipProgress(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kedipDiminta, (i) {
        final done = i < _kedipCount;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: done ? color : Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(
                color: done ? color : Colors.white54, width: 2),
          ),
          child: Icon(
            Icons.remove_red_eye,
            color: done ? Colors.white : Colors.white54,
            size: 18,
          ),
        );
      }),
    );
  }

  Widget _buildInstructionBubble() {
    IconData icon;
    Color    iconColor;

    if (_livenessOk) {
      icon = Icons.check_circle; iconColor = Colors.green;
    } else if (_kedipCount > 0) {
      icon = Icons.remove_red_eye; iconColor = Colors.orange;
    } else if (_wajahRect != null) {
      icon = Icons.face; iconColor = Colors.white;
    } else {
      icon = Icons.person_search; iconColor = Colors.white70;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(_instruksi,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownCircle(Color color) {
    return Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5),
        ],
      ),
      child: Center(
        child: Text('$_countdown',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildErrorBubble() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_pesan,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildKonfirmasi(Color color, String label) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_foto!, fit: BoxFit.cover),
        if (_mengirim)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text('Mengirim $label...',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ),
        if (_pesan.isNotEmpty)
          Positioned(
            bottom: 100, left: 20, right: 20,
            child: _buildErrorBubble(),
          ),
        if (!_mengirim)
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: ElevatedButton.icon(
              onPressed: _ulangi,
              icon: const Icon(Icons.refresh),
              label: const Text('Ulangi Foto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
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