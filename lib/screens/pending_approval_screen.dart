import 'package:flutter/material.dart';

/// شاشة الطلبات قيد الموافقة (فارغة - للاستخدام المستقبلي)
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('قيد الموافقة')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pending_actions_outlined, size: 80, color: muted),
            const SizedBox(height: 16),
            Text(
              'لا توجد طلبات قيد الموافقة',
              style: TextStyle(fontSize: 18, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
