import 'package:flutter/material.dart';

/// شاشة الاستيراد والتصدير (فارغة - للاستخدام المستقبلي)
class ImportExportScreen extends StatelessWidget {
  const ImportExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('الاستيراد والتصدير')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.import_export_outlined, size: 80, color: muted),
            const SizedBox(height: 16),
            Text(
              'وظيفة الاستيراد والتصدير غير متاحة حالياً',
              style: TextStyle(fontSize: 18, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
