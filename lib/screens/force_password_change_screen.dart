import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ForcePasswordChangeScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const ForcePasswordChangeScreen({super.key, required this.onComplete});

  @override
  State<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nextPassword = _newPassword.text;
    if (nextPassword.length < 8 ||
        !RegExp('[A-Za-z]').hasMatch(nextPassword) ||
        !RegExp(r'\d').hasMatch(nextPassword)) {
      setState(() {
        _error = 'استخدم 8 محارف على الأقل مع حرف إنجليزي ورقم.';
      });
      return;
    }
    if (nextPassword != _confirmPassword.text) {
      setState(() => _error = 'تأكيد كلمة المرور غير مطابق.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService().auth.changePassword(_oldPassword.text, nextPassword);
      await ApiService().setSession(null);
      if (mounted) widget.onComplete();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _saving = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    setState(() => _saving = true);
    try {
      await ApiService().auth.logout();
    } catch (_) {
      await ApiService().setSession(null);
    }
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('تغيير كلمة المرور'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _logout,
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_reset, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'كلمة المرور مؤقتة. غيّرها قبل متابعة استخدام التطبيق.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _oldPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'كلمة المرور الحالية'),
                    ),
                    TextField(
                      controller: _newPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'كلمة المرور الجديدة'),
                    ),
                    TextField(
                      controller: _confirmPassword,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('تغيير كلمة المرور'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
