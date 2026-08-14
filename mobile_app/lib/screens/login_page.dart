import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'homepage_screen.dart';

/// شاشة تسجيل الدخول
class LoginPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onLoginSuccess;
  
  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('saved_user');
    final savedPass = prefs.getString('saved_pass');
    if (savedUser != null && savedPass != null) {
      _userCtrl.text = savedUser;
      _passCtrl.text = savedPass;
    }
  }

  void _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final username = _userCtrl.text.trim();
      final password = _passCtrl.text;
      
      final data = await ApiService().post({
        'action': 'login',
        'username': username,
        'password': password,
      });
      
      if (!mounted) return;

      // حفظ بيانات الدخول
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_user', username);
      await prefs.setString('saved_pass', password);
      
      Map<String, dynamic>? sessionData;
      final possibleKeys = ['session', 'user', 'data', 'result'];
      for (var key in possibleKeys) {
        if (data[key] is Map) {
          sessionData = Map<String, dynamic>.from(data[key]);
          break;
        }
      }

      if (sessionData == null && (data.containsKey('role') || data.containsKey('full_name'))) {
        sessionData = data;
      }

      if (sessionData == null) {
        sessionData = {
          'username': username,
          'role': data['role'] ?? 'customer',
          'full_name': data['full_name'] ?? username,
          'token': data['token'],
        };
      }

      widget.onLoginSuccess(sessionData!);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                    const Color(0xFF0F3460),
                  ]
                : [
                    const Color(0xFFF5F7FA),
                    const Color(0xFFE8F4F8),
                    Colors.white,
                  ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.white).withOpacity(isDark ? 0.1 : 0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: (isDark ? Colors.white : const Color(0xff00658f)).withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // الشعار
                          Image.asset(
                            'assets/app_icon.png',
                            width: 100,
                            height: 100,
                            errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.waves, size: 80, color: Color(0xff00658f)),
                          ),
                          const SizedBox(height: 16),
                          Text('أوركا أوردر', 
                            style: TextStyle(
                              fontSize: 28, 
                              fontWeight: FontWeight.bold, 
                              color: isDark ? Colors.white : const Color(0xff00658f),
                            ),
                          ),
                          Text('ORCA ORDER', 
                            style: TextStyle(
                              fontSize: 14, 
                              letterSpacing: 2, 
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextField(
                            controller: _userCtrl,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'اسم المستخدم',
                              prefixIcon: Icon(Icons.person_outline, color: isDark ? Colors.white70 : const Color(0xff00658f)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: Icon(Icons.lock_outline, color: isDark ? Colors.white70 : const Color(0xff00658f)),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                              onPressed: _loading ? null : _login,
                              child: _loading 
                                ? const CircularProgressIndicator(color: Colors.white) 
                                : const Text('دخول'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
