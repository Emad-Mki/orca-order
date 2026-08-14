import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
    _nameCtrl.text = session?['full_name'] ?? '';
    // الهاتف قد لا يكون في الجلسة، يمكن جلبه من API أو إضافته للجلسة مستقبلاً
  }

  void _updateProfile() async {
    setState(() => _loading = true);
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      await ApiService().post({
        'action': 'updateUser',
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (_passCtrl.text.isNotEmpty) 'new_password': _passCtrl.text,
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح')));
        // تحديث الجلسة محلياً قد يتطلب إعادة تسجيل دخول أو آلية تحديث State
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
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
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة مرور جديدة (اختياري)', border: OutlineInputBorder())),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _loading ? null : _updateProfile,
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ التغييرات'),
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
