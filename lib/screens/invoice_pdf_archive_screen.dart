import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:printing/printing.dart';

import '../services/invoice_pdf_archive.dart';

class InvoicePdfArchiveScreen extends StatelessWidget {
  const InvoicePdfArchiveScreen({
    super.key,
    required this.archive,
    required this.invoiceId,
  });

  final InvoicePdfArchive archive;
  final String invoiceId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('نسخ الفاتورة المؤرشفة')),
        body: FutureBuilder(
          future: archive.list(invoiceId: invoiceId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('تعذر فتح الأرشيف: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final files = snapshot.data!;
            if (files.isEmpty) {
              return const Center(child: Text('لا توجد نسخ مؤرشفة'));
            }
            return ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final parts =
                    path.basenameWithoutExtension(file.path).split('_');
                final micros = parts.length > 1 ? int.tryParse(parts[1]) : null;
                final date = micros == null
                    ? ''
                    : DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true)
                        .toLocal()
                        .toString();
                final version = parts.length > 2
                    ? parts.sublist(2, parts.length - 1).join('_')
                    : '';
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text('قالب $version'),
                  subtitle: Text(date),
                  trailing: const Icon(Icons.share),
                  onTap: () async {
                    try {
                      await Printing.sharePdf(
                        bytes: await file.readAsBytes(),
                        filename: 'invoice-$version.pdf',
                      );
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('تعذرت مشاركة النسخة: $error')),
                        );
                      }
                    }
                  },
                );
              },
            );
          },
        ),
      );
}
