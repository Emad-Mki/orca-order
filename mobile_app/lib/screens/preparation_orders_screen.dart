import 'package:flutter/material.dart';

/// شاشة طلبات التحضير (فارغة - للاستخدام المستقبلي)
class PreparationOrdersScreen extends StatelessWidget {
  const PreparationOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات التحضير')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد طلبات قيد التحضير',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
