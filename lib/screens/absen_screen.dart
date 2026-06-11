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

class _AbsenScreenState extends State<AbsenScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isReady = false;
  bool _mengirim = false;
  bool _memproses = false;
  int _lastProcess = 0;
  File? _foto;
  String _pesan = '';
  String _instruksi = 'Arahkan wajah ke kamera';

  // Liveness
  int _kedipDiminta = 1;
  int _kedipCount = 0;
  bool _sedangKedip = false;
  bool _livenessSelesai = false;

  // Anti-cheat
  int _frameStabil = 0;
  int _frameMataBuka = 0;
  List<double> _historyEulerY = [];
  Rect? _wajahRect;

  // Capture
  File? _fotoCadangan; // Foto diambil lebih awal
  bool _sedangValidasiFoto = false;
  int _countdown = 3;
  Timer? _timer;

  static const int _MIN_STABIL = 8;
  static const int _MIN_MATA = 6;
  static const double _MAX_EULER = 20.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _kedipDiminta = Random().nextInt(2) + 1;
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
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _cameraController?.dispose();
    _faceDetector?.close();
    _fotoCadangan?.delete();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initKamera();
    }
  }

  Future<void> _initKamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _pesan = 'Kamera tidak tersedia');
        return;
      }

      final kamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        kamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() => _isReady = true);

      _cameraController!.startImageStream(_prosesFrame);
    } catch (e) {
      try {
        // Fallback
        final cameras = await availableCameras();
        final kamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        _cameraController = CameraController(
          kamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (!mounted) return;
        setState(() => _isReady = true);
        _cameraController!.startImageStream(_prosesFrame);
      } catch (e2) {
        setState(() => _pesan = 'Gagal: $e2');
      }
    }
  }

  Future<void> _prosesFrame(CameraImage image) async {
    if (_memproses || _sedangValidasiFoto || !_isReady) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcess < 300) return;
    _lastProcess = now;

    _memproses = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _memproses = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);
      if (!mounted || !_isReady) {
        _memproses = false;
        return;
      }

      if (faces.isEmpty) {
        setState(() {
          _wajahRect = null;
          _frameStabil = 0;
          _frameMataBuka = 0;
          _historyEulerY.clear();

          if (_countdown < 3) {
            _resetLiveness('Wajah tidak terdeteksi!');
          } else {
            _instruksi = 'Arahkan wajah ke kamera';
          }
        });
        _memproses = false;
        return;
      }

      final face = faces.first;
      final mataKiri = face.leftEyeOpenProbability ?? 1.0;
      final mataKanan = face.rightEyeOpenProbability ?? 1.0;
      final rataMata = (mataKiri + mataKanan) / 2;
      final eulerY = face.headEulerAngleY ?? 0;
      final eulerX = face.headEulerAngleX ?? 0;

      if (eulerY.abs() > _MAX_EULER || eulerX.abs() > _MAX_EULER) {
        setState(() {
          _wajahRect = face.boundingBox;
          _frameStabil = 0;
          _frameMataBuka = 0;
          _instruksi = 'Hadapkan wajah lurus ke kamera';

          if (_countdown < 3) {
            _resetLiveness('Posisi kepala miring!');
          }
        });
        _memproses = false;
        return;
      }

      setState(() => _wajahRect = face.boundingBox);

      // Stabilitas
      _historyEulerY.add(eulerY);
      if (_historyEulerY.length > 5) _historyEulerY.removeAt(0);

      if (_historyEulerY.length >= 3) {
        final maxY = _historyEulerY.reduce(max);
        final minY = _historyEulerY.reduce(min);
        if ((maxY - minY).abs() < 3.0) {
          _frameStabil++;
        } else {
          _frameStabil = 0;
          if (_countdown < 3) {
            _resetLiveness('Jangan bergerak!');
            _memproses = false;
            return;
          }
        }
      }

      // Mata buka
      if (rataMata > 0.6) {
        _frameMataBuka++;
      } else {
        _frameMataBuka = 0;
      }

      final mataBukaStabil = _frameMataBuka >= _MIN_MATA;
      final wajahStabil = _frameStabil >= _MIN_STABIL;

      if (!wajahStabil || !mataBukaStabil) {
        if (!_livenessSelesai) {
          setState(() => _instruksi = 'Tahan posisi, buka mata lebar');
        }
        _memproses = false;
        return;
      }

      // Kedip
      if (!_livenessSelesai) {
        if (rataMata < 0.15 && !_sedangKedip) {
          _sedangKedip = true;
          setState(() => _instruksi = 'Kedip terdeteksi...');
        } else if (rataMata > 0.6 && _sedangKedip) {
          _sedangKedip = false;
          _kedipCount++;

          if (_kedipCount >= _kedipDiminta) {
            setState(() {
              _livenessSelesai = true;
              _countdown = 3;
              _instruksi = 'Berhasil! Jangan bergerak...';
            });
            _mulaiCountdown();
          } else {
            setState(() {
              _instruksi = 'Kedip ${_kedipCount}/${_kedipDiminta}';
            });
          }
        }
      }
    } catch (_) {}

    _memproses = false;
  }

  void _mulaiCountdown() {
    _timer?.cancel();
    _fotoCadangan?.delete();
    _fotoCadangan = null;
    _sedangValidasiFoto = false;

    _timer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted || !_isReady) {
        t.cancel();
        return;
      }

      // Cek wajah masih ada
      if (_wajahRect == null || _frameStabil < _MIN_STABIL) {
        t.cancel();
        _resetLiveness('Wajah berubah! Ulangi');
        return;
      }

      if (_countdown > 1) {
        setState(() {
          _countdown--;
          _instruksi = 'Jangan bergerak... $_countdown';
        });
      } else if (_countdown == 1) {
        // AMBIL FOTO SEKARANG (sebelum countdown 0)
        t.cancel();
        _instruksi = '📸 Memotret...';
        _ambilDanValidasiFoto();
      }
    });
  }

  Future<void> _ambilDanValidasiFoto() async {
    if (_cameraController == null) {
      _resetLiveness('Error kamera!');
      return;
    }

    _sedangValidasiFoto = true;

    try {
      // Stop stream
      await _cameraController!.stopImageStream();

      // Ambil foto
      final file = await _cameraController!.takePicture();
      _fotoCadangan = File(file.path);

      if (!mounted) return;

      // ⭐ VALIDASI: cek apakah foto mengandung wajah
      final adaWajah = await _cekFotoAdaWajah(_fotoCadangan!);

      if (!mounted) return;

      if (adaWajah) {
        // BERHASIL! Foto valid
        setState(() {
          _foto = _fotoCadangan;
          _countdown = 0;
          _instruksi = 'Foto valid! ✅';
        });
        _sedangValidasiFoto = false;
        // Kirim ke server
        Future.delayed(const Duration(milliseconds: 200), _kirimAbsen);
      } else {
        // GAGAL! Tidak ada wajah di foto
        _fotoCadangan?.delete();
        _fotoCadangan = null;
        _sedangValidasiFoto = false;
        _resetLiveness('⚠️ Tidak ada wajah di foto! Curang terdeteksi!');
      }
    } catch (e) {
      _fotoCadangan?.delete();
      _fotoCadangan = null;
      _sedangValidasiFoto = false;
      _resetLiveness('Error! Ulangi');
    }
  }

  Future<bool> _cekFotoAdaWajah(File foto) async {
    try {
      // Baca file foto sebagai InputImage
      final inputImage = InputImage.fromFile(foto);
      
      // Deteksi wajah di foto
      final faces = await _faceDetector!.processImage(inputImage);
      
      // Return true jika ada wajah
      return faces.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  void _resetLiveness(String msg) {
    _timer?.cancel();
    _fotoCadangan?.delete();
    _fotoCadangan = null;
    _sedangValidasiFoto = false;
    
    setState(() {
      _countdown = 3;
      _livenessSelesai = false;
      _kedipCount = 0;
      _sedangKedip = false;
      _frameStabil = 0;
      _frameMataBuka = 0;
      _historyEulerY.clear();
      _instruksi = '⚠️ $msg';
    });

    if (_foto == null && _cameraController != null) {
      _cameraController!.startImageStream(_prosesFrame);
    }
  }

  void _ulangi() {
    _timer?.cancel();
    _fotoCadangan?.delete();
    _fotoCadangan = null;
    _sedangValidasiFoto = false;
    _kedipDiminta = Random().nextInt(2) + 1;

    setState(() {
      _foto = null;
      _pesan = '';
      _countdown = 3;
      _livenessSelesai = false;
      _kedipCount = 0;
      _sedangKedip = false;
      _frameStabil = 0;
      _frameMataBuka = 0;
      _historyEulerY.clear();
      _wajahRect = null;
      _instruksi = 'Arahkan wajah ke kamera';
    });

    _cameraController?.startImageStream(_prosesFrame);
  }

  Future<void> _kirimAbsen() async {
    if (_foto == null) return;

    setState(() => _mengirim = true);

    final lat = widget.posisi?.latitude ?? 0.0;
    final lng = widget.posisi?.longitude ?? 0.0;

    Map<String, dynamic> res;
    if (widget.tipe == 'masuk') {
      res = await ApiService.absenMasuk(lat, lng, fotoFile: _foto);
    } else {
      res = await ApiService.absenKeluar(lat, lng, fotoFile: _foto);
    }

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
        _pesan = res['messages']?['error'] ?? res['message'] ?? 'Gagal';
      });
      _ulangi();
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

  @override
  Widget build(BuildContext context) {
    final isMasuk = widget.tipe == 'masuk';
    final color = isMasuk ? const Color(0xFF1B5E20) : Colors.blue[700]!;
    final label = isMasuk ? 'Absen Masuk' : 'Absen Keluar';

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
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _foto != null
              ? _buildKonfirmasi(color, label)
              : _buildKamera(color),
    );
  }

  Widget _buildKamera(Color color) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),

        // Indikator kedip
        if (!_livenessSelesai)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_kedipDiminta, (i) {
                final done = i < _kedipCount;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: done ? Colors.green : Colors.black38,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done ? Colors.green : Colors.white54,
                      width: 2.5,
                    ),
                  ),
                  child: Icon(
                    Icons.remove_red_eye,
                    color: done ? Colors.white : Colors.white70,
                    size: 22,
                  ),
                );
              }),
            ),
          ),

        // Instruksi
        Positioned(
          top: 50,
          left: 20,
          right: 20,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                _instruksi,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),

        // Countdown atau loading validasi
        if ((_livenessSelesai && _countdown > 0) || _sedangValidasiFoto)
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _sedangValidasiFoto
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        '$_countdown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),

        // Error
        if (_pesan.isNotEmpty)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _pesan,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
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
        Image.file(_foto!, fit: BoxFit.cover),
        if (_mengirim)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Mengirim...',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ),
        if (!_mengirim)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _ulangi,
              icon: const Icon(Icons.refresh),
              label: const Text('Ulangi'),
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