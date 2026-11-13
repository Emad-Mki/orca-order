import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? session;

  const ProfileScreen({super.key, this.session});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final session = ApiService().currentUser ?? widget.session ?? {};
    _nameCtrl.text = (session['full_name'] ?? session['name'] ?? '').toString();
    _phoneCtrl.text = (session['phone'] ?? '').toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await ApiService().post({
        'action': 'user_update',
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (_passCtrl.text.isNotEmpty) ...{
          'old_password': _currentPasswordCtrl.text,
          'new_password': _passCtrl.text,
        },
      });
      if (!mounted) return;
      final currentSession = ApiService().currentUser;
      if (currentSession != null && ApiService().token != null) {
        final updatedSession = Map<String, dynamic>.from(currentSession);
        if (_nameCtrl.text.trim().isNotEmpty) {
          updatedSession['full_name'] = _nameCtrl.text.trim();
          updatedSession['name'] = _nameCtrl.text.trim();
        }
        if (_phoneCtrl.text.trim().isNotEmpty) {
          updatedSession['phone'] = _phoneCtrl.text.trim();
        }
        await ApiService().setSession(
          ApiService().token,
          updatedSession,
        );
        if (!mounted) return;
        context
            .findAncestorStateOfType<OrcaAppState>()
            ?.updateSession(updatedSession);
      }
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'تم تحديث البيانات بنجاح'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'الاسم الكامل', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                  labelText: 'رقم الهاتف', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(
              controller: _currentPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'كلمة المرور الحالية (لتغيير كلمة المرور)',
                  border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'كلمة مرور جديدة (اختياري)',
                  border: OutlineInputBorder())),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _loading ? null : _updateProfile,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('حفظ التغييرات'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// شاشات المدير (Admin Screens)
// ============================================================

// --- إدارة المستخدمين ---
