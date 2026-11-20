import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../utils/utils.dart';
import '../widgets/product_availability_badge.dart';
import '../widgets/product_image_widget.dart';
import 'new_order_screen.dart';

String _formatProductQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  final Map<String, dynamic>? session;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.session,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = PermissionHelper.fromString(
      session?['role']?.toString() ?? 'user',
    );
    final canSeeStock = PermissionHelper.hasPermission(
      role,
      AppPermission.viewProductQuantities,
    );
    final canSeePrice = PermissionHelper.hasPermission(
          role,
          AppPermission.viewProductPrices,
        ) ||
        PermissionHelper.hasPermission(
          role,
          AppPermission.viewSellingPriceOnly,
        );
    final canCreateOrder = PermissionHelper.hasPermission(
      role,
      AppPermission.createOrder,
    );
    final availability = productAvailabilityFrom(
      value: product.availabilityStatus,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildImageAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleAndStatus(context, availability),
                  if (canSeePrice) ...[
                    const SizedBox(height: 18),
                    _buildPriceCard(context),
                  ],
                  if (canSeeStock && product.stockQuantity != null) ...[
                    const SizedBox(height: 12),
                    _buildStockSummary(context),
                  ],
                  const SizedBox(height: 20),
                  _buildBasicInfo(context),
                  if (_hasOptionalInfo) ...[
                    const SizedBox(height: 16),
                    _buildOptionalInfo(context),
                  ],
                  if (_description != null) ...[
                    const SizedBox(height: 16),
                    _buildDescription(context, _description!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: canCreateOrder ? _buildBottomAction(context) : null,
    );
  }

  String? get _description {
    final description = product.description?.trim();
    if (description != null && description.isNotEmpty) return description;
    final notes = product.notes?.trim();
    return notes == null || notes.isEmpty ? null : notes;
  }

  bool get _hasOptionalInfo =>
      product.group.trim().isNotEmpty ||
      product.subGroup.trim().isNotEmpty ||
      (product.brand?.trim().isNotEmpty ?? false) ||
      product.unit.trim().isNotEmpty ||
      product.minOrderQuantity != null;

  String? get _heroTag {
    if (product.id == null && product.code.isEmpty) return null;
    return 'product_image_${product.id ?? product.code}';
  }

  Widget _buildImageAppBar(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).width * 0.78)
        .clamp(260.0, 360.0)
        .toDouble();
    final colors = Theme.of(context).colorScheme;
    return SliverAppBar(
      expandedHeight: height,
      pinned: true,
      backgroundColor: colors.surface,
      surfaceTintColor: colors.surface,
      title: Text(
        product.name.trim().isEmpty ? 'تفاصيل المنتج' : product.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Semantics(
          button: true,
          label: 'عرض صورة المنتج بالحجم الكامل',
          child: GestureDetector(
            onTap: () => _showFullScreenImage(context),
            child: ColoredBox(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.32),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 56),
                  child: ProductImageWidget(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.contain,
                    heroTag: _heroTag,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleAndStatus(
    BuildContext context,
    ProductAvailability availability,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name.trim().isEmpty ? 'منتج بدون اسم' : product.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
          softWrap: true,
        ),
        const SizedBox(height: 12),
        ProductAvailabilityBadge(availability: availability),
        if (product.group.trim().isNotEmpty ||
            product.subGroup.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (product.group.trim().isNotEmpty)
                _categoryBadge(
                  context,
                  product.group.trim(),
                  isPrimary: true,
                ),
              if (product.subGroup.trim().isNotEmpty)
                _categoryBadge(context, product.subGroup.trim()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _categoryBadge(
    BuildContext context,
    String label, {
    bool isPrimary = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary
            ? colors.primaryContainer.withValues(alpha: 0.68)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        softWrap: true,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isPrimary ? colors.primary : colors.onSurfaceVariant,
              fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
            ),
      ),
    );
  }

  Widget _buildPriceCard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سعر البيع',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          if (!product.priceConfigured)
            Text(
              'السعر غير مضبوط',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  formatMoneyShort(
                      product.offerPrice != null && product.offerPrice! > 0
                          ? product.offerPrice!
                          : product.price,
                      currency: product.currency),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (product.offerPrice != null &&
                    product.offerPrice! > 0 &&
                    product.priceConfigured)
                  Text(
                    formatMoneyShort(
                      product.price,
                      currency: product.currency,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStockSummary(BuildContext context) {
    final quantity = product.stockQuantity ?? product.stock.toDouble();
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'الكمية المسجلة: ${_formatProductQuantity(quantity)}${product.unit.trim().isEmpty ? '' : ' ${product.unit}'}',
              style: Theme.of(context).textTheme.bodyMedium,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(BuildContext context) {
    return _infoCard(
      context,
      title: 'معلومات أساسية',
      children: [
        _infoValue(
          context,
          label: 'رمز المنتج',
          value: product.code.trim().isEmpty ? '—' : product.code.trim(),
          copyValue: product.code.trim().isEmpty ? null : product.code.trim(),
        ),
        _infoValue(
          context,
          label: 'رقم OEM',
          value: product.oem.trim().isEmpty ? '_' : product.oem.trim(),
          copyValue: product.oem.trim().isEmpty ? null : product.oem.trim(),
        ),
        _infoValue(
          context,
          label: 'المنشأ',
          value: product.origin.trim().isEmpty
              ? 'غير محدد'
              : product.origin.trim(),
        ),
      ],
    );
  }

  Widget _buildOptionalInfo(BuildContext context) {
    return _infoCard(
      context,
      title: 'تفاصيل المنتج',
      children: [
        if (product.brand?.trim().isNotEmpty ?? false)
          _infoValue(context,
              label: 'العلامة التجارية', value: product.brand!.trim()),
        if (product.unit.trim().isNotEmpty)
          _infoValue(context, label: 'وحدة البيع', value: product.unit.trim()),
        if (product.minOrderQuantity != null)
          _infoValue(
            context,
            label: 'الحد الأدنى للطلب',
            value:
                '${_formatProductQuantity(product.minOrderQuantity!)}${product.unit.trim().isEmpty ? '' : ' ${product.unit.trim()}'}',
          ),
      ],
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoValue(
    BuildContext context, {
    required String label,
    required String value,
    String? copyValue,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          if (copyValue != null)
            IconButton(
              tooltip: 'نسخ $label',
              visualDensity: VisualDensity.compact,
              onPressed: () => _copyToClipboard(context, copyValue, label),
              icon: Icon(Icons.copy_rounded, size: 18, color: colors.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context, String description) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الوصف والملاحظات',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NewOrderScreen(
                      session: session ?? {},
                      initialProduct: product,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('إضافة إلى طلب جديد'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(
    BuildContext context,
    String value,
    String label,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ $label')),
    );
  }

  void _showFullScreenImage(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _ProductImageViewer(
          imageUrl: product.imageUrl,
          heroTag: _heroTag,
          productName: product.name,
        ),
      ),
    );
  }
}

class _ProductImageViewer extends StatelessWidget {
  final String? imageUrl;
  final String? heroTag;
  final String productName;

  const _ProductImageViewer({
    required this.imageUrl,
    required this.heroTag,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(40),
          child: SizedBox.expand(
            child: ProductImageWidget(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              heroTag: heroTag,
            ),
          ),
        ),
      ),
    );
  }
}
