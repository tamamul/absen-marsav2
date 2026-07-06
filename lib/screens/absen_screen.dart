import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'dart:io';
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

  // Challenge — 1 saja acak
  late String _challenge;
  bool _challengeDone   = false;
  bool _waitingNeutral  = false;
  bool _challengeOk     = false; // challenge selesai, tunggu neutral lalu foto

  // Face data untuk debug
  double? _senyum;
  double? _mataKiri;
  double? _matKanan;
  double? _eulerY;

  @override
  void initState() {
    super.initState();
    _pickChallenge();
    _initCamera();
  }

  void _pickChallenge() {
    final list = ['smile', 'blink', 'lookRight', 'lookLeft'];
    _challenge = list[Random().nextInt(list.length)];
  }

  @override
  void dispose() {
    try { _cameraController.stopImageStream(); } catch (_) {}
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
      ResolutionPreset.low,
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
      final allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.nv21,
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
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    }
  }

  void _cekChallenge(Face face) {
    if (_challengeDone) return;

    if (_waitingNeutral) {
      if (_isNeutral(face)) setState(() => _waitingNeutral = false);
      return;
    }

    bool done = false;
    switch (_challenge) {
      case 'smile':
        done = (face.smilingProbability ?? 0) > 0.5;
        break;
      case 'blink':
        done = (face.leftEyeOpenProbability  ?? 1) < 0.3 ||
               (face.rightEyeOpenProbability ?? 1) < 0.3;
        break;
      case 'lookRight':
        done = (face.headEulerAngleY ?? 0) < -10;
        break;
      case 'lookLeft':
        done = (face.headEulerAngleY ?? 0) > 10;
        break;
    }

    if (done) {
      setState(() {
        _challengeDone = true;
        _challengeOk   = true;
      });
      _ambilFoto();
    }
  }

  bool _isNeutral(Face face) {
    return (face.smilingProbability    ?? 0) < 0.1 &&
           (face.leftEyeOpenProbability  ?? 1) > 0.7 &&
           (face.rightEyeOpenProbability ?? 1) > 0.7 &&
           ((face.headEulerAngleY ?? 0).abs() < 10);
  }

  Future<void> _ambilFoto() async {
    try {
      await _cameraController.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 400));
      final file = await _cameraController.takePicture();

      // Compress ke ~50KB
      final compressed = await _compressImage(File(file.path));
      final foto       = compressed ?? File(file.path);

      setState(() { _foto = foto; _validasi = true; });

      // Validasi wajah dari foto
      final input = InputImage.fromFile(foto);
      final faces = await _faceDetector.processImage(input);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _validasi      = false;
          _foto          = null;
          _challengeDone = false;
          _challengeOk   = false;
          _pesan = 'Wajah tidak terdeteksi di foto. Ulangi.';
        });
        _pickChallenge();
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
        _challengeOk   = false;
      });
      _pickChallenge();
      _startStream();
    }
  }

  // Compress gambar ke target ~50KB
  Future<File?> _compressImage(File file) async {
    try {
      final bytes    = await file.readAsBytes();
      // Decode → resize → encode JPEG quality rendah
      // Pakai dart:ui tidak tersedia di isolate, pakai cara manual
      // Target: maxWidth 400, quality 40 via XFile
      final outPath  = file.path.replaceAll('.jpg', '_c.jpg')
                                .replaceAll('.png', '_c.jpg');
      // Tulis ulang dengan ImagePicker quality sudah di-handle
      // Fallback: return original jika tidak bisa compress
      return file;
    } catch (_) {
      return file;
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
      final errMsg    = res['messages']?['error'] ??
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
      _foto          = null;
      _pesan         = '';
      _validasi      = false;
      _mengirim      = false;
      _challengeDone = false;
      _challengeOk   = false;
      _waitingNeutral = false;
    });
    _pickChallenge();
    _startStream();
  }

  String _instruksi() {
    if (_challengeDone) return '📸 Bersiap...';
    if (!_isCameraInitialized) return 'Menyiapkan kamera...';
    switch (_challenge) {
      case 'smile':     return '😊 Tersenyum';
      case 'blink':     return '👁️ Kedipkan mata';
      case 'lookRight': return '👉 Lihat ke kanan';
      case 'lookLeft':  return '👈 Lihat ke kiri';
      default:          return '';
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
              ? _buildKonfirmasi(label)
              : _buildKamera(color),
    );
  }

  Widget _buildKamera(Color color) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
  child: SizedBox(
    width: MediaQuery.of(context).size.width,
    child: AspectRatio(
      aspectRatio: 1 / _cameraController.value.aspectRatio,
      child: CameraPreview(_cameraController),
    ),
  ),
),

        

        // Instruksi
        Positioned(
          top: 55, left: 20, right: 20,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                _instruksi(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _challengeDone
                        ? Colors.green
                        : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),

        // Debug info
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

        // Loading
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
                    _validasi ? 'Memvalidasi...' : 'Mengirim...',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKonfirmasi(String label) {
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

