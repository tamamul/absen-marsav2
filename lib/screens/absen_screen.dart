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
  int    _detectionFailCount = 0;

  // Challenge
  late String _challenge;
  String _instruksi = '';
  String _fase      = 'init';

  // State mata/senyum
  bool   _mataStabil    = false;
  int    _frameMata      = 0;
  bool   _kedipMulai    = false;
  int    _senyumFrames  = 0;
  int    _countdown     = 0;
  Timer? _timer;

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
        minFaceSize: 0.1,  // ✅ Turun dari 0.15 untuk deteksi lebih mudah
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

      _cam = CameraController(
        cam,
        ResolutionPreset.medium,  // ✅ Upgrade ke HIGH untuk kualitas lebih baik
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.nv21 
            : ImageFormatGroup.bgra8888,
      );

      await _cam!.initialize();
      if (!mounted) return;

      setState(() {
        _loading = false;
        _fase = 'siap';
      });

      _setInstruksi();
      _cam!.startImageStream(_onFrame);
    } catch (e) {
      setState(() { _loading = false; _pesan = 'Error: $e'; });
      debugPrint('Camera init error: $e');
    }
  }

  void _setInstruksi() {
    switch (_fase) {
      case 'siap':
        _instruksi = 'Arahkan wajah ke kamera';
        break;
      case 'challenge':
        _instruksi = _challenge == 'blink'
            ? '👁️ Kedipkan mata sekali'
            : '😊 Tersenyum lebar';
        break;
      case 'ok':
        _instruksi = '✅ Verifikasi berhasil!';
        break;
      case 'foto':
        _instruksi = '📸 Mengambil foto...';
        break;
      default:
        _instruksi = '';
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_memproses || _foto != null || !mounted) return;
    if (_fase == 'init' || _fase == 'foto' || _fase == 'kirim') return;

    final now = DateTime.now().millisecondsSinceEpoch;
    // ✅ Ubah timing: 300ms untuk beri cukup waktu ML Kit
    if (now - _lastMs < 300) return;
    _lastMs = now;
    _memproses = true;

    try {
      final inputImage = _toInputImage(img);
      if (inputImage == null) { 
        debugPrint('InputImage is null');
        _memproses = false; 
        return; 
      }

      debugPrint('Processing frame, fase: $_fase');

      // ✅ Tambah timeout untuk ML Kit
      final faces = await _detector!.processImage(inputImage).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('Face detection timeout');
          return [];
        },
      );

      debugPrint('Faces detected: ${faces.length}');

      if (faces.isNotEmpty) {
        _detectionFailCount = 0;
        _faceVisible = true;
        _lastFaceDetected = DateTime.now().millisecondsSinceEpoch;
      } else {
        _detectionFailCount++;
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
          _instruksi = 'Wajah tidak terdeteksi, coba sesuaikan posisi (${_detectionFailCount}s)';
          if (_fase == 'challenge' && _senyumFrames > 0) {
            _senyumFrames = max(0, _senyumFrames - 1);
          } else if (_fase == 'challenge' && _detectionFailCount > 3) {
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

      debugPrint('Face data - Mata: $mata, Senyum: $senyum, EulerY: $eulerY, EulerX: $eulerX');

      if (eulerY.abs() > 35 || eulerX.abs() > 30) {
        setState(() => _instruksi = 'Hadapkan wajah ke depan');
        _memproses = false;
        return;
      }

      if (_fase == 'siap') {
        if (mata > 0.5) {
          _frameMata++;
          if (_frameMata >= 2) {  // ✅ Turun dari 3 jadi 2 untuk lebih responsif
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
          if (senyum > 0.5) {  // ✅ Turun dari 0.6 jadi 0.5
            _senyumFrames++;
            setState(() => _instruksi =
                '😊 Tahan senyum... $_senyumFrames/2');
            if (_senyumFrames >= 2) _lulus();  // ✅ Turun dari 3 jadi 2
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
    return _faceVisible && (now - _lastFaceDetected) < 500;
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

  // ✅ VERIFIKASI FOTO DENGAN ML KIT
  Future<bool> _verifikasiFoto(File file) async {
    try {
      final inputImage = InputImage.fromFile(file);
      final faces = await _detector!.processImage(inputImage);
      debugPrint('Photo verification: ${faces.length} faces detected');
      return faces.isNotEmpty;
    } catch (e) {
      debugPrint('Gagal verifikasi foto: $e');
      return false;
    }
  }

  // ✅ AMBIL FOTO DENGAN VERIFIKASI
  Future<void> _ambilFoto() async {
  if (_cam == null) return;

  setState(() {
    _fase = 'foto';
    _setInstruksi();
  });

  try {
    // Stop stream dulu
    await _cam!.stopImageStream();
    await Future.delayed(const Duration(milliseconds: 400));

    final file = await _cam!.takePicture();
    if (!mounted) return;

    final fotoFile = File(file.path);
    setState(() => _foto = fotoFile);

    setState(() => _instruksi = '🔍 Memeriksa foto...');

    final adaWajah = await _verifikasiFoto(fotoFile);
    if (!mounted) return;

    if (adaWajah) {
      await Future.delayed(const Duration(milliseconds: 300));
      _kirimAbsen();
    } else {
      setState(() {
        _pesan = 'Wajah tidak terdeteksi di foto. Ulangi.';
        _foto  = null;
      });
      _ulangi();
    }
  } catch (e) {
    setState(() => _pesan = 'Gagal foto: $e');
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
    final warning      = res['warning'];
    final terlambat    = res['terlambat'] == true;
    final menitTerlambat = res['menit_terlambat'] ?? 0;

    // Tampil snackbar sukses
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? 'Absen berhasil'),
      backgroundColor: terlambat ? Colors.orange : Colors.green,
      duration: const Duration(seconds: 3),
    ));

    // Jika ada warning (pulang lebih awal mode santai)
    if (warning != null) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Perhatian'),
            ],
          ),
          content: Text(warning.toString()),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context, true);
    }
  } else {
    // Error — cek apakah pesan blokir jam
    final errMsg = res['messages']?['error'] ??
        res['message'] ?? 'Absen gagal';

    // Tampil dialog untuk error penting
    final isPenting = errMsg.contains('belum dibuka') ||
        errMsg.contains('Belum waktunya') ||
        errMsg.contains('luar area');

    if (isPenting) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red),
              SizedBox(width: 8),
              Text('Tidak Dapat Absen'),
            ],
          ),
          content: Text(errMsg),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      _ulangi();
    } else {
      setState(() {
        _foto  = null;
        _pesan = errMsg;
      });
      _ulangi();
    }
  }
}

  void _ulangi() {
    _timer?.cancel();
    _challenge = Random().nextBool() ? 'blink' : 'smile';

    setState(() {
      _foto = null;
      _pesan = '';
      _fase = 'siap';
      _frameMata = 0;
      _mataStabil = false;
      _kedipMulai = false;
      _senyumFrames = 0;
      _countdown = 0;
      _captureArmed = false;
      _detectionFailCount = 0;
      _setInstruksi();
    });

    _cam?.startImageStream(_onFrame);
  }

  InputImage? _toInputImage(CameraImage img) {
    try {
      final cam      = _cam!.description;
      final rotation = InputImageRotationValue.fromRawValue(
              cam.sensorOrientation) ??
          InputImageRotation.rotation0deg;

      final format = InputImageFormatValue.fromRawValue(img.format.raw);
      if (format == null) {
        debugPrint('Format is null: ${img.format.raw}');
        return null;
      }

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
              : _foto != null && !_mengirim && _pesan.isEmpty
                  ? _buildKonfirmasi(color, label)
                  : _foto != null && _mengirim
                      ? _buildKonfirmasi(color, label)
                      : _buildKamera(color),
    );
  }

  Widget _buildKamera(Color color) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
          const SizedBox(height: 20),

          Container(
            width: screenWidth * 0.9,
            height: screenWidth * 1.2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black,
              border: Border.all(color: Colors.white30, width: 2),
            ),
            clipBehavior: Clip.hardEdge,
            child: _cam != null && _cam!.value.isInitialized
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_cam!),
                      if (_fase == 'ok' && _countdown > 0)
                        Center(
                          child: Container(
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
                        ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          _buildProgress(color),

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
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
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
        if (_foto != null) Image.file(_foto!, fit: BoxFit.cover),
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
        if (!_mengirim && _pesan.isNotEmpty)
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
        if (!_mengirim)
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