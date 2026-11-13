import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/number_utils.dart';
import 'product_image_widget.dart';

/// بطاقة منتج قابلة للنقر تعرض صورة المنتج واسمه وسعره
class ProductCardWidget extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ProductCardWidget({
    super.key,
    required this.product,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج
            Expanded(
              child: _buildProductImage(),
            ),
            // معلومات المنتج
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.code,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildPriceWidget(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    return ProductImageWidget(
      imageUrl: product.imageUrl,
      width: double.infinity,
      fit: BoxFit.contain,
    );
  }

  Widget _buildPriceWidget(BuildContext context) {
    final theme = Theme.of(context);
    if (product.price > 0) {
      return Text(
        '\$${formatMoneyShort(product.price)}',
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return Text(
      'يرجى التواصل للسعر',
      style: TextStyle(color: theme.colorScheme.secondary, fontSize: 11),
    );
  }
}
