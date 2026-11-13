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
    required VoidCallback onSubmit,
    required ValueChanged<OrderItem> onRemoveItem,
    bool isSubmitting = false,
  }) {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('مراجعة الطلب قبل الإرسال'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return ListTile(
                  leading: _buildProductImage(item.product),
                  title: Text(item.product?.name ?? 'بدون اسم'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'الكمية: ${item.quantity} ${item.selectedUnit ?? item.product?.unit ?? ""}'),
                      if (item.note != null && item.note!.isNotEmpty)
                        Text('ملاحظة: ${item.note}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            )),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('\$${formatMoneyShort(item.total)}'),
                      IconButton(
                        tooltip: 'حذف الصنف',
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: isSubmitting
                            ? null
                            : () {
                                onRemoveItem(item);
                                setDialogState(() {});
                              },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
            FilledButton(
              onPressed: isSubmitting || cartItems.isEmpty ? null : onSubmit,
              child: isSubmitting
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
    );
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
