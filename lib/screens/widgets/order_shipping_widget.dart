import 'package:flutter/material.dart';

/// ويدجت معلومات الشحن والتجهيز
class OrderShippingWidget extends StatelessWidget {
  final Map<String, dynamic> shipmentData;
  final String role;

  const OrderShippingWidget({
    super.key,
    required this.shipmentData,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بيانات الشحن والتجهيز',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Divider(),
            if (shipmentData['warehouse_note']?.toString().isNotEmpty == true)
              _buildInfoRow(
                'ملاحظات المستودع',
                shipmentData['warehouse_note'].toString(),
              ),
            _buildInfoRow('طريقة الاستلام',
                shipmentData['delivery_method'] ?? 'غير محدد'),
            if (shipmentData['carrier']?.toString().isNotEmpty == true)
              _buildInfoRow('شركة الشحن', shipmentData['carrier']),
            if (shipmentData['province']?.toString().isNotEmpty == true)
              _buildInfoRow('الوجهة', shipmentData['province']),
            _buildInfoRow(
              'الطرود',
              '${shipmentData['package_count']} (كراتين: ${shipmentData['carton_count']}, أكياس: ${shipmentData['bag_count']})',
            ),
            if (role == 'admin' &&
                shipmentData['shipping_cost_internal'] != null)
              _buildInfoRow(
                'تكلفة الشحن الداخلية',
                '\$${shipmentData['shipping_cost_internal']}',
                valueColor: theme.colorScheme.error,
              ),
            if (shipmentData['tracking_no']?.toString().isNotEmpty == true)
              _buildInfoRow('رقم التتبع', shipmentData['tracking_no'],
                  isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
