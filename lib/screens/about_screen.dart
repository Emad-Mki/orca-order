import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';
import '../services/app_update_service.dart';
import '../services/public_app_content.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.session});

  final Map<String, dynamic>? session;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final _updates = AppUpdateService();
  PackageInfo? _packageInfo;
  Map<String, dynamic> _legalContent = {};
  String? _contentLastUpdated;
  bool _checkingUpdates = false;
  bool _copyingDiagnostics = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_updates.initialize());
  }

  @override
  void dispose() {
    _updates.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final cached = await PublicAppContent.readCache();
      if (mounted) {
        setState(() {
          _packageInfo = package;
          final legal = cached?['legal_content'];
          _legalContent = legal is Map ? Map<String, dynamic>.from(legal) : {};
          _contentLastUpdated = cached?['last_updated']?.toString();
        });
      }
      final content = await PublicAppContent.refresh();
      if (!mounted) return;
      final legal = content['legal_content'];
      setState(() {
        _legalContent = legal is Map ? Map<String, dynamic>.from(legal) : {};
        _contentLastUpdated = content['last_updated']?.toString();
      });
    } catch (_) {
      if (_packageInfo == null) {
        try {
          final package = await PackageInfo.fromPlatform();
          if (mounted) setState(() => _packageInfo = package);
        } catch (error) {
          debugPrint('Unable to read app version: $error');
        }
      }
    }
  }

  String get _terms => _legalContent['terms']?.toString().trim().isNotEmpty ==
          true
      ? _legalContent['terms'].toString()
      : 'يُستخدم تطبيق أوركا أوردر لإدارة الطلبات والتواصل التجاري مع شركة أوركا. '
          'يتحمل صاحب الحساب مسؤولية حماية بيانات الدخول ودقة المعلومات التي يرسلها. '
          'تخضع الأسعار والتوفر والتسليم للتأكيد عند معالجة الطلب، ولا يُعد عرض المنتج '
          'تأكيدًا نهائيًا للكمية أو السعر. يجب استخدام التطبيق بصورة نظامية وعدم إساءة '
          'استخدام الحساب أو الخدمة. يمكن تعديل هذه المسودة من إعدادات التطبيق.';

  String get _privacy => _legalContent['privacy_policy']
              ?.toString()
              .trim()
              .isNotEmpty ==
          true
      ? _legalContent['privacy_policy'].toString()
      : 'يعالج التطبيق بيانات الحساب والتواصل والطلبات اللازمة لتقديم الخدمة وإدارة '
          'المعاملات. لا تُرفق معلومات تشخيص الجهاز ببلاغ الدعم إلا بعد موافقتك، '
          'وتُستخدم لمعالجة البلاغ. تجنب تضمين كلمات المرور أو بيانات الدفع الحساسة '
          'في البلاغات. تُدار البيانات وفق إعدادات الشركة والمتطلبات النظامية ذات الصلة. '
          'يمكن للمدير تخصيص هذا النص من إعدادات التطبيق.';

  Future<void> _showLegal(String title, String text) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(child: SelectableText(text)),
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

  Future<void> _checkUpdates({required bool showNotes}) async {
    setState(() => _checkingUpdates = true);
    try {
      await _updates.initialize();
      await _updates.checkForUpdates(manual: true);
      if (!mounted) return;
      final update = _updates.manifest;
      if (update == null) {
        _message(
          _updates.errorMessage ??
              (_updates.status == AppUpdateStatus.noUpdate
                  ? 'التطبيق محدّث إلى آخر إصدار.'
                  : 'تعذر التحقق من التحديثات حاليًا.'),
        );
        return;
      }
      if (showNotes) {
        await _showLegal(
            'ما الجديد في ${update.versionName}', update.releaseNotes);
      } else {
        _message(
          update.buildNumber > _updates.installedBuildNumber
              ? 'يتوفر إصدار ${update.versionName} (بناء ${update.buildNumber}).'
              : 'التطبيق محدّث إلى آخر إصدار.',
        );
      }
    } catch (error) {
      if (mounted) _message('تعذر التحقق من التحديثات: $error');
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  Future<void> _copyDiagnostics() async {
    setState(() => _copyingDiagnostics = true);
    try {
      final info = _packageInfo ?? await PackageInfo.fromPlatform();
      final device = kIsWeb
          ? 'Web'
          : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      final diagnostics = {
        'app': 'Orca Order',
        'version': info.version,
        'build': info.buildNumber,
        'device': device,
        'account_id': widget.session?['user_id'] ??
            widget.session?['customer_id'] ??
            'غير متاح',
      };
      await Clipboard.setData(
        ClipboardData(
            text: const JsonEncoder.withIndent('  ').convert(diagnostics)),
      );
      if (mounted) _message('تم نسخ معلومات التشخيص غير الحساسة.');
    } catch (error) {
      if (mounted) _message('تعذر نسخ معلومات التشخيص: $error');
    } finally {
      if (mounted) setState(() => _copyingDiagnostics = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final info = _packageInfo;
    final version = info == null
        ? 'جارٍ التحميل…'
        : '${info.version} (${info.buildNumber})';
    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 72,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.shopping_bag_outlined, size: 64),
                  ),
                  const SizedBox(height: 12),
                  Text('أوركا أوردر',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text('الإصدار $version'),
                  const SizedBox(height: 14),
                  Text(
                    'أوركا أوردر تطبيق تابع لشركة أوركا محدودة المسؤولية '
                    '(Orca L.L.C)، المتخصصة في بيع قطع غيار الشاحنات وتوابعها. '
                    'تعمل الشركة في السوق منذ عام 1980، وهي الوكيل الحصري لشركة '
                    'Ci Car India International الهندية في سوريا.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.business_outlined),
                  title: Text('الشركة'),
                  subtitle: Text('Orca L.L.C · سوريا'),
                ),
                const ListTile(
                  leading: Icon(Icons.code),
                  title: Text('المطوّر'),
                  subtitle: Text('Emad Makki'),
                ),
                const ListTile(
                  leading: Icon(Icons.copyright),
                  title: Text('حقوق النشر'),
                  subtitle: Text('جميع الحقوق محفوظة للمطوّر'),
                ),
              ],
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('شروط الاستخدام'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLegal('شروط الاستخدام', _terms),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('سياسة الخصوصية'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLegal('سياسة الخصوصية', _privacy),
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('التراخيص مفتوحة المصدر'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'أوركا أوردر',
                    applicationVersion: version,
                    applicationIcon:
                        Image.asset('assets/images/logo.png', width: 48),
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.new_releases_outlined),
                  title: const Text('ما الجديد'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _checkingUpdates
                      ? null
                      : () => _checkUpdates(showNotes: true),
                ),
                ListTile(
                  leading: const Icon(Icons.system_update_alt),
                  title: const Text('التحقق من التحديثات'),
                  trailing: _checkingUpdates
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _checkingUpdates
                      ? null
                      : () => _checkUpdates(showNotes: false),
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('سجل الإصدارات'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://github.com/Emad-Mki/orca-order-updates/releases',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.content_copy_outlined),
              title: const Text('معلومات التشخيص للدعم الفني'),
              subtitle: const Text('نسخة التطبيق والجهاز ورقم الحساب فقط'),
              trailing: _copyingDiagnostics
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.copy),
              onTap: _copyingDiagnostics ? null : _copyDiagnostics,
            ),
          ),
          if (info != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${AppConfig.companyName} · ${info.packageName}'
                '${_contentLastUpdated?.isNotEmpty == true ? '\nآخر تحديث لمعلومات التطبيق: ${_formatDate(_contentLastUpdated!)}' : ''}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }
}
