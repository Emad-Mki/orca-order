import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../widgets/product_image_widget.dart';
import 'new_order_screen.dart';

/// شاشة تفاصيل المنتج المحدثة بتصميم عصري
class ProductDetailScreen extends StatelessWidget {
  final Product product;
  final Map<String, dynamic>? session;

  const ProductDetailScreen({super.key, required this.product, this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleString = session?['role']?.toString().toLowerCase() ?? 'user';
    final userRole = PermissionHelper.fromString(roleString);
    
    final canSeeStock = PermissionHelper.hasPermission(
        userRole, AppPermission.viewProductQuantities);
    final canSeePrice = PermissionHelper.hasPermission(
            userRole, AppPermission.viewProductPrices) ||
        PermissionHelper.hasPermission(
            userRole, AppPermission.viewSellingPriceOnly);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, canSeePrice),
                  const SizedBox(height: 24),
                  if (canSeeStock) ...[
                    _buildStockSection(context),
                    const SizedBox(height: 24),
                  ],
                  _buildDetailsSection(context),
                  const SizedBox(height: 24),
                  if (product.description?.isNotEmpty == true) ...[
                    _buildDescription(context),
                    const SizedBox(height: 24),
                  ],
                  _buildActionButtons(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 350.0,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: GestureDetector(
          onTap: () => _showFullScreenImage(context),
          child: Hero(
            tag: 'product_image_${product.id}',
            child: ProductImageWidget(
              imageUrl: product.imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: () {
            // منطق المشاركة
          },
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool canSeePrice) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Code: ${product.code}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            if (canSeePrice)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    product.price > 0 
                        ? '\$${formatMoneyShort(product.price)}' 
                        : 'اتصل للسعر',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (product.offerPrice != null && product.offerPrice! > 0)
                    Text(
                      '\$${formatMoneyShort(product.offerPrice!)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            product.category,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockSection(BuildContext context) {
    final theme = Theme.of(context);
    final bool isLowStock = product.stock <= 5;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLowStock ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLowStock ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLowStock ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: isLowStock ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حالة المخزون',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                isLowStock ? 'مخزون منخفض: ${product.stock} قطع' : 'متوفر: ${product.stock} قطع',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isLowStock ? Colors.orange[800] : Colors.green[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المواصفات التقنية',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _detailRow(context, 'رقم OEM', product.oem.isNotEmpty ? product.oem : 'غير متوفر'),
        _detailRow(context, 'المنشأ', product.origin),
        _detailRow(context, 'الماركة', product.brand ?? 'غير محدد'),
        _detailRow(context, 'المجموعة الفرعية', product.subGroup.isNotEmpty ? product.subGroup : 'لا يوجد'),
        _detailRow(context, 'وحدة القياس', product.unit),
        _detailRow(context, 'الحد الأدنى للطلب', '${product.minOrderQuantity ?? 1}'),
      ],
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الوصف',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          product.description!,
          style: TextStyle(color: Colors.grey[800], height: 1.5),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewOrderScreen(
                    session: session ?? {},
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('إضافة للطلب'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: ProductImageWidget(
                imageUrl: product.imageUrl,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
