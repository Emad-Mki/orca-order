import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../utils/number_utils.dart';
import 'product_image_widget.dart';

/// Widget يعرض ملخص السلة مع إمكانية المراجعة والتأكيد
class CartSummaryWidget extends StatelessWidget {
  final List<OrderItem> cartItems;
  final VoidCallback? onReviewTap;
  final VoidCallback? onSubmitTap;
  final VoidCallback? onSaveDraftTap;
  final bool isSubmitting;

  const CartSummaryWidget({
    super.key,
    required this.cartItems,
    this.onReviewTap,
    this.onSubmitTap,
    this.onSaveDraftTap,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // عرض السلة
          Row(
            children: [
              Icon(Icons.shopping_cart, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'السلة: ${cartItems.length} أصناف',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (cartItems.isNotEmpty && onReviewTap != null)
                TextButton(
                  onPressed: onReviewTap,
                  child: const Text('مراجعة'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // زر الإرسال
          Row(
            children: [
              if (onSaveDraftTap != null) ...[
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: isSubmitting ? null : onSaveDraftTap,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('حفظ مسودة'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed:
                        cartItems.isEmpty || isSubmitting ? null : onSubmitTap,
                    icon: const Icon(Icons.send),
                    label: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('تأكيد وإرسال'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// يظهر Dialog لمراجعة محتويات السلة
  static void showReviewDialog({
    required BuildContext context,
    required List<OrderItem> cartItems,
    required Future<void> Function() onSubmit,
    required ValueChanged<OrderItem> onRemoveItem,
    required void Function(OrderItem item, double quantity, String unit)
        onUpdateItem,
    bool isSubmitting = false,
  }) {
    var submitting = isSubmitting;
    final quantityControllers = <String, TextEditingController>{};
    for (final item in cartItems) {
      final key =
          '${item.code}|${item.selectedUnit ?? item.unit}|${item.priceOffer ?? item.displayPrice}';
      quantityControllers[key] =
          TextEditingController(text: '${item.quantity ?? 0}');
    }
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('مراجعة الطلب قبل الإرسال'),
          content: SizedBox(
            width: min(560.0, MediaQuery.sizeOf(context).width - 48).toDouble(),
            height:
                min(560.0, MediaQuery.sizeOf(context).height * 0.65).toDouble(),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final units = item.product?.availableUnits ?? [item.unit];
                      final unit = item.selectedUnit ?? item.unit;
                      final quantity = item.quantity ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildProductImage(item.product),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.product?.name ?? item.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف الصنف',
                                    icon: Icon(Icons.delete_outline,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error),
                                    onPressed: submitting
                                        ? null
                                        : () {
                                            onRemoveItem(item);
                                            setDialogState(() {});
                                          },
                                  ),
                                ],
                              ),
                              if (item.code.isNotEmpty)
                                Text('رمز المنتج: ${item.code}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  IconButton.filledTonal(
                                    tooltip: 'إنقاص الكمية',
                                    onPressed: submitting || quantity <= 1
                                        ? null
                                        : () {
                                            final next = (quantity - 1)
                                                .clamp(0.0, double.infinity)
                                                .toDouble();
                                            onUpdateItem(item, next, unit);
                                            setDialogState(() {});
                                          },
                                    icon: const Icon(Icons.remove, size: 18),
                                  ),
                                  SizedBox(
                                    width: 72,
                                    child: TextField(
                                      controller: quantityControllers[
                                          '${item.code}|${item.selectedUnit ?? item.unit}|${item.priceOffer ?? item.displayPrice}'],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      textAlign: TextAlign.center,
                                      enabled: !submitting,
                                      onSubmitted: (value) {
                                        final next = double.tryParse(value);
                                        if (next == null ||
                                            !next.isFinite ||
                                            next <= 0) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'أدخل كمية صحيحة أكبر من صفر')),
                                          );
                                          quantityControllers[
                                                  '${item.code}|${item.selectedUnit ?? item.unit}|${item.priceOffer ?? item.displayPrice}']
                                              ?.text = quantity.toString();
                                          return;
                                        }
                                        onUpdateItem(item, next, unit);
                                        setDialogState(() {});
                                      },
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    tooltip: 'زيادة الكمية',
                                    onPressed: submitting
                                        ? null
                                        : () {
                                            onUpdateItem(
                                                item, quantity + 1, unit);
                                            setDialogState(() {});
                                          },
                                    icon: const Icon(Icons.add, size: 18),
                                  ),
                                  if (units.length > 1)
                                    DropdownButton<String>(
                                      value: units.contains(unit)
                                          ? unit
                                          : units.first,
                                      items: units
                                          .map((value) => DropdownMenuItem(
                                                value: value,
                                                child: Text(value),
                                              ))
                                          .toList(),
                                      onChanged: submitting
                                          ? null
                                          : (value) {
                                              if (value != null) {
                                                onUpdateItem(
                                                    item, quantity, value);
                                                setDialogState(() {});
                                              }
                                            },
                                    )
                                  else
                                    Text('الوحدة: $unit'),
                                ],
                              ),
                              if (item.note?.trim().isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text('ملاحظة: ${item.note}',
                                      softWrap: true),
                                ),
                              if (!item.hasConfiguredUnitPrice ||
                                  !item.hasConfiguredUnitConversion)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    !item.hasConfiguredUnitPrice
                                        ? 'سعر هذه الوحدة غير مضبوط'
                                        : 'معامل تحويل الوحدة غير مضبوط',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      item.hasConfiguredUnitPrice
                                          ? 'سعر الوحدة: ${formatMoneyShort(item.displayPrice, currency: item.currency)}'
                                          : 'سعر هذه الوحدة غير مضبوط',
                                      style: TextStyle(
                                        color: item.hasConfiguredUnitPrice
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                            : Theme.of(context)
                                                .colorScheme
                                                .error,
                                      )),
                                  Text(
                                    formatMoneyShort(item.total,
                                        currency: item.currency),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    'الإجمالي: ${formatMoneyShort(cartItems.fold<double>(0, (sum, item) => sum + item.total), currency: cartItems.isEmpty ? 'USD' : cartItems.first.currency)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
            FilledButton(
              onPressed: submitting ||
                      cartItems.isEmpty ||
                      cartItems.any((item) =>
                          !item.hasConfiguredUnitPrice ||
                          !item.hasConfiguredUnitConversion)
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      await onSubmit();
                      if (context.mounted) {
                        setDialogState(() => submitting = false);
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('تأكيد وإرسال'),
            ),
          ],
        ),
      ),
    ).then((_) {
      for (final controller in quantityControllers.values) {
        controller.dispose();
      }
    });
  }

  static Widget _buildProductImage(Product? product) {
    return ProductImageWidget(
      imageUrl: product?.imageUrl,
      width: 60,
      height: 60,
      borderRadius: BorderRadius.circular(8),
    );
  }
}
