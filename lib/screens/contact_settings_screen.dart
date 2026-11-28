import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/public_app_content.dart';
import '../utils/permissions.dart';

class ContactSettingsScreen extends StatefulWidget {
  const ContactSettingsScreen({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  State<ContactSettingsScreen> createState() => _ContactSettingsScreenState();
}

class _ContactSettingsScreenState extends State<ContactSettingsScreen> {
  static const _fields = <(String, String, TextInputType)>[
    ('company_name', 'اسم الشركة', TextInputType.text),
    ('phone', 'رقم الاتصال الدولي (+... )', TextInputType.phone),
    ('whatsapp', 'رقم واتساب الدولي (+... )', TextInputType.phone),
    ('facebook', 'رابط فيسبوك HTTPS', TextInputType.url),
    ('telegram', 'رابط تيليجرام HTTPS', TextInputType.url),
    ('instagram', 'رابط إنستغرام HTTPS', TextInputType.url),
    ('email', 'البريد الإلكتروني', TextInputType.emailAddress),
    ('working_hours', 'ساعات العمل', TextInputType.text),
    ('address', 'العنوان', TextInputType.streetAddress),
    ('support_hours', 'ساعات الدعم', TextInputType.text),
    ('expected_response_time', 'زمن الرد المتوقع', TextInputType.text),
    ('extra_name', 'اسم قناة إضافية', TextInputType.text),
    ('extra_value', 'رابط أو قيمة القناة الإضافية', TextInputType.url),
  ];

  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _termsController = TextEditingController();
  final _privacyController = TextEditingController();
  final _faqController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isAdmin =>
      PermissionHelper.fromString(widget.session['role']?.toString() ?? '') ==
      AppRole.admin;

  @override
  void initState() {
    super.initState();
    for (final (key, _, _) in _fields) {
      _controllers[key] = TextEditingController();
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _termsController.dispose();
    _privacyController.dispose();
    _faqController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cached = await PublicAppContent.readCache();
      if (cached != null) _populate(cached);
    } catch (_) {
      // Continue with the authoritative server request.
    }
    try {
      final content = await PublicAppContent.refresh();
      if (!mounted) return;
      _populate(content);
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _populate(Map<String, dynamic> content) {
    final contact = _asMap(content['contact_info']);
    final legal = _asMap(content['legal_content']);
    for (final (key, _, _) in _fields) {
      _controllers[key]!.text = (contact[key] ?? '').toString();
    }
    _termsController.text = (legal['terms'] ?? '').toString();
    _privacyController.text = (legal['privacy_policy'] ?? '').toString();
    final faq = content['faq'];
    _faqController.text = const JsonEncoder.withIndent('  ')
        .convert(faq is List ? faq : const []);
  }

  Map<String, dynamic> _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  String? _validateField(String key, String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    if ((key == 'phone' || key == 'whatsapp') &&
        !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(text)) {
      return 'استخدم الصيغة الدولية مثل +963...';
    }
    if (key == 'email' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(text)) {
      return 'أدخل بريدًا إلكترونيًا صحيحًا';
    }
    if (const {'facebook', 'telegram', 'instagram'}.contains(key)) {
      final uri = Uri.tryParse(text);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        return 'أدخل رابط HTTPS صالحًا';
      }
      final hosts = {
        'facebook': {'facebook.com', 'www.facebook.com'},
        'telegram': {'t.me', 'www.t.me', 'telegram.me', 'www.telegram.me'},
        'instagram': {'instagram.com', 'www.instagram.com'},
      }[key]!;
      if (!hosts.contains(uri.host.toLowerCase())) {
        return 'استخدم رابط القناة المحددة';
      }
    }
    if (key == 'extra_value' && text.startsWith('http')) {
      final uri = Uri.tryParse(text);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        return 'الرابط يجب أن يستخدم HTTPS';
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (!_isAdmin) {
      _message('تعديل إعدادات التواصل متاح للمدير فقط.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    dynamic faq;
    try {
      faq = jsonDecode(_faqController.text.trim().isEmpty
          ? '[]'
          : _faqController.text.trim());
      if (faq is! List) throw const FormatException();
    } catch (_) {
      _message('الأسئلة الشائعة يجب أن تكون قائمة JSON من السؤال والجواب.');
      return;
    }
    setState(() => _saving = true);
    try {
      final contact = {
        for (final (key, _, _) in _fields) key: _controllers[key]!.text.trim(),
      };
      final settings = await PublicAppContent.save({
        'contact_info': contact,
        'legal_content': {
          'terms': _termsController.text.trim(),
          'privacy_policy': _privacyController.text.trim(),
        },
        'faq': faq,
      });
      if (!mounted) return;
      _populate(settings);
      _message('تم حفظ بيانات التواصل ومحتوى التطبيق.');
    } catch (error) {
      if (mounted) _message('تعذر حفظ الإعدادات: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _preview() async {
    final contact = {
      for (final (key, _, _) in _fields) key: _controllers[key]!.text.trim(),
    };
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معاينة بيانات التواصل'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (key, label, _) in _fields)
                  if ((contact[key] ?? '').isNotEmpty)
                    ListTile(
                      dense: true,
                      title: Text(label),
                      subtitle: Text(contact[key]!),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('بيانات التواصل')),
        body: const Center(child: Text('هذه الإعدادات متاحة للمدير فقط.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('بيانات التواصل ومحتوى التطبيق')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.cloud_off_outlined),
                        title: const Text('تعذر تحديث البيانات من الخادم'),
                        subtitle: Text(_error!),
                        trailing: IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                  const Text(
                    'اترك القناة فارغة لإخفائها. أرقام الهاتف يجب أن تكون دولية، وروابط التواصل HTTPS.',
                  ),
                  const SizedBox(height: 12),
                  for (final (key, label, keyboard) in _fields) ...[
                    TextFormField(
                      controller: _controllers[key],
                      keyboardType: keyboard,
                      enabled: !_saving,
                      maxLines: key == 'address' ? 2 : 1,
                      decoration: InputDecoration(
                        labelText: label,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) => _validateField(key, value ?? ''),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Divider(height: 28),
                  TextFormField(
                    controller: _termsController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: 8000,
                    decoration: const InputDecoration(
                      labelText: 'شروط الاستخدام',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _privacyController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: 8000,
                    decoration: const InputDecoration(
                      labelText: 'سياسة الخصوصية',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _faqController,
                    enabled: !_saving,
                    minLines: 4,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      labelText: 'الأسئلة الشائعة بصيغة JSON',
                      helperText:
                          '[{"question":"كيف أتابع طلبي؟","answer":"افتح صفحة طلباتي."}]',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _preview,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('معاينة التواصل'),
                      ),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('حفظ'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
