import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/api_service.dart';

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
  }

  void _login() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final username = _userCtrl.text.trim();
      final password = _passCtrl.text;

      final data = await ApiService().auth.login(username, password);

      if (!mounted) return;

      Map<String, dynamic>? sessionData = data['session'];

      if (sessionData == null) {
        throw Exception('فشل في استلام بيانات الجلسة');
      }

      widget.onLoginSuccess(sessionData);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colors.surface,
                    colors.surfaceContainerLow,
                    colors.surfaceContainerHighest,
                  ]
                : [
                    colors.surface,
                    colors.surfaceContainerLow,
                    colors.surface,
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
                      color: colors.surface
                          .withValues(alpha: isDark ? 0.82 : 0.72),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.7),
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
                                Icon(Icons.waves,
                                    size: 80, color: colors.primary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'أوركا أوردر',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                          Text(
                            'ORCA ORDER',
                            style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 2,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextField(
                            controller: _userCtrl,
                            style: TextStyle(color: colors.onSurface),
                            decoration: InputDecoration(
                              labelText: 'اسم المستخدم',
                              prefixIcon: Icon(Icons.person_outline,
                                  color: colors.primary),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            style: TextStyle(color: colors.onSurface),
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: Icon(Icons.lock_outline,
                                  color: colors.primary),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: colors.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                              onPressed: _loading ? null : _login,
                              child: _loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
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
