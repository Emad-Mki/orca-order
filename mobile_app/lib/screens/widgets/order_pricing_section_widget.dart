import 'package:flutter/material.dart';
import '../utils/number_utils.dart';

/// ويدجت قسم التسعير والملخص المالي للطلب
class OrderPricingSectionWidget extends StatelessWidget {
  final List<dynamic> items;
  final Map<String, dynamic>? balanceInfo;
  final double? discount;
  final double? shippingCost;

  const OrderPricingSectionWidget({
    super.key,
    required this.items,
    this.balanceInfo,
    this.discount,
    this.shippingCost,
  });

  @override
  Widget build(BuildContext context) {
    final total = _calculateTotal();
    final discountAmount = discount ?? 0.0;
    final shippingAmount = shippingCost ?? 0.0;
    final netTotal = total - discountAmount + shippingAmount;

    return Card(
      margin: const EdgeInsets.only(top: 16, bottom: 80),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow(
              'إجمالي الفاتورة الحالية:',
              '\\$${total.toStringAsFixed(2)}',
              isBold: true,
            ),
            if (discountAmount > 0)
              _summaryRow(
                'الخصم:',
                '-\\$${discountAmount.toStringAsFixed(2)}',
                color: Colors.green,
              ),
            if (shippingAmount > 0)
              _summaryRow(
                'تكلفة الشحن:',
                '+\\$${shippingAmount.toStringAsFixed(2)}',
                color: Colors.orange,
              ),
            const Divider(),
            _summaryRow(
              'الصافي النهائي:',
              '\\$${netTotal.toStringAsFixed(2)}',
              isBold: true,
              color: Colors.blue,
            ),
            if (balanceInfo != null) ...[
              const Divider(),
              _summaryRow(
                'رصيد الحساب السابق:',
                '\\$${formatMoneyShort(balanceInfo!['current_balance'])}',
              ),
              _summaryRow(
                'الرصيد النهائي بعد الفاتورة:',
                '\\$${formatMoneyShort((balanceInfo!['current_balance'] ?? 0.0) + netTotal)}',
                color: Colors.red,
                isBold: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _calculateTotal() {
    double total = 0.0;
    for (var item in items) {
      final qty = (item['quantity_approved'] ?? 0) > 0
          ? (item['quantity_approved'] as num).toDouble()
          : (item['quantity_requested'] as num).toDouble();
      final price = (item['final_price'] ?? 0) > 0
          ? (item['final_price'] as num).toDouble()
          : (item['price_offer'] as num).toDouble();
      total += qty * price;
    }
    return total;
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
