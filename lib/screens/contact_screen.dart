import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/public_app_content.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  Map<String, dynamic> _contact = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final cached = await PublicAppContent.readCache();
      if (cached != null && mounted) {
        setState(() {
          _contact = _asMap(cached['contact_info']);
          _loading = false;
        });
      }
    } catch (_) {
      // A damaged local cache should not prevent a server refresh.
    }
    try {
      final content = await PublicAppContent.refresh();
      if (!mounted) return;
      setState(() {
        _contact = _asMap(content['contact_info']);
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

  Map<String, dynamic> _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  String _value(String key) => (_contact[key] ?? '').toString().trim();

  Future<void> _open(String label, Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _message('تعذر فتح $label. تحقق من تثبيت التطبيق أو صحة البيانات.');
      }
    } catch (error) {
      if (mounted) _message('تعذر فتح $label: $error');
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _message('تم نسخ البيانات');
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final company = _value('company_name');
    final cards = <Widget>[
      if (_value('phone').isNotEmpty)
        _channel(
          icon: Icons.phone_outlined,
          title: 'اتصال هاتفي',
          value: _value('phone'),
          onTap: () =>
              _open('تطبيق الاتصال', Uri(scheme: 'tel', path: _value('phone'))),
        ),
      if (_value('whatsapp').isNotEmpty)
        _channel(
          icon: Icons.chat_outlined,
          title: 'واتساب',
          value: _value('whatsapp'),
          onTap: () {
            final number = _value('whatsapp').replaceAll(RegExp(r'\D'), '');
            final uri = Uri.https('wa.me', '/$number', {
              'text': 'مرحبًا، أتواصل معكم من تطبيق أوركا أوردر.',
            });
            _open('واتساب', uri);
          },
        ),
      if (_value('facebook').isNotEmpty)
        _channel(
          icon: Icons.facebook,
          title: 'فيسبوك',
          value: _value('facebook'),
          onTap: () => _open('فيسبوك', Uri.parse(_value('facebook'))),
        ),
      if (_value('telegram').isNotEmpty)
        _channel(
          icon: Icons.send_outlined,
          title: 'تيليجرام',
          value: _value('telegram'),
          onTap: () => _open('تيليجرام', Uri.parse(_value('telegram'))),
        ),
      if (_value('instagram').isNotEmpty)
        _channel(
          icon: Icons.camera_alt_outlined,
          title: 'إنستغرام',
          value: _value('instagram'),
          onTap: () => _open('إنستغرام', Uri.parse(_value('instagram'))),
        ),
      if (_value('email').isNotEmpty)
        _channel(
          icon: Icons.email_outlined,
          title: 'البريد الإلكتروني',
          value: _value('email'),
          onTap: () => _open(
              'تطبيق البريد', Uri(scheme: 'mailto', path: _value('email'))),
        ),
      if (_value('extra_name').isNotEmpty && _value('extra_value').isNotEmpty)
        _channel(
          icon: Icons.link,
          title: _value('extra_name'),
          value: _value('extra_value'),
          onTap: () {
            final value = _value('extra_value');
            final uri = Uri.tryParse(value);
            if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
              _open(_value('extra_name'), uri);
            } else {
              _copy(value);
            }
          },
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('التواصل')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (company.isNotEmpty) ...[
              Text(company, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
            ],
            if (_loading && cards.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (cards.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error == null
                        ? 'لم تُضف بيانات التواصل بعد.'
                        : 'تعذر تحميل بيانات التواصل. اسحب للأسفل للمحاولة مجددًا.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...cards,
            if (_error != null && cards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'تعذر تحديث البيانات؛ المعروض هو آخر إصدار محفوظ.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_value('working_hours').isNotEmpty)
              _infoCard(Icons.schedule, 'ساعات العمل', _value('working_hours')),
            if (_value('address').isNotEmpty)
              _infoCard(
                  Icons.location_on_outlined, 'العنوان', _value('address')),
          ],
        ),
      ),
    );
  }

  Widget _channel({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          tooltip: 'نسخ',
          onPressed: () => _copy(value),
          icon: const Icon(Icons.copy_outlined),
        ),
        onTap: onTap,
        onLongPress: () => _copy(value),
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String value) => Card(
        margin: const EdgeInsets.only(top: 8),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(value),
          onLongPress: () => _copy(value),
        ),
      );
}
