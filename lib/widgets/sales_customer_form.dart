import 'dart:math';

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SalesCustomerRequest {
  final String name;
  final String phone;
  final String requestId;

  SalesCustomerRequest({required this.name, required this.phone})
      : requestId = 'CUSTOMER-${DateTime.now().microsecondsSinceEpoch}-'
            '${Random.secure().nextInt(0x7fffffff)}';

  Future<Map<String, dynamic>> submit() async {
    final response = await ApiService().sales.createCustomer(
          fullName: name,
          phone: phone,
          clientRequestId: requestId,
        );
    final customer = response['customer'];
    if (customer is! Map || customer['customer_id'] == null) {
      throw const FormatException('استجابة إنشاء العميل غير صالحة');
    }
    return Map<String, dynamic>.from(customer);
  }
}

Future<Map<String, String>?> showSalesCustomerForm(BuildContext context) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  try {
    final route = DialogRoute<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة زبون تجاري دون حساب دخول'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'اسم الزبون'),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'الهاتف (اختياري)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('أدخل اسمًا من حرفين على الأقل')),
                );
                return;
              }
              Navigator.pop(context, {
                'name': name.text.trim(),
                'phone': phone.text.trim(),
              });
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    Navigator.of(context, rootNavigator: true).push(route);
    return await route.completed;
  } finally {
    name.dispose();
    phone.dispose();
  }
}
