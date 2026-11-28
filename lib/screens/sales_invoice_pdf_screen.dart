import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../app_config.dart';
import '../services/api_service.dart';
import '../services/invoice_pdf_archive.dart';
import '../services/invoice_product_images.dart';
import '../services/sales_invoice_pdf.dart';
import '../utils/permissions.dart';
import 'invoice_pdf_archive_screen.dart';

class SalesInvoicePdfScreen extends StatefulWidget {
  const SalesInvoicePdfScreen({super.key, required this.invoice});

  final Map<String, dynamic> invoice;

  @override
  State<SalesInvoicePdfScreen> createState() => _SalesInvoicePdfScreenState();
}

class _SalesInvoicePdfScreenState extends State<SalesInvoicePdfScreen> {
  late final Future<_GeneratedInvoice> _document = _generate();

  Future<_GeneratedInvoice> _generate() async {
    final api = ApiService();
    final user = api.currentUser;
    final token = api.token;
    final userId =
        (user?['user_id'] ?? user?['id'] ?? user?['customer_id'])?.toString() ??
            '';
    final role = user?['role']?.toString() ?? '';
    final invoiceId = widget.invoice['invoice_id']?.toString() ?? '';
    if (token == null || userId.isEmpty || role.isEmpty || invoiceId.isEmpty) {
      throw StateError('بيانات الحساب أو معرّف الفاتورة غير متوفرة للأرشفة');
    }
    final template = await api.invoiceTemplateStore.current();
    final environment = '${AppConfig.environmentName}:${AppConfig.apiUrl}';
    final roleName = PermissionHelper.fromString(role).name;
    final imageStore = InvoiceProductImages(
        scope: invoiceImageScope(environment, userId, roleName));
    final exportedAt = DateTime.now();
    final items = widget.invoice['items'];
    if (items is! List) throw StateError('بنود الفاتورة غير متوفرة');
    final invoiceForPdf = Map<String, dynamic>.from(widget.invoice);
    if (!const {'admin', 'manager', 'accountant'}.contains(roleName)) {
      invoiceForPdf.remove('accounting_invoice_no');
    }
    final codes = items
        .whereType<Map>()
        .map((item) => item['code']?.toString() ?? '')
        .where((code) => code.isNotEmpty);
    final images = await imageStore.read(invoiceId, codes);
    final bytes = await SalesInvoicePdf.build(invoiceForPdf,
        template: template.toMap(),
        logoBytes: template.logoBytes,
        productImages: images,
        exportedAt: exportedAt);
    if (api.token != token) {
      throw StateError('تغيرت جلسة المستخدم أثناء التصدير');
    }
    final archive = kIsWeb
        ? null
        : InvoicePdfArchive(
            environment: environment,
            userId: userId,
            role: role,
          );
    final version = SalesInvoicePdf.templateVersion;
    final fileName = SalesInvoicePdf.exportFileName(invoiceForPdf, exportedAt);
    if (archive != null) {
      await archive.save(
          bytes: bytes, invoiceId: invoiceId, templateVersion: version);
    }
    return _GeneratedInvoice(bytes, version, archive, invoiceId, fileName);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('معاينة فاتورة PDF')),
        body: FutureBuilder<_GeneratedInvoice>(
          future: _document,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Text('تعذر إنشاء الفاتورة: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final document = snapshot.data!;
            return Column(
              children: [
                if (document.archive != null)
                  ListTile(
                    dense: true,
                    title: Text('تم حفظ نسخة خاصة · قالب ${document.version}'),
                    trailing: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => InvoicePdfArchiveScreen(
                              archive: document.archive!,
                              invoiceId: document.invoiceId),
                        ),
                      ),
                      child: const Text('النسخ المؤرشفة'),
                    ),
                  ),
                Expanded(
                  child: PdfPreview(
                    build: (_) async => document.bytes,
                    initialPageFormat: PdfPageFormat.a4,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    pdfFileName: document.fileName,
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _GeneratedInvoice {
  const _GeneratedInvoice(
      this.bytes, this.version, this.archive, this.invoiceId, this.fileName);
  final Uint8List bytes;
  final String version;
  final InvoicePdfArchive? archive;
  final String invoiceId;
  final String fileName;
}
