import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';

/// Widget لعرض قائمة أصناف الطلب مع دعم State Management
class OrderItemsListView extends StatelessWidget {
  final String role;
  
  const OrderItemsListView({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderDetailProvider>(context);
    final items = provider.items;

    if (items.isEmpty) {
      return const Center(child: Text('لا توجد أصناف في هذا الطلب'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final bool showPrices = role != 'warehouse';
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المطلوب: ${item.quantityRequested} ${item.unit}'),
                if (item.quantityApproved > 0)
                  Text('المعتمد: ${item.quantityApproved} ${item.unit}', 
                       style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                if (item.quantityPrepared > 0)
                  Text('المجهز: ${item.quantityPrepared} ${item.unit}', 
                       style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                if (item.customerNote?.toString().isNotEmpty == true)
                  Text('ملاحظة الزبون: ${item.customerNote}', 
                       style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                if (item.accountantNote?.toString().isNotEmpty == true)
                  Text('ملاحظة المحاسب: ${item.accountantNote}', 
                       style: const TextStyle(fontSize: 12, color: Colors.blue)),
                if (item.warehouseNote?.toString().isNotEmpty == true)
                  Text('ملاحظة المستودع: ${item.warehouseNote}', 
                       style: const TextStyle(fontSize: 12, color: Colors.orange)),
              ],
            ),
            trailing: showPrices ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$' + formatMoneyShort(item.displayPrice),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('الإجمالي: \$' + formatMoneyShort(item.total),
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ) : null,
          ),
        );
      },
    );
  }
}
