import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
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
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      minFaceSize: 0.3,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _isDetecting         = false;
  bool _mengirim            = false;
  bool _validasi            = false;
  File? _foto;
  String _pesan             = '';

  // Challenge
  List<String> _challenges  = ['smile', 'blink', 'lookRight', 'lookLeft'];
  int  _challengeIndex      = 0;
  bool _waitingNeutral      = false;
  bool _challengeDone       = false;

  // Face data
  double? _senyum;
  double? _mataKiri;
  double? _matKanan;
  double? _eulerY;

  @override
  void initState() {
    super.initState();
    _challenges.shuffle();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController.stopImageStream();
    _faceDetector.close();
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front   = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(
      front,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController.initialize();
    if (!mounted) return;
    setState(() => _isCameraInitialized = true);
    _startStream();
  }

  void _startStream() {
    _cameraController.startImageStream((CameraImage image) {
      if (!_isDetecting && !_challengeDone) {
        _isDetecting = true;
        _detectFaces(image).then((_) => _isDetecting = false);
      }
    });
  }

  Future<void> _detectFaces(CameraImage image) async {
    try {
      // Gabung semua planes — persis seperti kode referensi
      final allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg, // hardcode seperti referensi
          format: InputImageFormat.nv21,               // hardcode nv21
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) return;

      if (faces.isNotEmpty) {
        final face = faces.first;
        setState(() {
          _senyum   = face.smilingProbability;
          _mataKiri = face.leftEyeOpenProbability;
          _matKanan = face.rightEyeOpenProbability;
          _eulerY   = face.headEulerAngleY;
        });
        _cekChallenge(face);
      } else {
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    }
  }

  void _cekChallenge(Face face) {
    if (_challengeDone) return;

    if (_waitingNeutral) {
      if (_isNeutral(face)) {
        setState(() => _waitingNeutral = false);
      }
      return;
    }

    final action    = _challenges[_challengeIndex];
    bool completed  = false;

    switch (action) {
      case 'smile':
        completed = (face.smilingProbability ?? 0) > 0.5;
        break;
      case 'blink':
        completed = (face.leftEyeOpenProbability  ?? 1) < 0.3 ||
                    (face.rightEyeOpenProbability ?? 1) < 0.3;
        break;
      case 'lookRight':
        completed = (face.headEulerAngleY ?? 0) < -10;
        break;
      case 'lookLeft':
        completed = (face.headEulerAngleY ?? 0) > 10;
        break;
    }

    if (completed) {
      _challengeIndex++;
      if (_challengeIndex >= _challenges.length) {
        // Semua challenge selesai → ambil foto
        setState(() => _challengeDone = true);
        _ambilFoto();
      } else {
        setState(() => _waitingNeutral = true);
      }
    }
  }

  bool _isNeutral(Face face) {
    return (face.smilingProbability    ?? 0)    < 0.1 &&
           (face.leftEyeOpenProbability  ?? 1)  > 0.7 &&
           (face.rightEyeOpenProbability ?? 1)  > 0.7 &&
           ((face.headEulerAngleY ?? 0).abs()  < 10);
  }

  Future<void> _ambilFoto() async {
    try {
      await _cameraController.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 400));
      final file = await _cameraController.takePicture();
      final foto = File(file.path);

      setState(() {
        _foto     = foto;
        _validasi = true;
      });

      // Validasi wajah dari foto
      final input = InputImage.fromFile(foto);
      final faces = await _faceDetector.processImage(input);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _validasi      = false;
          _foto          = null;
          _challengeDone = false;
          _challengeIndex = 0;
          _challenges.shuffle();
          _pesan = 'Wajah tidak terdeteksi di foto. Ulangi.';
        });
        _startStream();
      } else {
        setState(() => _validasi = false);
        await Future.delayed(const Duration(milliseconds: 300));
        _kirimAbsen();
      }
    } catch (e) {
      setState(() {
        _pesan         = 'Gagal ambil foto: $e';
        _challengeDone = false;
        _challengeIndex = 0;
      });
      _startStream();
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
      final warning   = res['warning'];
      final terlambat = res['terlambat'] == true;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Absen berhasil'),
        backgroundColor: terlambat ? Colors.orange : Colors.green,
        duration: const Duration(seconds: 3),
      ));

      if (warning != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Perhatian'),
            ]),
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
      final errMsg   = res['messages']?['error'] ??
          res['message'] ?? 'Absen gagal';
      final isPenting = errMsg.contains('belum dibuka') ||
          errMsg.contains('Belum waktunya') ||
          errMsg.contains('luar area');

      if (isPenting) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.block, color: Colors.red),
              SizedBox(width: 8),
              Text('Tidak Dapat Absen'),
            ]),
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
        setState(() => _pesan = errMsg);
        _ulangi();
      }
    }
  }

  void _ulangi() {
    setState(() {
      _foto           = null;
      _pesan          = '';
      _validasi       = false;
      _mengirim       = false;
      _challengeDone  = false;
      _challengeIndex = 0;
      _challenges.shuffle();
      _waitingNeutral = false;
    });
    _startStream();
  }

  String _instruksiChallenge() {
    if (_challengeDone) return '📸 Mengambil foto...';
    if (!_isCameraInitialized) return 'Menyiapkan kamera...';
    switch (_challenges[_challengeIndex]) {
      case 'smile':    return '😊 Tersenyum';
      case 'blink':    return '👁️ Kedipkan mata';
      case 'lookRight': return '👉 Lihat ke kanan';
      case 'lookLeft':  return '👈 Lihat ke kiri';
      default:         return '';
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
      body: !_isCameraInitialized
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
        CameraPreview(_cameraController),

        // Overlay gelap — cutout oval di tengah
        CustomPaint(painter: _OvalOverlayPainter(color: color)),

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
                _instruksiChallenge(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _challengeDone
                        ? Colors.green
                        : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),

        // Step indicator
        Positioned(
          top: 120, left: 20, right: 20,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_challenges.length, (i) {
                final done = i < _challengeIndex;
                final curr = i == _challengeIndex;
                return Container(
                  width: 10, height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: done
                        ? Colors.green
                        : curr
                            ? color
                            : Colors.white30,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
        ),

        // Debug info (bisa dihapus nanti)
        Positioned(
          bottom: 20, left: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Senyum: ${_senyum != null ? (_senyum! * 100).toStringAsFixed(0) : "N/A"}%',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11)),
                Text(
                  'Kedip: ${_mataKiri != null && _matKanan != null ? (((_mataKiri! + _matKanan!) / 2) * 100).toStringAsFixed(0) : "N/A"}%',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11)),
                Text(
                  'Arah: ${_eulerY?.toStringAsFixed(1) ?? "N/A"}°',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ),

        // Error
        if (_pesan.isNotEmpty)
          Positioned(
            bottom: 20, left: 20, right: 20,
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

        // Loading validasi/kirim
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
                        : 'Mengirim...',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16)),
                ],
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
        if (_foto != null) Image.file(_foto!, fit: BoxFit.cover),
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

// Overlay gelap dengan lubang oval di tengah
class _OvalOverlayPainter extends CustomPainter {
  final Color color;
  const _OvalOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final rx     = size.width  * 0.38;
    final ry     = size.height * 0.28;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCenter(
          center: center, width: rx * 2, height: ry * 2))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Border oval
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(
      Rect.fromCenter(
          center: center, width: rx * 2, height: ry * 2),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}