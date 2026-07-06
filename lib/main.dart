import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Ditambahkan untuk mengatur warna status bar
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const AbsenMarsaApp());
}

class AbsenMarsaApp extends StatelessWidget {
  const AbsenMarsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absen MARSA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50), // Menggunakan hijau aksen yang lebih cerah
          primary: const Color(0xFF4CAF50),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// SPLASH SCREEN (VERSI CLEAN & CERAH)
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // Mengatur status bar di bagian atas layar agar ikonnya berwarna gelap (karena background putih)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _checkLogin();
  }

  Future<void> _checkLogin() async {
  await Future.delayed(const Duration(seconds: 1));
  
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(ApiConfig.tokenKey);

  if (!mounted) return;

  if (token != null && token.isNotEmpty) {
    // Verifikasi token masih valid ke server
    final res = await ApiService.getPegawaiProfil();
    if (!mounted) return;
    
    if (res['status'] == true) {
      // Token valid → langsung dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      // Token expired/invalid → hapus → login
      await ApiService.clearToken();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Ganti background jadi putih bersih total
      body: Column(
        children: [
          // Bagian Tengah: Logo & Teks Sekolah
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- LOGO CLEAN (TANPA BORDER / CONTAINER PUTIH KAKU) ---
                  Image.asset(
                    'assets/logo.png',
                    width: 140, // Sedikit diperbesar agar proporsional
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),
                  
                  // --- TEKS GELAP MODERN ---
                  const Text(
                    'Absen MARSA',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87, // Diubah jadi gelap agar kontras
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'SMK Ma\'arif 9 Kebumen',
                    style: TextStyle(
                      color: Colors.black54, // Abu-abu halus minimalis
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bagian Bawah: Loading Indikator & Footer
          Padding(
            padding: const EdgeInsets.only(bottom: 40.0),
            child: Column(
              children: [
                // Loading indicator warna hijau cerah
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Powered by MARSA Tech',
                  style: TextStyle(
                    color: Colors.black38,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}