import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  Future<void> _loadSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();

    _loginCtrl.text = prefs.getString('saved_username') ?? '';
    _passwordCtrl.text = prefs.getString('saved_password') ?? '';

    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? true;
    });
  }

  Future<void> _doLogin() async {
    if (_loginCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      _showSnack('Username dan password wajib diisi');
      return;
    }

    setState(() => _loading = true);

    final res = await ApiService.login(
      _loginCtrl.text.trim(),
      _passwordCtrl.text,
    );

    setState(() => _loading = false);

    if (res['status'] == true) {
      final token = res['data']['token'];
      final user = res['data']['user'];

      await ApiService.saveToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConfig.userKey, jsonEncode(user));

      if (_rememberMe) {
        await prefs.setString('saved_username', _loginCtrl.text.trim());
        await prefs.setString('saved_password', _passwordCtrl.text);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_username');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      _showSnack(res['messages']?['error'] ?? 'Login gagal');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Definisi palet warna cerah & modern
    const Color primaryColor = Color(0xFF1B5E20); // Hijau utama identitas sekolah
    const Color inputBgColor = Color(0xFFF4F6F4);  // Abu-abu kehijauan sangat soft untuk field

    return Scaffold(
      backgroundColor: Colors.white, // Latar belakang putih bersih
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- AREA LOGO (CLEAN, NO BORDER, NO SHADOW) ---
                Image.asset(
                  'assets/logo.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                
                // --- JUDUL APLIKASI ---
                const Text(
                  'Absen MARSA',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'SMK Ma\'arif 9 Kebumen',
                  style: TextStyle(
                    color: Colors.black45,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),

                // --- FORM INPUT (MODERN CERAH) ---
                // Menggunakan TextField tanpa border kaku, melainkan diisi warna lembut (Filled)
                TextField(
                  controller: _loginCtrl,
                  decoration: InputDecoration(
                    labelText: 'Username / Email',
                    labelStyle: const TextStyle(color: Colors.black45),
                    prefixIcon: const Icon(Icons.person_outline, color: primaryColor),
                    filled: true,
                    fillColor: inputBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none, // Hilangkan border garis luar
                    ),
                    floatingLabelStyle: const TextStyle(color: primaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.black45),
                    prefixIcon: const Icon(Icons.lock_outline, color: primaryColor),
                    filled: true,
                    fillColor: inputBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    floatingLabelStyle: const TextStyle(color: primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.black45,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscure = !_obscure;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // --- REMEMBER ME (MINIMALIS) ---
                Theme(
                  data: ThemeData(unselectedWidgetColor: Colors.black38),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _rememberMe,
                    title: const Text(
                      'Ingat Username & Password',
                      style: TextStyle(fontSize: 14, color: Colors.black65),
                    ),
                    activeColor: primaryColor,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) {
                      setState(() {
                        _rememberMe = v ?? true;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // --- TOMBOL MASUK ELEGAN ---
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _doLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0, // Flat design modern
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
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
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}