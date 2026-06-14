import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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

  // Challenge untuk memastikan Wajah Asli (Anti-Spoofing)
  late String _challenge;
  String _instruksi = '';
  String _fase      = 'init'; // init, siap, challenge, ok, foto, kirim

  // State deteksi
  bool   _mataStabil    = false;
  int    _frameMata      = 0;
  bool   _kedipMulai    = false;
  int    _senyumFrames  = 0;
  int    _countdown     = 0;
  Timer? _timer;

  bool _faceVisible = false;
  int _lastFaceDetected = 0;
  
  // Variabel penyimpan frame gambar untuk foto final
  CameraImage? _currentFrame;
  
  @override
  void initState() {
    super.initState();
    // Acak tantangan agar tidak bisa diakali pakai video rekaman HP lain
    _challenge = Random().nextBool() ? 'blink' : 'smile';
    _detector  = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // Wajib true untuk cek mata & senyum
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.2, // Memastikan wajah cukup dekat dengan kamera
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
        ResolutionPreset.high, // Diubah ke HIGH agar hasil foto absen tajam dan terang
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await _cam!.initialize();
      if (!mounted) return;

      // Optimasi Kecerahan Kamera
      await _optimizeExposure();

      setState(() { _loading = false; _fase = 'siap'; });
      _setInstruksi();
      _cam!.startImageStream((img) {
        _currentFrame = img; // Simpan frame terbaru secara konstan
        _onFrame(img);
      });
    } catch (e) {
      setState(() { _loading = false; _pesan = 'Error: $e'; });
    }
  }

  // JALUR SOLUSI KADANG GELAP: Paksa kompensasi cahaya naik sedikit jika hardware mendukung
  Future<void> _optimizeExposure() async {
    if (_cam == null) return;
    try {
      await _cam!.setExposureMode(ExposureMode.auto);
      
      final minOffset = await _cam!.getMinExposureOffset();
      final maxOffset = await _cam!.getMaxExposureOffset();
      
      // Berikan kompensasi +0.7 atau +1.0 agar wajah terlihat lebih terang dari background
      double brightOffset = 1.0.clamp(minOffset, maxOffset);
      await _cam!.setExposureOffset(brightOffset);
    } catch (e) {
      debugPrint('Gagal optimasi pencahayaan: $e');
    }
  }

  void _setInstruksi() {
    if (_fase == 'siap') {
      _instruksi = 'Arahkan wajah ke kamera';
    } else if (_fase == 'challenge') {
      _instruksi = _challenge == 'blink'
          ? '👁️ Kedipkan mata Anda sekali'
          : '😊 Tersenyum lebar ke kamera';
    } else if (_fase == 'ok') {
      _instruksi = '✅ Wajah Terverifikasi Asli!';
    } else if (_fase == 'foto') {
      _instruksi = '📸 Menyimpan foto absen...';
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_memproses || _foto != null || !mounted) return;
    if (_fase == 'init' || _fase == 'foto' || _fase == 'kirim') return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 150) return; // Kecepatan cek frame ditingkatkan
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
      }
      
      if (!mounted) { _memproses = false; return; }

      if (faces.isEmpty) {
        setState(() {
          _instruksi = 'Wajah tidak terdeteksi atau terlalu jauh';
          if (_fase == 'challenge') {
            _fase = 'siap';
            _mataStabil = false;
            _kedipMulai = false;
            _senyumFrames = 0;
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

      // Proteksi miring: mencegah orang menaruh foto miring di depan kamera
      if (eulerY.abs() > 25 || eulerX.abs() > 25) {
        setState(() => _instruksi = 'Hadapkan wajah lurus ke depan');
        _memproses = false;
        return;
      }

      // Fase 1: Memastikan wajah diam & siap menerima tantangan liveness
      if (_fase == 'siap') {
        if (mata > 0.6) {
          _frameMata++;
          if (_frameMata >= 2) {
            setState(() {
              _mataStabil = true;
              _fase       = 'challenge';
              _setInstruksi();
            });
          }
        }
      } 
      // Fase 2: Pengecekan Tantangan Gerakan (Mencegah manipulasi Kertas/Layar)
      else if (_fase == 'challenge') {
        if (_challenge == 'blink') {
          // Harus mendeteksi proses mata terbuka -> merem -> terbuka lagi baru dianggap sah
          if (!_kedipMulai && mata > 0.6) {
            _kedipMulai = true;
          } else if (_kedipMulai && mata < 0.25) {
            setState(() => _instruksi = '👁️ Buka mata kembali...');
          } else if (_kedipMulai && mata > 0.6 && _instruksi == '👁️ Buka mata kembali...') {
            _lulusVerification();
          }
        } else {
          // Harus menahan senyum lebar selama beberapa frame berturut-turut
          if (senyum > 0.65) {
            _senyumFrames++;
            setState(() => _instruksi = '😊 Tahan senyuman Anda... $_senyumFrames/3');
            if (_senyumFrames >= 3) _lulusVerification();
          } else {
            _senyumFrames = max(0, _senyumFrames - 1);
          }
        }
      }
    } catch (e) {
      debugPrint('Kesalahan ML Kit: $e');
    }

    _memproses = false;
  }

  void _lulusVerification() {
    setState(() {
      _fase = 'ok';
      _countdown = 1; // Langsung kunci target dalam 1 detik demi kecepatan berkas
      _setInstruksi();
    });
    
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () {
      if (mounted) _prosesAmbilFotoDariStream();
    });
  }

  // ALUR TERAMAN: Mengonversi frame stream saat dinyatakan lulus menjadi file gambar matang
  Future<void> _prosesAmbilFotoDariStream() async {
    if (_cam == null || _currentFrame == null) {
      setState(() { _pesan = 'Gagal menangkap gambar, silakan ulangi'; });
      _ulangi();
      return;
    }

    setState(() {
      _fase = 'foto';
      _setInstruksi();
    });

    try {
      // Pastikan wajah masih ada di detik terakhir sebelum konversi
      final selisihWaktuWajah = DateTime.now().millisecondsSinceEpoch - _lastFaceDetected;
      if (selisihWaktuWajah > 800) {
        setState(() { _pesan = 'Verifikasi gagal. Wajah Anda bergerak menjauh.'; });
        _ulangi();
        return;
      }

      await _cam!.stopImageStream();
      
      // Ambil snapshot gambar resolusi tinggi langsung dari sensor aktif yang sudah terang
      final XFile fileGambar = await _cam!.takePicture();
      
      if (!mounted) return;
      setState(() => _foto = File(fileGambar.path));
      
      // Langsung eksekusi kirim ke server
      _kirimAbsen();
    } catch (e) {
      setState(() { _pesan = 'Gagal menyimpan gambar: $e'; _ulangi(); });
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
          content: Text(res['message'] ?? 'Absen berhasil dicatat'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true);
      } else {
        setState(() {
          _pesan = res['messages']?['error'] ?? res['message'] ?? 'Absen ditolak server';
        });
        _ulangi();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _mengirim = false; _pesan = 'Masalah Jaringan: $e'; });
      _ulangi();
    }
  }

  void _ulangi() {
    _timer?.cancel();
    _challenge = Random().nextBool() ? 'blink' : 'smile';
    setState(() {
      _foto         = null;
      _fase         = 'siap';
      _frameMata    = 0;
      _mataStabil   = false;
      _kedipMulai   = false;
      _senyumFrames = 0;
      _countdown    = 0;
      _setInstruksi();
    });
    _optimizeExposure();
    _cam?.startImageStream((img) {
      _currentFrame = img;
      _onFrame(img);
    });
  }

  InputImage? _toInputImage(CameraImage img) {
    try {
      final cam      = _cam!.description;
      final rotation = InputImageRotationValue.fromRawValue(cam.sensorOrientation) ?? InputImageRotation.rotation0deg;
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
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _pesan.isNotEmpty && _foto == null && _fase == 'siap'
              ? _buildKameraDenganPesanError(color)
              : _foto != null
                  ? _buildKonfirmasi(color, label)
                  : _buildKamera(color),
    );
  }

  Widget _buildKameraDenganPesanError(Color color) {
    return Stack(
      children: [
        _buildKamera(color),
        Positioned(
          bottom: 110, left: 20, right: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red[900], borderRadius: BorderRadius.circular(12)),
            child: Text(_pesan, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }

  Widget _buildKamera(Color color) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _instruksi,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _fase == 'ok' ? Colors.greenAccent : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 30),

        Center(
          child: Container(
            width: screenWidth * 0.85,
            height: screenWidth * 1.1,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.black,
              border: Border.all(color: _fase == 'ok' ? Colors.green : Colors.white24, width: 3),
            ),
            clipBehavior: Clip.hardEdge,
            child: _cam != null && _cam!.value.isInitialized
                ? CameraPreview(_cam!)
                : const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 30),
        _buildProgress(color),
      ],
    );
  }

  Widget _buildProgress(Color color) {
    final steps = ['Deteksi', _challenge == 'blink' ? 'Kedip' : 'Senyum', 'Selesai'];
    final activeStep = _fase == 'siap' ? 0 : _fase == 'challenge' ? 1 : 2;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Container(width: 30, height: 2, color: i ~/ 2 < activeStep ? color : Colors.white24);
        }
        final idx  = i ~/ 2;
        final done = idx < activeStep;
        final curr = idx == activeStep;
        return Column(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: done ? color : curr ? color.withOpacity(0.3) : Colors.white12,
                shape: BoxShape.circle,
                border: Border.all(color: done || curr ? color : Colors.white30, width: 2),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : Text('${idx + 1}', style: TextStyle(color: curr ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 4),
            Text(steps[idx], style: TextStyle(color: done || curr ? Colors.white : Colors.white38, fontSize: 10)),
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
        Container(
          color: Colors.black54,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text('Memproses data & mengirim $label...', style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}