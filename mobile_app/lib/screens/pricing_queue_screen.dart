import 'package:flutter/material.dart';

/// شاشة قائمة التسعير (فارغة - للاستخدام المستقبلي)
class PricingQueueScreen extends StatelessWidget {
  const PricingQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قائمة التسعير')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.price_check_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد عناصر في قائمة التسعير',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
