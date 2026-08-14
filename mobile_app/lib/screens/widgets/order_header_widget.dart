import 'package:flutter/material.dart';
import '../models/order.dart';

/// ويدجت رأس بطاقة الطلب - يعرض معلومات الطلب الأساسية
class OrderHeaderWidget extends StatelessWidget {
  final Order order;
  final String statusText;
  final Color statusColor;

  const OrderHeaderWidget({
    super.key,
    required this.order,
    required this.statusText,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'طلب رقم: ${order.orderNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildStatusChip(order.status ?? '', statusText, statusColor),
            ],
          ),
          const SizedBox(height: 4),
          Text('التاريخ: ${_formatDate(order.createdAt)}'),
          if (order.note?.toString().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'ملاحظة الطلب: ${order.note}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, String text, Color color) {
    return Chip(
      label: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
