import 'package:flutter/material.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../utils/number_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget يعرض ملخص السلة مع إمكانية المراجعة والتأكيد
class CartSummaryWidget extends StatelessWidget {
  final List<OrderItem> cartItems;
  final VoidCallback? onReviewTap;
  final VoidCallback? onSubmitTap;
  final bool isSubmitting;

  const CartSummaryWidget({
    super.key,
    required this.cartItems,
    this.onReviewTap,
    this.onSubmitTap,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              const Icon(Icons.shopping_cart, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'السلة: ${cartItems.length} أصناف',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: cartItems.isEmpty || isSubmitting ? null : onSubmitTap,
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
                  : const Text('إرسال الطلب للمراجعة'),
            ),
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
    bool isSubmitting = false,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
                    Text('الكمية: ${item.quantity} ${item.selectedUnit ?? item.product?.unit ?? ""}'),
                    if (item.note != null && item.note!.isNotEmpty)
                      Text('ملاحظة: ${item.note}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                trailing: Text('\$${formatMoneyShort(item.total)}'),
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
            onPressed: isSubmitting ? null : onSubmit,
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
    );
  }

  static Widget _buildProductImage(Product? product) {
    if (product?.imageUrl != null && product!.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: product.imageUrl!,
          width: 60,
          height: 60,
          fit: BoxFit.contain,
          imageBuilder: (context, imageProvider) => Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.contain,
              ),
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          placeholder: (context, url) => Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, error, stackTrace) => _placeholderImage(),
        ),
      );
    }
    return _placeholderImage();
  }

  static Widget _placeholderImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.inventory_2, size: 30),
    );
  }
}
