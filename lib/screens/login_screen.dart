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
      SnackBar(content: Text(msg)),
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2E7D32),
              Color(0xFF1B5E20),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 20,
                          color: Colors.black26,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Absen MARSA',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'SMK Ma\'arif 9 Kebumen',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 40),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextField(
                            controller: _loginCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Username / Email',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscure = !_obscure;
                                  });
                                },
                              ),
                            ),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _rememberMe,
                            title: const Text(
                              'Ingat Username & Password',
                              style: TextStyle(fontSize: 14),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) {
                              setState(() {
                                _rememberMe = v ?? true;
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _doLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'MASUK',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
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