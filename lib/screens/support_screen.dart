import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/api_service.dart';
import '../services/public_app_content.dart';
import '../utils/permissions.dart';
import 'contact_screen.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _descriptionController = TextEditingController();
  final _faqSearchController = TextEditingController();
  String _ticketType = 'bug';
  bool _includeDiagnostics = false;
  bool _sending = false;
  bool _loadingTickets = true;
  bool _loadingContent = true;
  String? _ticketError;
  String? _contentError;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _faq = [];
  Map<String, dynamic> _contact = {};
  Uint8List? _attachment;
  String? _attachmentName;

  bool get _isAdmin =>
      PermissionHelper.fromString(widget.session['role']?.toString() ?? '') ==
      AppRole.admin;

  @override
  void initState() {
    super.initState();
    unawaited(_loadContent());
    unawaited(_loadTickets());
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _faqSearchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  List<Map<String, dynamic>> _asMapList(Object? value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : [];

  Future<void> _loadContent() async {
    try {
      final cached = await PublicAppContent.readCache();
      if (cached != null && mounted) {
        setState(() {
          _contact = _asMap(cached['contact_info']);
          _faq = _asMapList(cached['faq']);
          _loadingContent = false;
        });
      }
    } catch (_) {
      // The server remains the source of truth when the local cache is invalid.
    }
    try {
      final content = await PublicAppContent.refresh();
      if (!mounted) return;
      setState(() {
        _contact = _asMap(content['contact_info']);
        _faq = _asMapList(content['faq']);
        _contentError = null;
        _loadingContent = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _contentError = error.toString();
        _loadingContent = false;
      });
    }
  }

  Future<void> _loadTickets() async {
    try {
      final response = await ApiService().post({
        'action':
            _isAdmin ? 'support_ticket_admin_list' : 'support_ticket_list',
      });
      if (!mounted) return;
      setState(() {
        _tickets = _asMapList(response['tickets']);
        _ticketError = null;
        _loadingTickets = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ticketError = error.toString();
        _loadingTickets = false;
      });
    }
  }

  Future<void> _chooseScreenshot() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 55,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 30000) {
        _message('حجم الصورة بعد الضغط أكبر من 30 كيلوبايت؛ اختر صورة أصغر.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _attachment = bytes;
        _attachmentName = file.name;
      });
    } catch (error) {
      if (mounted) _message('تعذر اختيار الصورة: $error');
    }
  }

  Future<Map<String, dynamic>> _diagnostics() async {
    final package = await PackageInfo.fromPlatform();
    final device = kIsWeb
        ? 'Web'
        : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    return {
      'app_version': package.version,
      'build_number': package.buildNumber,
      'device': device,
      'user_id':
          widget.session['user_id'] ?? widget.session['customer_id'] ?? '',
    };
  }

  Future<void> _submitTicket() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _message('اكتب وصفًا للمشكلة قبل الإرسال.');
      return;
    }
    if (description.length > 3000) {
      _message('يجب ألا يتجاوز وصف البلاغ 3000 محرف.');
      return;
    }
    setState(() => _sending = true);
    try {
      final response = await ApiService().post({
        'action': 'support_ticket_create',
        'type': _ticketType,
        'description': description,
        'attach_diagnostics': _includeDiagnostics,
        if (_includeDiagnostics) 'diagnostics': await _diagnostics(),
        if (_attachment != null)
          'attachment_base64': base64Encode(_attachment!),
      });
      if (!mounted) return;
      _descriptionController.clear();
      setState(() {
        _attachment = null;
        _attachmentName = null;
        _includeDiagnostics = false;
      });
      _message('تم إرسال البلاغ ${response['ticket_id'] ?? ''}.');
      await _loadTickets();
    } catch (error) {
      if (mounted) _message('تعذر إرسال البلاغ: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _updateTicket(
    String ticketId,
    String status,
    String response,
  ) async {
    try {
      await ApiService().post({
        'action': 'support_ticket_update',
        'ticket_id': ticketId,
        'status': status,
        'response': response,
      });
      if (!mounted) return;
      _message('تم تحديث البلاغ.');
      await _loadTickets();
    } catch (error) {
      if (mounted) _message('تعذر تحديث البلاغ: $error');
    }
  }

  String _ticketTypeLabel(String value) => switch (value) {
        'account' => 'الحساب',
        'order' => 'الطلبات',
        'payment' => 'المدفوعات',
        'suggestion' => 'اقتراح',
        'other' => 'أخرى',
        _ => 'مشكلة تقنية',
      };

  String _statusLabel(String value) => switch (value) {
        'in_progress' => 'قيد المعالجة',
        'resolved' => 'محلول',
        _ => 'مفتوح',
      };

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final query = _faqSearchController.text.trim().toLowerCase();
    final visibleFaq = _faq.where((item) {
      final text = '${item['question'] ?? ''} ${item['answer'] ?? ''}';
      return text.toLowerCase().contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدعم'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              _loadContent();
              _loadTickets();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadContent(), _loadTickets()]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.support_agent)),
                title: const Text('اتصل بنا'),
                subtitle: Text(
                  _contact['support_hours']?.toString().trim().isNotEmpty ==
                          true
                      ? 'ساعات الدعم: ${_contact['support_hours']}'
                      : 'اختر قناة التواصل المتاحة',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactScreen()),
                ),
              ),
            ),
            if (_contact['expected_response_time']
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'زمن الرد المتوقع: ${_contact['expected_response_time']}',
                ),
              ),
            if (_contentError != null)
              Text(
                _loadingContent
                    ? 'جارٍ مزامنة معلومات الدعم…'
                    : 'تعذر تحديث معلومات الدعم؛ قد تظهر بيانات محفوظة على الجهاز.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            _sectionTitle('أبلغ عن مشكلة'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _ticketType,
                      decoration: const InputDecoration(
                        labelText: 'نوع البلاغ',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'bug', child: Text('مشكلة تقنية')),
                        DropdownMenuItem(
                            value: 'account', child: Text('الحساب')),
                        DropdownMenuItem(
                            value: 'order', child: Text('الطلبات')),
                        DropdownMenuItem(
                            value: 'payment', child: Text('المدفوعات')),
                        DropdownMenuItem(
                            value: 'suggestion', child: Text('اقتراح ميزة')),
                        DropdownMenuItem(value: 'other', child: Text('أخرى')),
                      ],
                      onChanged: _sending
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _ticketType = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 7,
                      maxLength: 3000,
                      enabled: !_sending,
                      decoration: const InputDecoration(
                        labelText: 'وصف المشكلة أو الاقتراح',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_attachment != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _attachment!,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _sending
                            ? null
                            : () => setState(() {
                                  _attachment = null;
                                  _attachmentName = null;
                                }),
                        icon: const Icon(Icons.delete_outline),
                        label: Text('إزالة ${_attachmentName ?? 'الصورة'}'),
                      ),
                    ],
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _includeDiagnostics,
                      onChanged: _sending
                          ? null
                          : (value) => setState(
                                () => _includeDiagnostics = value ?? false,
                              ),
                      title: const Text('إرفاق معلومات تشخيصية'),
                      subtitle: const Text(
                        'نسخة التطبيق ونظام الجهاز ورقم الحساب فقط؛ لا تُرفق كلمات مرور.',
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        onPressed: _sending ? null : _chooseScreenshot,
                        icon: const Icon(Icons.image_outlined),
                        label: const Text(
                            'إرفاق لقطة شاشة اختيارية (30 كيلوبايت كحد أقصى)'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _sending ? null : _submitTicket,
                        icon: _sending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_outlined),
                        label: const Text('إرسال البلاغ'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'سيظهر رقم البلاغ وحالته هنا. لا يُضمن الرد الفوري؛ راجع ساعات الدعم أعلاه.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            _sectionTitle(_isAdmin ? 'بلاغات المستخدمين' : 'بلاغاتي'),
            if (_loadingTickets)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_ticketError != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off_outlined),
                  title: const Text('تعذر تحميل البلاغات'),
                  subtitle: Text(_ticketError!),
                  trailing: IconButton(
                    onPressed: _loadTickets,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              )
            else if (_tickets.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('لا توجد بلاغات بعد.'),
                ),
              )
            else
              for (final ticket in _tickets)
                _isAdmin
                    ? _AdminTicketCard(
                        key: ValueKey(ticket['ticket_id']),
                        ticket: ticket,
                        onSave: _updateTicket,
                      )
                    : _userTicketCard(ticket),
            _sectionTitle('الأسئلة الشائعة'),
            TextField(
              controller: _faqSearchController,
              decoration: InputDecoration(
                labelText: 'ابحث في الأسئلة',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () {
                    _faqSearchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (_faq.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _contentError != null
                        ? 'الأسئلة الشائعة غير متاحة دون اتصال.'
                        : 'ستظهر الأسئلة الشائعة هنا عند إضافتها من إعدادات التطبيق.',
                  ),
                ),
              )
            else if (visibleFaq.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد نتائج مطابقة.'),
              )
            else
              for (final item in visibleFaq)
                Card(
                  child: ExpansionTile(
                    title: Text(item['question']?.toString() ?? ''),
                    childrenPadding:
                        const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(item['answer']?.toString() ?? ''),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 18, 4, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _userTicketCard(Map<String, dynamic> ticket) {
    final status = ticket['status']?.toString() ?? 'open';
    final response = ticket['response']?.toString().trim() ?? '';
    return Card(
      child: ExpansionTile(
        leading: Icon(
          status == 'resolved'
              ? Icons.check_circle_outline
              : status == 'in_progress'
                  ? Icons.pending_outlined
                  : Icons.mark_email_unread_outlined,
        ),
        title:
            Text('${ticket['ticket_id'] ?? 'بلاغ'} · ${_statusLabel(status)}'),
        subtitle: Text(_ticketTypeLabel(ticket['type']?.toString() ?? '')),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(ticket['description']?.toString() ?? ''),
          ),
          if (response.isNotEmpty) ...[
            const Divider(),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('رد الدعم: $response'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminTicketCard extends StatefulWidget {
  const _AdminTicketCard({
    super.key,
    required this.ticket,
    required this.onSave,
  });

  final Map<String, dynamic> ticket;
  final Future<void> Function(String id, String status, String response) onSave;

  @override
  State<_AdminTicketCard> createState() => _AdminTicketCardState();
}

class _AdminTicketCardState extends State<_AdminTicketCard> {
  late final TextEditingController _responseController;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.ticket['status']?.toString() ?? 'open';
    _responseController = TextEditingController(
        text: widget.ticket['response']?.toString() ?? '');
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  String _statusLabel(String status) => switch (status) {
        'in_progress' => 'قيد المعالجة',
        'resolved' => 'محلول',
        _ => 'مفتوح',
      };

  @override
  Widget build(BuildContext context) {
    final ticketId = widget.ticket['ticket_id']?.toString() ?? '';
    final attachment = widget.ticket['attachment_base64']?.toString() ?? '';
    return Card(
      child: ExpansionTile(
        title: Text('$ticketId · ${_statusLabel(_status)}'),
        subtitle: Text(
          '${widget.ticket['username'] ?? 'حساب'} · ${widget.ticket['type'] ?? ''}',
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(widget.ticket['description']?.toString() ?? ''),
          ),
          if (attachment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Image.memory(
                base64Decode(attachment),
                height: 180,
                errorBuilder: (_, __, ___) => const Text('تعذر عرض المرفق'),
              ),
            ),
          TextField(
            controller: _responseController,
            maxLength: 2000,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'رد للمستخدم',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue:
                const {'open', 'in_progress', 'resolved'}.contains(_status)
                    ? _status
                    : 'open',
            decoration: const InputDecoration(
              labelText: 'حالة البلاغ',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'open', child: Text('مفتوح')),
              DropdownMenuItem(
                  value: 'in_progress', child: Text('قيد المعالجة')),
              DropdownMenuItem(value: 'resolved', child: Text('محلول')),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _status = value);
                  },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      await widget.onSave(
                        ticketId,
                        _status,
                        _responseController.text.trim(),
                      );
                      if (mounted) setState(() => _saving = false);
                    },
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ التحديث'),
            ),
          ),
        ],
      ),
    );
  }
}
