import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LivenessDetectionPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const LivenessDetectionPage({Key? key, required this.cameras}) : super(key: key);

  @override
  _LivenessDetectionPageState createState() => _LivenessDetectionPageState();
}

class _LivenessDetectionPageState extends State<LivenessDetectionPage> {
  CameraController? _cameraController;
  late CameraDescription _frontCamera;
  
  // ML Kit
  final FaceDetector _faceDetector = GoogleMlKit.vision.faceDetector(
    FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      minFaceSize: 0.3,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  
  // State management
  bool _isDetecting = false;
  bool _faceDetected = false;
  String _statusMessage = "Posisikan wajah di depan kamera";
  String _challengeAction = "";
  bool _challengeCompleted = false;
  int _countdown = 5;
  Timer? _countdownTimer;
  bool _isTakingPhoto = false;
  
  // Flow states
  enum LivenessFlow {
    detectFace,
    challenge,
    countdown,
    takePhoto,
    verifyPhoto,
    uploadServer
  }
  
  LivenessFlow _currentFlow = LivenessFlow.detectFace;
  
  // Challenge types
  final List<String> _challenges = ["Kedipkan Mata", "Tersenyum"];
  String _currentChallenge = "";
  bool _blinkDetected = false;
  bool _smileDetected = false;
  double _smileProbability = 0.0;
  double _leftEyeOpenProbability = 1.0;
  double _rightEyeOpenProbability = 1.0;
  
  // Photo result
  XFile? _capturedPhoto;
  bool _faceFoundInPhoto = false;

  @override
  void initState() {
    super.initState();
    _frontCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      _frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    
    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      
      setState(() {});
      _startImageStream();
    } catch (e) {
      print("Error initializing camera: $e");
      setState(() {
        _statusMessage = "Gagal menginisialisasi kamera";
      });
    }
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) {
      if (_isDetecting) return;
      
      _isDetecting = true;
      _processCameraImage(image);
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final InputImageRotation imageRotation = InputImageRotation.rotation270deg;
      final InputImageFormat inputImageFormat = InputImageFormat.nv21;

      final planeData = image.planes.map(
        (Plane plane) {
          return InputImagePlaneMetadata(
            bytesPerRow: plane.bytesPerRow,
            height: plane.height,
            width: plane.width,
          );
        },
      ).toList();

      final inputImageData = InputImageData(
        size: imageSize,
        imageRotation: imageRotation,
        inputImageFormat: inputImageFormat,
        planeData: planeData,
      );

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        inputImageData: inputImageData,
      );

      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          if (faces.isNotEmpty) {
            final face = faces.first;
            _faceDetected = true;
            
            // Update probabilities
            _smileProbability = face.smilingProbability ?? 0.0;
            _leftEyeOpenProbability = face.leftEyeOpenProbability ?? 1.0;
            _rightEyeOpenProbability = face.rightEyeOpenProbability ?? 1.0;
            
            _handleFlowState(face);
          } else {
            _faceDetected = false;
            if (_currentFlow == LivenessFlow.detectFace) {
              _statusMessage = "Wajah tidak terdeteksi";
            }
          }
        });
      }
    } catch (e) {
      print("Error processing image: $e");
    } finally {
      _isDetecting = false;
    }
  }

  void _handleFlowState(Face face) {
    switch (_currentFlow) {
      case LivenessFlow.detectFace:
        _handleFaceDetection();
        break;
      case LivenessFlow.challenge:
        _handleChallenge(face);
        break;
      case LivenessFlow.countdown:
      case LivenessFlow.takePhoto:
      case LivenessFlow.verifyPhoto:
      case LivenessFlow.uploadServer:
        // Handled by other methods
        break;
    }
  }

  void _handleFaceDetection() {
    if (_faceDetected) {
      _statusMessage = "Wajah terdeteksi!";
      // Lanjut ke challenge
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _currentFlow = LivenessFlow.challenge;
            _selectRandomChallenge();
          });
        }
      });
    } else {
      _statusMessage = "Posisikan wajah di depan kamera";
    }
  }

  void _selectRandomChallenge() {
    final random = DateTime.now().millisecondsSinceEpoch % _challenges.length;
    _currentChallenge = _challenges[random];
    _challengeAction = _currentChallenge;
    _statusMessage = "Lakukan: $_currentChallenge";
    
    // Reset detection flags
    _blinkDetected = false;
    _smileDetected = false;
    _challengeCompleted = false;
  }

  void _handleChallenge(Face face) {
    if (_challengeCompleted) return;
    
    bool conditionMet = false;
    
    if (_currentChallenge == "Kedipkan Mata") {
      // Deteksi kedipan
      if (_leftEyeOpenProbability < 0.3 || _rightEyeOpenProbability < 0.3) {
        _blinkDetected = true;
      }
      
      if (_blinkDetected && _leftEyeOpenProbability > 0.7 && _rightEyeOpenProbability > 0.7) {
        conditionMet = true;
      }
    } else if (_currentChallenge == "Tersenyum") {
      // Deteksi senyum
      if (_smileProbability > 0.7) {
        _smileDetected = true;
        conditionMet = true;
      }
    }
    
    if (conditionMet) {
      setState(() {
        _challengeCompleted = true;
        _statusMessage = "Berhasil! $_currentChallenge terdeteksi";
        _currentFlow = LivenessFlow.countdown;
      });
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdown = 5;
    _countdownTimer?.cancel();
    
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_countdown > 0) {
          _statusMessage = "Jangan bergerak... $_countdown";
          _countdown--;
        } else {
          timer.cancel();
          _currentFlow = LivenessFlow.takePhoto;
          _takePhoto();
        }
      });
    });
  }

  Future<void> _takePhoto() async {
    if (_isTakingPhoto) return;
    
    setState(() {
      _isTakingPhoto = true;
      _statusMessage = "Mengambil foto...";
    });
    
    try {
      await Future.delayed(Duration(milliseconds: 500)); // Brief delay untuk stabilitas
      
      final XFile photo = await _cameraController!.takePicture();
      
      setState(() {
        _capturedPhoto = photo;
        _currentFlow = LivenessFlow.verifyPhoto;
      });
      
      await _verifyPhotoWithMLKit(photo);
    } catch (e) {
      print("Error taking photo: $e");
      setState(() {
        _statusMessage = "Gagal mengambil foto. Ulangi.";
        _isTakingPhoto = false;
        _currentFlow = LivenessFlow.detectFace;
        _faceDetected = false;
        _challengeCompleted = false;
      });
    }
  }

  Future<void> _verifyPhotoWithMLKit(XFile photo) async {
    setState(() {
      _statusMessage = "Memverifikasi foto...";
    });
    
    try {
      final File imageFile = File(photo.path);
      final inputImage = InputImage.fromFile(imageFile);
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      
      setState(() {
        _isTakingPhoto = false;
        
        if (faces.isNotEmpty) {
          _faceFoundInPhoto = true;
          _statusMessage = "Verifikasi berhasil! Upload ke server...";
          _currentFlow = LivenessFlow.uploadServer;
          _uploadToServer(photo);
        } else {
          _faceFoundInPhoto = false;
          _statusMessage = "Wajah tidak terdeteksi di foto. Ulangi proses.";
          _currentFlow = LivenessFlow.detectFace;
          _faceDetected = false;
          _challengeCompleted = false;
          _capturedPhoto = null;
        }
      });
    } catch (e) {
      print("Error verifying photo: $e");
      setState(() {
        _statusMessage = "Gagal verifikasi. Ulangi.";
        _isTakingPhoto = false;
        _currentFlow = LivenessFlow.detectFace;
        _faceDetected = false;
        _challengeCompleted = false;
        _capturedPhoto = null;
      });
    }
  }

  Future<void> _uploadToServer(XFile photo) async {
    try {
      // Contoh upload ke server
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('YOUR_UPLOAD_URL_HERE'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          photo.path,
        ),
      );
      
      // Tambahkan metadata
      request.fields['challenge'] = _currentChallenge;
      request.fields['timestamp'] = DateTime.now().toIso8601String();
      
      var response = await request.send();
      
      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = "Upload berhasil!";
        });
        
        // Tampilkan dialog sukses atau navigasi ke halaman lain
        _showSuccessDialog();
      } else {
        throw Exception("Upload failed");
      }
    } catch (e) {
      print("Error uploading: $e");
      setState(() {
        _statusMessage = "Gagal upload. Coba lagi.";
        // Reset untuk mencoba lagi
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _currentFlow = LivenessFlow.detectFace;
              _faceDetected = false;
              _challengeCompleted = false;
              _capturedPhoto = null;
            });
          }
        });
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Sukses"),
        content: Text("Foto berhasil diverifikasi dan diupload!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Reset atau navigasi ke halaman lain
            },
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  // UI Helper methods
  Color _getStatusColor() {
    switch (_currentFlow) {
      case LivenessFlow.detectFace:
        return _faceDetected ? Colors.green : Colors.orange;
      case LivenessFlow.challenge:
        return _challengeCompleted ? Colors.green : Colors.orange;
      case LivenessFlow.countdown:
        return Colors.blue;
      case LivenessFlow.takePhoto:
        return Colors.purple;
      case LivenessFlow.verifyPhoto:
        return _faceFoundInPhoto ? Colors.green : Colors.red;
      case LivenessFlow.uploadServer:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Status bar
            Container(
              padding: EdgeInsets.all(16),
              color: _getStatusColor().withOpacity(0.8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            
            // Camera preview
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CameraPreview(_cameraController!),
                  
                  // Face guide overlay
                  if (_currentFlow == LivenessFlow.detectFace)
                    CustomPaint(
                      size: Size.infinite,
                      painter: FaceGuidePainter(
                        faceDetected: _faceDetected,
                      ),
                    ),
                  
                  // Challenge UI
                  if (_currentFlow == LivenessFlow.challenge)
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _currentChallenge == "Kedipkan Mata" 
                                ? Icons.remove_red_eye 
                                : Icons.emoji_emotions,
                            size: 50,
                            color: Colors.white,
                          ),
                          SizedBox(height: 10),
                          Text(
                            _challengeAction,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            _currentChallenge == "Kedipkan Mata"
                                ? "Kedipkan mata Anda"
                                : "Tersenyumlah",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Countdown UI
                  if (_currentFlow == LivenessFlow.countdown)
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withOpacity(0.8),
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _countdown.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  
                  // Loading indicator saat mengambil foto
                  if (_isTakingPhoto)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              "Memproses...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Info panel
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.grey[900],
              child: Column(
                children: [
                  // Flow indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFlowStep("Deteksi", LivenessFlow.detectFace),
                      Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
                      _buildFlowStep("Challenge", LivenessFlow.challenge),
                      Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
                      _buildFlowStep("Countdown", LivenessFlow.countdown),
                      Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
                      _buildFlowStep("Foto", LivenessFlow.takePhoto),
                      Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
                      _buildFlowStep("Verifikasi", LivenessFlow.verifyPhoto),
                      Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
                      _buildFlowStep("Upload", LivenessFlow.uploadServer),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Detection info
                  if (_faceDetected)
                    Text(
                      "Senyum: ${(_smileProbability * 100).toStringAsFixed(0)}% | "
                      "Mata Kiri: ${(_leftEyeOpenProbability * 100).toStringAsFixed(0)}% | "
                      "Mata Kanan: ${(_rightEyeOpenProbability * 100).toStringAsFixed(0)}%",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowStep(String label, LivenessFlow step) {
    final isActive = _currentFlow == step;
    final isCompleted = _currentFlow.index > step.index;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? _getStatusColor()
            : isCompleted
                ? Colors.green.withOpacity(0.5)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isActive
              ? _getStatusColor()
              : Colors.white24,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _faceDetector.close();
    _cameraController?.dispose();
    super.dispose();
  }
}

// Custom painter for face guide
class FaceGuidePainter extends CustomPainter {
  final bool faceDetected;
  
  FaceGuidePainter({required this.faceDetected});
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = faceDetected ? Colors.green : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    final double ovalWidth = size.width * 0.6;
    final double ovalHeight = size.height * 0.5;
    final double left = (size.width - ovalWidth) / 2;
    final double top = (size.height - ovalHeight) / 2;
    
    final RRect oval = RRect.fromLTRBR(
      left, top, left + ovalWidth, top + ovalHeight,
      Radius.circular(ovalWidth / 2),
    );
    
    canvas.drawRRect(oval, paint);
    
    // Draw text
    if (!faceDetected) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Posisikan wajah di sini',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, top - 30),
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}