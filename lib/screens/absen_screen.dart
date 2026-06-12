import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
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

  bool   _loading   = true;
  bool   _mengirim  = false;
  bool   _memproses = false;
  int    _lastMs    = 0;
  File?  _foto;
  String _pesan     = '';

  // Challenge
  late String _challenge;
  String _instruksi = '';
  String _fase      = 'init'; // init, siap, challenge, ok, foto, kirim

  // State mata/senyum
  bool   _mataStabil    = false;
  int    _frameMata      = 0;
  bool   _kedipMulai    = false;
  int    _senyumFrames  = 0;
  int    _countdown     = 0;
  Timer? _timer;

  // Exposure adjustment flag
  bool _exposureAdjusted = false;
  
  bool _faceVisible = false;
  int _lastFaceDetected = 0;
  bool _captureArmed = false;
  
  @override
  void initState() {
    super.initState();
    _challenge = Random().nextBool() ? 'blink' : 'smile';
    _detector  = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15,
      ),
    );
    _initCam();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cam?.dispose();
    _detector?.close();
    super.dispose();
  }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() { _loading = false; _pesan = 'Kamera tidak ada'; });
        return;
      }
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );

      // Resolusi medium + format paksa NV21 (Android) untuk kompatibilitas
      _cam = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await _cam!.initialize();
      if (!mounted) return;

      // Atur exposure untuk kondisi gelap
      await _adjustExposure();

      setState(() { _loading = false; _fase = 'siap'; });
      _setInstruksi();
      _cam!.startImageStream(_onFrame);
    } catch (e) {
      setState(() { _loading = false; _pesan = 'Error: $e'; });
    }
  }

  Future<void> _adjustExposure() async {
    if (_cam == null) return;
    try {
      await _cam!.setExposureMode(ExposureMode.auto);
      final min = await _cam!.getMinExposureOffset();
      final max = await _cam!.getMaxExposureOffset();
      final target = 2.0.clamp(min, max);
      await _cam!.setExposureOffset(target);
      if (mounted) _exposureAdjusted = true;
    } catch (e) {
      debugPrint('Exposure adjustment failed: $e');
    }
  }

  void _setInstruksi() {
    if (_fase == 'siap') {
      _instruksi = 'Arahkan wajah ke kamera';
    } else if (_fase == 'challenge') {
      _instruksi = _challenge == 'blink'
          ? '👁️ Kedipkan mata sekali'
          : '😊 Tersenyum lebar';
    } else if (_fase == 'ok') {
      _instruksi = '✅ Verifikasi berhasil!';
    } else if (_fase == 'foto') {
      _instruksi = '📸 Mengambil foto...';
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_memproses || _foto != null || !mounted) return;
    if (_fase == 'init' || _fase == 'foto' || _fase == 'kirim') return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 200) return;
    _lastMs = now;
    _memproses = true;

    try {
      final inputImage = _toInputImage(img);
      if (inputImage == null) { _memproses = false; return; }

      final faces = await _detector!.processImage(inputImage);
      if (faces.isNotEmpty) {
  _faceVisible = true;
  _lastFaceDetected = DateTime.now().millisecondsSinceEpoch;
} else {
  _faceVisible = false;

  if (_captureArmed && _fase == 'ok') {
    _captureArmed = false;

    setState(() {
      _pesan = 'Wajah hilang sebelum foto diambil';
    });

    _ulangi();
    _memproses = false;
    return;
  }
}
      if (!mounted) { _memproses = false; return; }

      if (faces.isEmpty) {
        setState(() {
          _instruksi = 'Wajah tidak terdeteksi, coba sesuaikan posisi';
          if (_fase == 'challenge' && _senyumFrames > 0) {
            _senyumFrames = max(0, _senyumFrames - 1);
          } else if (_fase == 'challenge') {
            _fase = 'siap';
            _mataStabil = false;
            _kedipMulai = false;
            _setInstruksi();
          }
        });
        _memproses = false;
        return;
      }

      final face     = faces.first;
      final eulerY   = face.headEulerAngleY ?? 0.0;
      final eulerX   = face.headEulerAngleX ?? 0.0;
      final leftEye  = face.leftEyeOpenProbability  ?? 0.8;
      final rightEye = face.rightEyeOpenProbability ?? 0.8;
      final mata     = (leftEye + rightEye) / 2;
      final senyum   = face.smilingProbability ?? 0.0;

      // Toleransi sudut lebih besar
      if (eulerY.abs() > 35 || eulerX.abs() > 30) {
        setState(() => _instruksi = 'Hadapkan wajah ke depan');
        _memproses = false;
        return;
      }

      if (_fase == 'siap') {
        if (mata > 0.5) {
          _frameMata++;
          if (_frameMata >= 3) {
            setState(() {
              _mataStabil = true;
              _fase       = 'challenge';
              _setInstruksi();
            });
          }
        } else {
          _frameMata = max(0, _frameMata - 1);
        }
      } else if (_fase == 'challenge') {
        if (_challenge == 'blink') {
          if (!_kedipMulai && mata > 0.6) {
            _kedipMulai = true;
          } else if (_kedipMulai && mata < 0.3) {
            setState(() => _instruksi = '👁️ Buka mata...');
          } else if (_kedipMulai && mata > 0.5 &&
              _instruksi == '👁️ Buka mata...') {
            _lulus();
          }
        } else {
          if (senyum > 0.6) {
            _senyumFrames++;
            setState(() => _instruksi =
                '😊 Tahan senyum... $_senyumFrames/3');
            if (_senyumFrames >= 3) _lulus();
          } else {
            _senyumFrames = max(0, _senyumFrames - 1);
            if (_senyumFrames == 0) {
              setState(() => _instruksi = '😊 Tersenyum lebar');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    }

    _memproses = false;
  }
  
  bool _isFaceStillPresent() {
  final now = DateTime.now().millisecondsSinceEpoch;

  return _faceVisible &&
      (now - _lastFaceDetected) < 500;
}

  void _lulus() {
  _captureArmed = true;

  setState(() {
    _fase = 'ok';
    _countdown = 2;
    _setInstruksi();
  });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _ambilFoto();
      }
    });
  }

  Future<void> _ambilFoto() async {
  if (_cam == null) return;

  setState(() {
    _fase = 'foto';
    _setInstruksi();
  });

  try {
    if (!_isFaceStillPresent()) {
      setState(() {
        _pesan = 'Wajah tidak terdeteksi. Silakan ulangi.';
      });

      _ulangi();
      return;
    }
    
    if (!_faceVisible) {
  setState(() {
    _pesan = 'Wajah tidak terdeteksi';
  });

  _ulangi();
  return;
}
    
    await _cam!.stopImageStream();

    try {
      await _cam!.setExposureMode(ExposureMode.auto);
      await _cam!.setExposureOffset(0.0);
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 600));

    final file = await _cam!.takePicture();
      if (!mounted) return;
      setState(() => _foto = File(file.path));
      await Future.delayed(const Duration(milliseconds: 500));
      _kirimAbsen();
    } catch (e) {
      setState(() { _pesan = 'Gagal foto: $e'; _ulangi(); });
    }
  }

  Future<void> _kirimAbsen() async {
    if (_foto == null) return;
    setState(() { _mengirim = true; _pesan = ''; });

    final lat = widget.posisi?.latitude  ?? 0.0;
    final lng = widget.posisi?.longitude ?? 0.0;

    try {
      final res = widget.tipe == 'masuk'
          ? await ApiService.absenMasuk(lat, lng, fotoFile: _foto)
          : await ApiService.absenKeluar(lat, lng, fotoFile: _foto);

      if (!mounted) return;
      setState(() => _mengirim = false);

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
    } catch (e) {
      if (!mounted) return;
      setState(() { _mengirim = false; _pesan = 'Error: $e'; });
      _ulangi();
    }
  }

  void _ulangi() {
    _timer?.cancel();
    _challenge = Random().nextBool() ? 'blink' : 'smile';
    _exposureAdjusted = false;
    setState(() {
      _foto         = null;
      _pesan        = '';
      _fase         = 'siap';
      _frameMata    = 0;
      _mataStabil   = false;
      _kedipMulai   = false;
      _senyumFrames = 0;
      _countdown    = 0;
      _setInstruksi();
    });
    _adjustExposure();
    _cam?.startImageStream(_onFrame);
  }

  InputImage? _toInputImage(CameraImage img) {
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
        final allBytes = WriteBuffer();
        for (final p in img.planes) allBytes.putUint8List(p.bytes);
        return InputImage.fromBytes(
          bytes: allBytes.done().buffer.asUint8List(),
          metadata: InputImageMetadata(
            size: Size(img.width.toDouble(), img.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: img.planes[0].bytesPerRow,
          ),
        );
      }
    } catch (e) {
      debugPrint('Conversion error: $e');
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
          : _pesan.isNotEmpty && _foto == null && _fase == 'init'
              ? _buildError()
              : _foto != null
                  ? _buildKonfirmasi(color, label)
                  : _buildKamera(color),
    );
  }

  Widget _buildKamera(Color color) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Instruksi di atas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _instruksi,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _fase == 'ok' ? Colors.green : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 40),

        // Area preview lingkaran
        GestureDetector(
          // Tidak ada aksi tap, hanya menampilkan preview
          child: Stack(
            alignment: Alignment.center,
            children: [
              
              // Lingkaran dalam berisi preview
              Container(
  width: screenWidth * 0.9,
  height: screenWidth * 1.2,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(20),
    color: Colors.black,
  ),
  clipBehavior: Clip.hardEdge,
  child: _cam != null && _cam!.value.isInitialized
      ? CameraPreview(_cam!)
      : const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
),
              

              // Countdown di tengah preview
              if (_fase == 'ok' && _countdown > 0)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.85),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$_countdown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Progress indicator
        _buildProgress(color),

        // Pesan error di bawah progress
        if (_pesan.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[900],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _pesan,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgress(Color color) {
    final steps = ['Wajah', _challenge == 'blink' ? 'Kedip' : 'Senyum', 'Foto'];
    final activeStep = _fase == 'siap'
        ? 0
        : _fase == 'challenge'
            ? 1
            : 2;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Container(
            width: 40, height: 2,
            color: i ~/ 2 < activeStep ? color : Colors.white30,
          );
        }
        final idx  = i ~/ 2;
        final done = idx < activeStep;
        final curr = idx == activeStep;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: done
                    ? color
                    : curr
                        ? color.withOpacity(0.3)
                        : Colors.white12,
                shape: BoxShape.circle,
                border: Border.all(
                    color: done || curr ? color : Colors.white30,
                    width: 2),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check,
                        color: Colors.white, size: 16)
                    : Text('${idx + 1}',
                        style: TextStyle(
                            color: curr ? Colors.white : Colors.white38,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 4),
            Text(steps[idx],
                style: TextStyle(
                    color: done || curr ? Colors.white : Colors.white38,
                    fontSize: 10)),
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
        if (!_mengirim) ...[
          if (_pesan.isNotEmpty)
            Positioned(
              bottom: 100, left: 20, right: 20,
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

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            Text(_pesan,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() { _loading = true; _pesan = ''; });
                _initCam();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}