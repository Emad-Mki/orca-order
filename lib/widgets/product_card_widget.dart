import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/number_utils.dart';
import 'product_availability_badge.dart';
import 'product_image_widget.dart';

class ProductCardWidget extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool canViewPrice;
  final bool canViewWholesale;

  const ProductCardWidget({
    super.key,
    required this.product,
    required this.onTap,
    this.onLongPress,
    this.canViewPrice = true,
    this.canViewWholesale = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final availability = productAvailabilityFrom(
      value: product.availabilityStatus,
    );
    final heroTag = product.id != null || product.code.isNotEmpty
        ? 'product_image_${product.id ?? product.code}'
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج مع شارة الحالة
            Stack(
              children: [
                Container(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  child: AspectRatio(
                    aspectRatio: 1.3,
                    child: ProductImageWidget(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.contain,
                      heroTag: heroTag,
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  end: 8,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: ProductAvailabilityBadge(
                      availability: availability,
                      compact: true,
                    ),
                  ),
                ),
              ],
            ),
            // معلومات المنتج
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name.trim().isEmpty
                              ? 'منتج بدون اسم'
                              : product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.code.trim().isEmpty
                              ? '—'
                              : 'الرمز: ${product.code}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.secondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (canViewPrice)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.priceConfigured
                                ? 'السعر: ${formatMoneyShort(
                                    product.offerPrice != null &&
                                            product.offerPrice! > 0
                                        ? product.offerPrice!
                                        : product.price,
                                    currency: product.currency,
                                  )}'
                                : 'السعر غير مضبوط',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: product.priceConfigured
                                  ? colorScheme.primary
                                  : colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (canViewWholesale &&
                              product.wholesalePrice != null)
                            Text(
                              'الجملة: ${formatMoneyShort(product.wholesalePrice!, currency: product.currency)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.brightness == Brightness.dark
                                    ? Colors.green.shade300
                                    : Colors.green.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
