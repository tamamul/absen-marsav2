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

class _AbsenScreenState extends State<AbsenScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _cameraReady    = false;
  bool _loading        = true;
  bool _mengirim       = false;
  bool _memproses      = false;
  int _lastProcess     = 0;
  File? _foto;
  String _pesan        = '';
  String _instruksi    = 'Posisikan wajah di kotak';

  // Liveness
  bool _livenessOk      = false;
  bool _mataTerbuka     = false;
  bool _kedipTerdeteksi = false;
  int _countdown        = 0;
  Timer? _countdownTimer;
  Timer? _prosesTimer;

  // Tracking wajah
  Rect? _wajahRect;
  Size? _previewSize;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initKamera();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _prosesTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  Future<void> _initKamera() async {
    setState(() => _loading = true);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() { _loading = false; _pesan = 'Kamera tidak tersedia'; });
        return;
      }

      final kamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _isFrontCamera = kamera.lensDirection == CameraLensDirection.front;

      _cameraController = CameraController(
        kamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      _previewSize = _cameraController!.value.previewSize;

      if (!mounted) return;
      setState(() { _cameraReady = true; _loading = false; });

      _cameraController!.startImageStream(_prosesFrame);
    } catch (e) {
      setState(() { _loading = false; _pesan = 'Gagal buka kamera: $e'; });
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
      if (inputImage == null) {
        _memproses = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) {
        _memproses = false;
        return;
      }

      if (faces.isEmpty) {
        setState(() {
          _wajahRect = null;
          if (!_livenessOk) _instruksi = 'Posisikan wajah di kotak';
          _kedipTerdeteksi = false;
          _mataTerbuka = false;
        });
        _memproses = false;
        return;
      }

      final face = faces.first;
      final leftEye = face.leftEyeOpenProbability ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;
      final rataEye = (leftEye + rightEye) / 2;

      // Simpan rect mentahan, nanti di-mapping di UI
      setState(() {
        _wajahRect = face.boundingBox;
      });

      // Logika kedip
      if (!_kedipTerdeteksi) {
        if (rataEye > 0.7 && !_mataTerbuka) {
          setState(() {
            _mataTerbuka = true;
            _instruksi = 'Kedipkan mata Anda 👁️';
          });
        } else if (rataEye < 0.25 && _mataTerbuka) {
          setState(() {
            _kedipTerdeteksi = true;
            _instruksi = 'Kedipan terdeteksi! ✅';
          });
        }
      } else if (!_livenessOk) {
        if (rataEye > 0.7) {
          setState(() {
            _livenessOk = true;
            _instruksi = 'Jangan bergerak...';
            _countdown = 2;
          });
          _mulaiCountdown();
        }
      }
    } catch (_) {}

    _memproses = false;
  }

  void _mulaiCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
          _instruksi = 'Jangan bergerak... $_countdown';
        }
      });
      if (_countdown <= 0) {
        t.cancel();
        _ambilFotoOtomatis();
      }
    });
  }

  Future<void> _ambilFotoOtomatis() async {
    if (_cameraController == null || !_cameraReady) return;
    try {
      await _cameraController!.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 300));
      final file = await _cameraController!.takePicture();
      setState(() {
        _foto = File(file.path);
        _instruksi = 'Foto berhasil diambil 📸';
      });
      _prosesTimer = Timer(const Duration(seconds: 1), _kirimAbsen);
    } catch (e) {
      setState(() => _pesan = 'Gagal ambil foto: $e');
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final camera = _cameraController!.description;
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

  void _ulangi() {
    _countdownTimer?.cancel();
    _prosesTimer?.cancel();
    _lastProcess = 0;
    setState(() {
      _foto = null;
      _pesan = '';
      _instruksi = 'Posisikan wajah di kotak';
      _livenessOk = false;
      _mataTerbuka = false;
      _kedipTerdeteksi = false;
      _countdown = 0;
      _wajahRect = null;
    });
    _cameraController?.startImageStream(_prosesFrame);
  }

  Future<void> _kirimAbsen() async {
    if (_foto == null) return;
    setState(() {
      _mengirim = true;
      _pesan = '';
    });

    final lat = widget.posisi?.latitude ?? 0.0;
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

  @override
  Widget build(BuildContext context) {
    final isMasuk = widget.tipe == 'masuk';
    final color = isMasuk ? const Color(0xFF1B5E20) : Colors.blue[700]!;
    final label = isMasuk ? 'Absen Masuk' : 'Absen Keluar';

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
        // Area preview
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Camera preview - gunakan ClipRect saja, biarkan natural
              ClipRect(
                child: CameraPreview(_cameraController!),
              ),

              // Overlay kotak deteksi (indikator sederhana)
              if (_wajahRect != null)
                _buildFaceIndicator(color),

              // Instruksi di atas
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: _buildInstructionBubble(color),
              ),

              // Countdown di tengah
              if (_countdown > 0)
                _buildCountdownCircle(color),

              // Error message
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

  Widget _buildInstructionBubble(Color color) {
    IconData icon;
    Color iconColor;
    
    if (_livenessOk) {
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (_kedipTerdeteksi) {
      icon = Icons.remove_red_eye;
      iconColor = Colors.orange;
    } else if (_wajahRect != null) {
      icon = Icons.face;
      iconColor = Colors.white;
    } else {
      icon = Icons.person_search;
      iconColor = Colors.white70;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _instruksi,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCircle(Color color) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$_countdown',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.bold,
          ),
        ),
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
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _pesan,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceIndicator(Color color) {
    // Sederhana: tampilkan ikon centang jika wajah terdeteksi
    // tanpa kotak yang rumit
    if (_livenessOk) {
      return Positioned(
        top: 80,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 30),
        ),
      );
    }
    
    if (_kedipTerdeteksi) {
      return Positioned(
        top: 80,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.remove_red_eye, color: Colors.white, size: 30),
        ),
      );
    }

    // Wajah terdeteksi tapi belum kedip
    return const SizedBox.shrink();
  }

  Widget _buildKonfirmasi(Color color, String label) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Foto hasil
        Image.file(_foto!, fit: BoxFit.cover),

        // Overlay loading
        if (_mengirim)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Mengirim $label...',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

        // Error
        if (_pesan.isNotEmpty)
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: _buildErrorBubble(),
          ),

        // Tombol ulangi
        if (!_mengirim)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _ulangi,
              icon: const Icon(Icons.refresh),
              label: const Text('Ulangi Foto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
