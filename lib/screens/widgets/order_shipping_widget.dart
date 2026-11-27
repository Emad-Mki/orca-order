import 'package:flutter/material.dart';
import '../../utils/shipment_summary.dart';

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
    final rawShipments = shipmentData['all_shipments'];
    final shipments = rawShipments is List
        ? rawShipments
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[shipmentData];
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
            for (var index = 0; index < shipments.length; index++) ...[
              if (shipments.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    'شحنة ${index + 1} ${shipments[index]['shipment_id'] == null ? '' : '#${shipments[index]['shipment_id']}'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              if (shipments[index]['warehouse_note']?.toString().isNotEmpty ==
                  true)
                _buildInfoRow(
                  'ملاحظات المستودع',
                  shipments[index]['warehouse_note'].toString(),
                ),
              _buildInfoRow(
                'طريقة الاستلام',
                shipments[index]['delivery_method']?.toString() ?? 'غير محدد',
              ),
              if (shipments[index]['carrier']?.toString().isNotEmpty == true)
                _buildInfoRow(
                    'شركة الشحن', shipments[index]['carrier'].toString()),
              if (shipments[index]['province']?.toString().isNotEmpty == true)
                _buildInfoRow(
                    'الوجهة', shipments[index]['province'].toString()),
              _buildInfoRow('الطرود', ShipmentSummary.format(shipments[index])),
              if (shipments[index]['weight_kg']?.toString().isNotEmpty == true)
                _buildInfoRow('الوزن', '${shipments[index]['weight_kg']} كغ'),
              if (shipments[index]['dimensions']?.toString().isNotEmpty == true)
                _buildInfoRow(
                    'الحجم', shipments[index]['dimensions'].toString()),
              if (role == 'admin' &&
                  shipments[index]['shipping_cost_internal'] != null)
                _buildInfoRow(
                  'تكلفة الشحن الداخلية',
                  '\$${shipments[index]['shipping_cost_internal']}',
                  valueColor: theme.colorScheme.error,
                ),
              if (shipments[index]['tracking_no']?.toString().isNotEmpty ==
                  true)
                _buildInfoRow(
                  'رقم التتبع',
                  shipments[index]['tracking_no'].toString(),
                  isBold: true,
                ),
              if (index < shipments.length - 1) const Divider(),
            ],
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
