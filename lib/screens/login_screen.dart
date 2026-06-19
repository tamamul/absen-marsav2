import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // jika tidak digunakan, abaikan
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'dashboard_screen.dart';
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  // Memuat data tersimpan dari SharedPreferences
  Future<void> _loadSavedLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('saved_username') ?? '';
      final password = prefs.getString('saved_password') ?? '';
      final remember = prefs.getBool('remember_me') ?? true;

      setState(() {
        _usernameController.text = username;
        _passwordController.text = password;
        _rememberMe = remember;
      });
    } catch (e) {
      // Jika terjadi error saat membaca preferences, abaikan
      debugPrint('Error loading saved login: $e');
    }
  }

  // Fungsi login dengan penanganan error lengkap
  Future<void> _doLogin() async {
    // Validasi form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await ApiService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      // Cek apakah response berhasil
      if (response['status'] == true) {
        // Ambil token dan data user
        final token = response['data']?['token'];
        final user = response['data']?['user'];

        if (token == null || user == null) {
          throw Exception('Data token atau user tidak lengkap');
        }

        // Simpan token di ApiService
        await ApiService.saveToken(token);

        // Simpan user ke SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConfig.userKey, jsonEncode(user));

        // Simpan / hapus credential sesuai remember me
        if (_rememberMe) {
          await prefs.setString('saved_username', _usernameController.text.trim());
          await prefs.setString('saved_password', _passwordController.text);
          await prefs.setBool('remember_me', true);
        } else {
          await prefs.remove('saved_username');
          await prefs.remove('saved_password');
          await prefs.setBool('remember_me', false);
        }

        if (!mounted) return;
        // Navigasi ke dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        // Tampilkan pesan error dari server
        final errorMsg = response['messages']?['error'] ?? 'Login gagal, periksa kembali data Anda';
        _showSnackBar(errorMsg, isError: true);
      }
    } catch (e) {
      // Tangani error koneksi atau lainnya
      _showSnackBar('Terjadi kesalahan: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Snackbar custom dengan desain modern
  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Palet warna cerah modern
    const Color primaryColor = Color(0xFF1B5E20); // Hijau sekolah
    const Color accentColor = Color(0xFF2E7D32);
    const Color surfaceColor = Color(0xFFF8FAF8); // Latar belakang soft

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo dengan efek bayangan halus
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Judul dan subjudul
                  const Text(
                    'Absen MARSA',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'SMK Ma\'arif 9 Kebumen',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Card untuk form dengan shadow halus
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    color: surfaceColor,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Field Username
                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: InputDecoration(
                              labelText: 'Username / Email',
                              labelStyle: const TextStyle(color: Colors.black54),
                              prefixIcon: const Icon(Icons.person_outline, color: primaryColor),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: primaryColor, width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Username wajib diisi';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                          ),
                          const SizedBox(height: 16),

                          // Field Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(color: Colors.black54),
                              prefixIcon: const Icon(Icons.lock_outline, color: primaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.black45,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: primaryColor, width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password wajib diisi';
                              }
                              if (value.length < 6) {
                                return 'Password minimal 6 karakter';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) {
                              // Submit form jika user tekan done
                              _doLogin();
                            },
                          ),
                          const SizedBox(height: 8),

                          // Remember Me (custom row)
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value ?? true;
                                    });
                                  },
                                  activeColor: primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Ingat saya',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  // Fungsi lupa password jika ada
                                  _showSnackBar('Fungsi lupa password sedang dalam pengembangan', isError: false);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Lupa Password?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Tombol Login
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _doLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'MASUK',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer / versi
                  const SizedBox(height: 24),
                  const Text(
                    'Versi 2.0.0',
                    style: TextStyle(
                      color: Colors.black38,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}