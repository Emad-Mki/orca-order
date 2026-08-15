import 'package:flutter/material.dart';
import '../../models/models.dart';

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
    return Card(
      color: Colors.indigo.shade50,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بيانات الشحن والتجهيز',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const Divider(),
            _buildInfoRow('طريقة الاستلام', shipmentData['delivery_method'] ?? 'غير محدد'),
            if (shipmentData['carrier']?.toString().isNotEmpty == true)
              _buildInfoRow('شركة الشحن', shipmentData['carrier']),
            if (shipmentData['province']?.toString().isNotEmpty == true)
              _buildInfoRow('الوجهة', shipmentData['province']),
            _buildInfoRow(
              'الطرود',
              '${shipmentData['package_count']} (كراتين: ${shipmentData['carton_count']}, أكياس: ${shipmentData['bag_count']})',
            ),
            if (role == 'admin' && shipmentData['shipping_cost_internal'] != null)
              _buildInfoRow(
                'تكلفة الشحن الداخلية',
                '\$${shipmentData['shipping_cost_internal']}',
                valueColor: Colors.red,
              ),
            if (shipmentData['tracking_no']?.toString().isNotEmpty == true)
              _buildInfoRow('رقم التتبع', shipmentData['tracking_no'], isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
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
