import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../settings/setting_definitions.dart';
import '../utils/guarded_navigation.dart';
import '../utils/permissions.dart';

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
  final _confirmPasswordCtrl = TextEditingController();
  bool _loading = false;
  bool _allowPop = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  late String _initialName;
  late String _initialPhone;

  bool get _dirty =>
      _nameCtrl.text != _initialName ||
      _phoneCtrl.text != _initialPhone ||
      _currentPasswordCtrl.text.isNotEmpty ||
      _passCtrl.text.isNotEmpty ||
      _confirmPasswordCtrl.text.isNotEmpty;

  Map<String, dynamic> get _session =>
      ApiService().currentUser ?? widget.session ?? {};

  bool get _canEditName => const {
        AppRole.admin,
        AppRole.manager,
        AppRole.accountant,
      }.contains(
        PermissionHelper.fromString(_session['role']?.toString() ?? ''),
      );

  int get _passwordStrength {
    final value = _passCtrl.text;
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }

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
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final changingPassword = _passCtrl.text.isNotEmpty ||
        _currentPasswordCtrl.text.isNotEmpty ||
        _confirmPasswordCtrl.text.isNotEmpty;
    if (changingPassword) {
      if (_currentPasswordCtrl.text.isEmpty ||
          _passCtrl.text.isEmpty ||
          _confirmPasswordCtrl.text.isEmpty) {
        _showMessage('أدخل كلمة المرور الحالية والجديدة وتأكيدها.');
        return;
      }
      if (_passCtrl.text != _confirmPasswordCtrl.text) {
        _showMessage('تأكيد كلمة المرور الجديدة غير مطابق.');
        return;
      }
      if (_passCtrl.text.length < 10 ||
          !RegExp(r'[A-Za-z]').hasMatch(_passCtrl.text) ||
          !RegExp(r'\d').hasMatch(_passCtrl.text) ||
          _passCtrl.text == _currentPasswordCtrl.text ||
          RegExp(
            r'^(password|password123|1234567890|qwerty123|admin123|welcome1)$',
            caseSensitive: false,
          ).hasMatch(_passCtrl.text)) {
        _showMessage(
          'استخدم 10 محارف على الأقل، مع أحرف وأرقام، واختر كلمة مختلفة عن الحالية وغير شائعة.',
        );
        return;
      }
    }
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await ApiService().post({
        'action': 'user_update',
        if (_canEditName && _nameCtrl.text.trim() != _initialName)
          SettingDefinitions.accountName.key: _nameCtrl.text.trim(),
        if (_phoneCtrl.text.trim() != _initialPhone.trim())
          SettingDefinitions.accountPhone.key: _phoneCtrl.text.trim(),
        if (changingPassword) ...{
          'old_password': _currentPasswordCtrl.text,
          'new_password': _passCtrl.text,
        },
      });
      if (!mounted) return;
      final currentSession = ApiService().currentUser;
      if (currentSession != null && ApiService().token != null) {
        final updatedSession = Map<String, dynamic>.from(currentSession);
        if (_canEditName &&
            _nameCtrl.text.trim().isNotEmpty &&
            _nameCtrl.text.trim() != _initialName) {
          updatedSession['full_name'] = _nameCtrl.text.trim();
          updatedSession['name'] = _nameCtrl.text.trim();
        }
        if (_phoneCtrl.text.trim() != _initialPhone.trim()) {
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
          _confirmPasswordCtrl.clear();
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الحساب',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      readOnly: !_canEditName,
                      decoration: InputDecoration(
                        labelText: 'الاسم الكامل',
                        border: const OutlineInputBorder(),
                        helperText: _canEditName
                            ? 'متاح للتعديل للحسابات المخولة'
                            : 'للتعديل، راجع المدير أو المحاسب',
                        suffixIcon: Icon(
                          _canEditName
                              ? Icons.edit_outlined
                              : Icons.lock_outline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _readOnlyDetail('الدور', _roleLabel(_session['role'])),
                    _readOnlyDetail(
                      'رقم الحساب',
                      (_session['user_id'] ?? _session['customer_id'] ?? '—')
                          .toString(),
                    ),
                    if ((_session['last_login'] ?? '').toString().isNotEmpty)
                      _readOnlyDetail(
                        'آخر تسجيل دخول',
                        _formatDate(_session['last_login']),
                      ),
                    if ((_session['groups'] ??
                            _session['group'] ??
                            _session['customer_type'] ??
                            '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      _readOnlyDetail(
                        'الفئة / المجموعة',
                        (_session['groups'] ??
                                _session['group'] ??
                                _session['customer_type'])
                            .toString(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الأمان',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    const Text('استخدم كلمة مرور فريدة لا تقل عن 10 محارف.'),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _currentPasswordCtrl,
                      obscureText: !_showCurrentPassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الحالية',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _showCurrentPassword ? 'إخفاء' : 'إظهار',
                          onPressed: () => setState(
                            () => _showCurrentPassword = !_showCurrentPassword,
                          ),
                          icon: Icon(_showCurrentPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: !_showNewPassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _showNewPassword ? 'إخفاء' : 'إظهار',
                          onPressed: () => setState(
                              () => _showNewPassword = !_showNewPassword),
                          icon: Icon(_showNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    _buildStrengthIndicator(),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordCtrl,
                      obscureText: !_showConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور الجديدة',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _showConfirmPassword ? 'إخفاء' : 'إظهار',
                          onPressed: () => setState(
                            () => _showConfirmPassword = !_showConfirmPassword,
                          ),
                          icon: Icon(_showConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _loading || !_dirty ? null : _updateProfile,
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

  Widget _readOnlyDetail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(width: 128, child: Text(label)),
            Expanded(child: Text(value, textAlign: TextAlign.end)),
          ],
        ),
      );

  Widget _buildStrengthIndicator() {
    final strength = _passwordStrength;
    final labels = ['أدخل كلمة مرور', 'ضعيفة', 'مقبولة', 'جيدة', 'قوية'];
    final colors = [
      Theme.of(context).colorScheme.outline,
      Colors.red,
      Colors.orange,
      Colors.lightGreen,
      Colors.green,
    ];
    return Semantics(
      label: 'قوة كلمة المرور: ${labels[strength]}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: strength / 4,
            color: colors[strength],
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 4),
          Text(labels[strength], style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  String _roleLabel(Object? role) =>
      switch (PermissionHelper.fromString(role?.toString() ?? '')) {
        AppRole.admin => 'مدير',
        AppRole.manager => 'مدير فرع',
        AppRole.accountant => 'محاسب',
        AppRole.warehouse => 'مستودع',
        AppRole.salesperson => 'مندوب مبيعات',
        AppRole.customer => 'زبون',
        _ => role?.toString() ?? '—',
      };

  String _formatDate(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return value.toString();
    final local = parsed.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// شاشات المدير (Admin Screens)
// ============================================================

// --- إدارة المستخدمين ---
