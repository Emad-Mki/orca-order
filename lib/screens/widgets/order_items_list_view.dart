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
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductImageWidget(
                      imageUrl: item.imageUrl,
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (item.code.isNotEmpty)
                            Text(
                              'رمز المنتج: ${item.code}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'الوحدة: ${item.unit.isEmpty ? 'غير محددة' : item.unit}',
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (hasPricing)
                  _buildQuantityRow(
                      context, 'الكمية في الفاتورة', item.pricedQuantity, item)
                else
                  _buildQuantityRow(
                      context, 'المطلوب', item.quantityRequested ?? 0, item),
                if (!hasPricing &&
                    item.quantityApproved != null &&
                    item.quantityApproved! > 0)
                  _buildQuantityRow(
                      context, 'المعتمد', item.quantityApproved!, item,
                      color: theme.colorScheme.primary, isBold: true),
                if (item.quantityPrepared != null && item.quantityPrepared! > 0)
                  _buildQuantityRow(
                      context, 'المجهز', item.quantityPrepared!, item,
                      color: Colors.orange, isBold: true),
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
                if (showPrices && item.hasConfiguredUnitPrice) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasPricing && item.isUnavailable
                              ? 'غير متوفر'
                              : 'سعر الوحدة: ${formatMoneyShort(hasPricing ? item.pricedUnitPrice : item.displayPrice, currency: item.currency)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        'الإجمالي: ${formatMoneyShort(hasPricing ? item.pricedLineTotal : item.total, currency: item.currency)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (showPrices &&
                    !item.hasConfiguredUnitPrice &&
                    hasPricing &&
                    !item.isUnavailable) ...[
                  const Divider(height: 20),
                  Text(
                    'لا يوجد سعر محفوظ لهذا البند',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuantityRow(
      BuildContext context, String label, double quantity, OrderItem item,
      {Color? color, bool isBold = false}) {
    final theme = Theme.of(context);
    String unitInfo = item.unit;

    // Show conversion info if using secondary units
    if (item.unitFactor != null && item.unitFactor! != 1.0) {
      final baseQty = (quantity * item.unitFactor!).toStringAsFixed(2);
      unitInfo += ' ($baseQty ${item.unit1 ?? ''})';
    }

    return Text(
      '$label: $quantity $unitInfo',
      style: TextStyle(
        color: color ?? theme.colorScheme.onSurface,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
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
