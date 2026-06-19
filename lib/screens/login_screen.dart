import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Konfigurasi sistem UI agar status bar juga clean/putih
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // StatusBar transparan
      statusBarIconBrightness: Brightness.dark, // Icon hitam (karena bg putih)
    ));

    // Inisialisasi Animasi Fade In (opsional biar makin halus)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Durasi animasi
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    
    _animationController.forward(); // Mulai animasi

    _navigateToNext();
  }

  // Fungsi untuk mengecek status login dan berpindah screen
  Future<void> _navigateToNext() async {
    // Delay SplashScreen selama 2.5 detik (biar kelihatan dulu logonya)
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    
    // Asumsi: Kita cek apakah ada token tersimpan
    // Sesuaikan kuncinya dengan yang kamu pakai di ApiService/ApiConfig
    // Di kode sebelumnya kamu pakai ApiService.saveToken(token)
    // Biasanya ini disimpan di SharedPreferences dengan key 'token'
    final String? token = prefs.getString('token'); 

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      // Jika token ada (user sudah login), pergi ke Dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      // Jika tidak ada token (belum login), pergi ke Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Definisi warna aksen hijau yang sama dengan tombol di LoginScreen baru
    const Color accentGreen = Color(0xFF4CAF50);

    return Scaffold(
      backgroundColor: Colors.white, // Background putih bersih total
      body: FadeTransition(
        opacity: _fadeAnimation, // Terapkan animasi fade in
        child: Column(
          children: [
            // Area Tengah (Logo & Teks)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- LOGO (CLEAN, NO BORDER, NO SHADOW) ---
                    Image.asset(
                      'assets/logo.png', // Pastikan path benar
                      width: 140, // Sedikit lebih besar karena clean
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    
                    // --- TYPOGRAPHY MINIMALIS ---
                    const Text(
                      'Absen MARSA',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87, // Teks gelap agar kontras
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SMK Ma\'arif 9 Kebumen',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54, // Teks abu-abu halus
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // --- AREA BAWAH (LOADING & FOOTER) ---
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Column(
                children: [
                  // Loading indicator kecil warna hijau aksen
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(accentGreen),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Footer minimalis
                  Text(
                    'Powered by MARSA Tech',
                    style: TextStyle(
                      color: Colors.black38, // Sangat tipis
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}