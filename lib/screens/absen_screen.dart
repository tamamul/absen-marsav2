import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:math' as math;
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
  int _lastProcess     = 0; // Throttle timestamp
  File? _foto;
  String _pesan        = '';
  String _instruksi    = 'Posisikan wajah di kotak';

  // Liveness
  bool _livenessOk     = false;
  bool _mataTerbuka    = false;
  bool _kedipTerdeteksi = false;
  int _countdown       = 0;
  Timer? _countdownTimer;
  Timer? _prosesTimer;

  // Tracking wajah
  Rect? _wajahRect;
  Size? _previewSize;

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

      // Mulai stream deteksi
      _cameraController!.startImageStream(_prosesFrame);
    } catch (e) {
      setState(() { _loading = false; _pesan = 'Gagal buka kamera: $e'; });
    }
  }

  Future<void> _prosesFrame(CameraImage image) async {
    if (_memproses || _livenessOk || !mounted) return;
    
    // Throttle: proses maksimal 1x per 300ms
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcess < 300) return;
    _lastProcess = now;
    
    _memproses = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) { _memproses = false; return; }

      final faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) { _memproses = false; return; }

      if (faces.isEmpty) {
        setState(() {
          _wajahRect       = null;
          _instruksi       = 'Posisikan wajah di kotak';
          _kedipTerdeteksi = false;
          _mataTerbuka     = false;
        });
        _memproses = false;
        return;
      }

      final face    = faces.first;
      final leftEye  = face.leftEyeOpenProbability ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;
      final rataEye  = (leftEye + rightEye) / 2;

      setState(() => _wajahRect = face.boundingBox);

      if (!_kedipTerdeteksi) {
        if (rataEye > 0.7 && !_mataTerbuka) {
          setState(() {
            _mataTerbuka = true;
            _instruksi   = 'Kedipkan mata Anda';
          });
        } else if (rataEye < 0.3 && _mataTerbuka) {
          setState(() {
            _kedipTerdeteksi = true;
            _instruksi       = 'Kedipan terdeteksi! ✓';
          });
        }
      } else if (!_livenessOk) {
        if (rataEye > 0.7) {
          setState(() {
            _livenessOk = true;
            _instruksi  = 'Liveness OK! Bersiap...';
            _countdown  = 2;
          });
          _mulaiCountdown();
        }
      }
    } catch (_) {}

    _memproses = false;
  }

  void _mulaiCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
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
        _foto      = File(file.path);
        _instruksi = 'Foto diambil!';
      });
      // Auto kirim setelah 1 detik
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
    _lastProcess = 0; // Reset throttle
    setState(() {
      _foto            = null;
      _pesan           = '';
      _instruksi       = 'Posisikan wajah di kotak';
      _livenessOk      = false;
      _mataTerbuka     = false;
      _kedipTerdeteksi = false;
      _countdown       = 0;
      _wajahRect       = null;
    });
    _cameraController?.startImageStream(_prosesFrame);
  }

  Future<void> _kirimAbsen() async {
    if (_foto == null) return;
    setState(() { _mengirim = true; _pesan = ''; });

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
              : _foto != null
                  ? _buildKonfirmasi(color, label)
                  : _buildKamera(color),
    );
  }

  Widget _buildKamera(Color color) {
  final previewSize = _previewSize;
  
  return Stack(
    alignment: Alignment.center,
    children: [
      // Preview kamera dengan aspect ratio yang benar
      if (previewSize != null)
        Center(
          child: AspectRatio(
            aspectRatio: previewSize.width / previewSize.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),

      // Kotak tracking wajah
      if (_wajahRect != null && previewSize != null)
        _buildWajahBox(color, previewSize),

      // Instruksi atas
      Positioned(
        top: 16, left: 16, right: 16,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _livenessOk
                      ? Icons.check_circle
                      : _kedipTerdeteksi
                          ? Icons.remove_red_eye
                          : Icons.face,
                  color: _livenessOk
                      ? Colors.green
                      : _kedipTerdeteksi
                          ? Colors.orange
                          : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(_instruksi,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),

      // Countdown
      if (_countdown > 0)
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: color.withOpacity(0.85),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$_countdown',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold)),
          ),
        ),

      // Error
      if (_pesan.isNotEmpty)
        Positioned(
          bottom: 20, left: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_pesan,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center),
          ),
        ),
    ],
  );
}

Widget _buildWajahBox(Color color, Size previewSize) {
  return LayoutBuilder(
    builder: (context, constraints) {
      // Hitung aspect ratio preview
      final previewRatio = previewSize.width / previewSize.height;
      final screenRatio = constraints.maxWidth / constraints.maxHeight;
      
      // Hitung ukuran preview yang sebenarnya di layar
      double displayWidth, displayHeight;
      if (previewRatio > screenRatio) {
        // Preview lebih lebar dari layar
        displayWidth = constraints.maxWidth;
        displayHeight = constraints.maxWidth / previewRatio;
      } else {
        // Preview lebih tinggi dari layar
        displayHeight = constraints.maxHeight;
        displayWidth = constraints.maxHeight * previewRatio;
      }

      // Offset agar preview di tengah
      final offsetX = (constraints.maxWidth - displayWidth) / 2;
      final offsetY = (constraints.maxHeight - displayHeight) / 2;

      // Skala dari ukuran preview kamera ke ukuran display
      final scaleX = displayWidth / previewSize.width;
      final scaleY = displayHeight / previewSize.height;

      // Mapping kotak wajah
      // Koordinat dari ML Kit: x horizontal, y vertikal
      final left = offsetX + (_wajahRect!.left * scaleX);
      final top = offsetY + (_wajahRect!.top * scaleY);
      final width = _wajahRect!.width * scaleX;
      final height = _wajahRect!.height * scaleY;

      final boxColor = _livenessOk
          ? Colors.green
          : _kedipTerdeteksi
              ? Colors.orange
              : color;

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: boxColor, width: 3),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    },
  );
}

  Widget _buildKonfirmasi(Color color, String label) {
    return Stack(
      children: [
        SizedBox.expand(
          child: Image.file(_foto!, fit: BoxFit.cover),
        ),
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
            bottom: 100, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_pesan,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center),
            ),
          ),
        if (!_mengirim)
          Positioned(
            bottom: 30, left: 16, right: 16,
            child: OutlinedButton.icon(
              onPressed: _ulangi,
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
      ],
    );
  }
}
