import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';

/// ويدجت قائمة أصناف الطلب - يعرض جميع المنتجات في الطلب
class OrderItemsListWidget extends StatelessWidget {
  final List<OrderItem> items;
  final String role;
  final bool showPrices;

  const OrderItemsListWidget({
    super.key,
    required this.items,
    required this.role,
    this.showPrices = true,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد أصناف في هذا الطلب'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return OrderItemTileWidget(
          item: item,
          showPrices: showPrices,
        );
      },
    );
  }
}

/// ويدجت صنف واحد من أصناف الطلب
class OrderItemTileWidget extends StatelessWidget {
  final OrderItem item;
  final bool showPrices;

  const OrderItemTileWidget({
    super.key,
    required this.item,
    this.showPrices = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المطلوب: ${item.quantityRequested} ${item.unit}'),
            if (item.quantityApproved > 0)
              Text(
                'المعتمد: ${item.quantityApproved} ${item.unit}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (item.quantityPrepared > 0)
              Text(
                'المجهز: ${item.quantityPrepared} ${item.unit}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (item.customerNote?.toString().isNotEmpty == true)
              Text(
                'ملاحظة الزبون: ${item.customerNote}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (item.accountantNote?.toString().isNotEmpty == true)
              Text(
                'ملاحظة المحاسب: ${item.accountantNote}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
            if (item.warehouseNote?.toString().isNotEmpty == true)
              Text(
                'ملاحظة المستودع: ${item.warehouseNote}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                ),
              ),
          ],
        ),
        trailing: showPrices ? _buildPriceColumn() : null,
      ),
    );
  }

  Widget _buildPriceColumn() {
    final price = item.finalPrice > 0 ? item.finalPrice : item.priceOffer;
    final qty = item.quantityApproved > 0 ? item.quantityApproved : item.quantityRequested;
    final total = price * qty;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '\$${formatMoneyShort(price)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        if (item.finalPrice > 0)
          Text(
            'الإجمالي: \$${formatMoneyShort(total)}',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
      ],
    );
  }
}
