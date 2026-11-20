import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../settings/setting_definitions.dart';
import '../utils/guarded_navigation.dart';

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
  bool _allowPop = false;
  late String _initialName;
  late String _initialPhone;

  bool get _dirty =>
      _nameCtrl.text != _initialName ||
      _phoneCtrl.text != _initialPhone ||
      _currentPasswordCtrl.text.isNotEmpty ||
      _passCtrl.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final session = ApiService().currentUser ?? widget.session ?? {};
    _nameCtrl.text =
        (session[SettingDefinitions.accountName.key] ?? session['name'] ?? '')
            .toString();
    _phoneCtrl.text =
        (session[SettingDefinitions.accountPhone.key] ?? '').toString();
    _initialName = _nameCtrl.text;
    _initialPhone = _phoneCtrl.text;
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
        SettingDefinitions.accountName.key: _nameCtrl.text.trim(),
        SettingDefinitions.accountPhone.key: _phoneCtrl.text.trim(),
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
        setState(() {
          _initialName = _nameCtrl.text;
          _initialPhone = _phoneCtrl.text;
          _currentPasswordCtrl.clear();
          _passCtrl.clear();
        });
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

  Future<void> _back() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_loading) return;
    if (!_dirty) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديلات غير محفوظة'),
        content: const Text('احفظ التعديلات أولاً أو تجاهلها للعودة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('متابعة التحرير'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تجاهل التعديلات'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
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
      ),
    );
  }
}

// ============================================================
// شاشات المدير (Admin Screens)
// ============================================================

// --- إدارة المستخدمين ---
