import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../order_status_mapper.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../../widgets/product_image_widget.dart';

/// Widget لعرض قائمة أصناف الطلب مع دعم State Management
class OrderItemsListView extends StatelessWidget {
  final String role;

  const OrderItemsListView({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<OrderDetailProvider>(context);
    final items = provider.items;

    if (items.isEmpty) {
      return const Center(child: Text('لا توجد أصناف في هذا الطلب'));
    }

    final userRole = PermissionHelper.fromString(role);
    final bool showPrices = PermissionHelper.hasPermission(
            userRole, AppPermission.viewProductPrices) ||
        PermissionHelper.hasPermission(
            userRole, AppPermission.viewSellingPriceOnly);
    final hasPricing =
        OrderStatusMapper.hasPricing(provider.currentOrder?.status);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: ProductImageWidget(
              imageUrl: item.imageUrl,
              width: 50,
              height: 50,
              borderRadius: BorderRadius.circular(4),
            ),
            title: Text(item.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.code.isNotEmpty)
                  Text('كود: ${item.code}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      )),
                if (hasPricing)
                  Text(
                      'الكمية في الفاتورة: ${item.pricedQuantity} ${item.unit}')
                else
                  Text('المطلوب: ${item.quantityRequested} ${item.unit}'),
                if (!hasPricing &&
                    item.quantityApproved != null &&
                    item.quantityApproved! > 0)
                  Text('المعتمد: ${item.quantityApproved} ${item.unit}',
                      style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                if (item.quantityPrepared != null && item.quantityPrepared! > 0)
                  Text('المجهز: ${item.quantityPrepared} ${item.unit}',
                      style: const TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold)),
                if (item.customerNote?.toString().isNotEmpty == true)
                  Text('ملاحظة الزبون: ${item.customerNote}',
                      style: const TextStyle(
                          fontSize: 12, fontStyle: FontStyle.italic)),
                if (item.accountantNote?.toString().isNotEmpty == true)
                  Text('ملاحظة المحاسب: ${item.accountantNote}',
                      style: TextStyle(
                          fontSize: 12, color: theme.colorScheme.primary)),
                if (item.warehouseNote?.toString().isNotEmpty == true)
                  Text('ملاحظة المستودع: ${item.warehouseNote}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.orange)),
                if (item.warehousePackageNumbers?.isNotEmpty == true)
                  Text(
                    'الطرد: ${item.warehousePackageNumbers} - ${_packageTypeLabel(item)}',
                    style: const TextStyle(fontSize: 12, color: Colors.indigo),
                  ),
              ],
            ),
            trailing: showPrices
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          hasPricing && item.isUnavailable
                              ? 'غير متوفر'
                              : '\$${formatMoneyShort(hasPricing ? item.pricedUnitPrice : item.displayPrice)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                          'الإجمالي: \$${formatMoneyShort(hasPricing ? item.pricedLineTotal : item.total)}',
                          style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  String _packageTypeLabel(OrderItem item) {
    switch (item.warehousePackageType) {
      case 'carton':
        return 'كرتونة';
      case 'bag':
        return 'كيس';
      case 'other':
        return item.warehouseCustomPackageType ?? 'أخرى';
      default:
        return '';
    }
  }
}
