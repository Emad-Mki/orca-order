import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';

/// شاشة تفاصيل المنتج
class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.name ?? 'تفاصيل المنتج')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج
            Center(
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: product.imageUrl!,
                      height: 200,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    )
                  : Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, size: 80, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 16),
            
            // اسم المنتج
            Text(
              product.name ?? '',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // السعر
            Row(
              children: [
                Text(
                  '\$${product.price?.toStringAsFixed(2) ?? '0.00'}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (product.offerPrice != null && product.offerPrice! > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '\$${product.price?.toStringAsFixed(2) ?? '0.00'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            
            // الوصف
            if (product.description != null && product.description!.isNotEmpty) ...[
              const Text('الوصف:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(product.description!),
              const SizedBox(height: 16),
            ],
            
            // الكمية المتوفرة
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 20),
                const SizedBox(width: 8),
                Text('الكمية المتوفرة: ${product.stockQuantity ?? 0}'),
              ],
            ),
            const SizedBox(height: 8),
            
            // الحد الأدنى للطلب
            Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, size: 20),
                const SizedBox(width: 8),
                Text('الحد الأدنى للطلب: ${product.minOrderQuantity ?? 1}'),
              ],
            ),
            const SizedBox(height: 16),
            
            // معلومات إضافية
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('المعرف', product.id.toString()),
                    const Divider(),
                    _buildInfoRow('الفئة', product.category ?? 'غير محدد'),
                    const Divider(),
                    _buildInfoRow('العلامة التجارية', product.brand ?? 'غير محدد'),
                    const Divider(),
                    _buildInfoRow('الحالة', product.isActive == true ? 'نشط' : 'غير نشط'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
