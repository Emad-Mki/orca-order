import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../providers/products_provider.dart';
import '../widgets/product_image_widget.dart';
import '../widgets/product_card_widget.dart';
import '../widgets/product_skeleton_widget.dart';
import 'product_detail_screen.dart';
import 'homepage_screen.dart';

class ProductsScreen extends StatefulWidget {
  final Map<String, dynamic>? session;
  final ProductSortOption? initialSortOption;

  const ProductsScreen({
    super.key,
    this.session,
    this.initialSortOption,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _throttleNoticeShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProductsProvider>();
      _searchController.text = provider.searchQuery;
      if (widget.initialSortOption != null) {
        provider.setSortOption(widget.initialSortOption!);
      }
      provider.fetchProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    final provider = context.read<ProductsProvider>();
    await provider.fetchProducts(forceRefresh: true);
    if (!mounted) return;
    if (provider.lastRefreshThrottled) {
      if (_throttleNoticeShown) return;
      _throttleNoticeShown = true;
      final seconds = provider.manualRefreshRemaining.inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى الانتظار قليلًا قبل التحديث مجددًا'
            '${seconds > 0 ? ' (باقي $seconds ثانية)' : ''}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _throttleNoticeShown = false;
    }
  }

  void _showProductDetails(Product product) {
    final session = widget.session ??
        context.findAncestorStateOfType<HomePageState>()?.widget.session;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              ProductDetailScreen(product: product, session: session)),
    );
  }

  void _showSortBottomSheet() {
    final provider = context.read<ProductsProvider>();
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('ترتيب حسب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          _sortTile(ProductSortOption.name, 'الاسم', Icons.sort_by_alpha),
          _sortTile(ProductSortOption.newest, 'الأحدث أولاً', Icons.new_releases),
          _sortTile(ProductSortOption.priceLowHigh, 'السعر: من الأقل إلى الأعلى',
              Icons.arrow_upward),
          _sortTile(ProductSortOption.priceHighLow, 'السعر: من الأعلى إلى الأقل',
              Icons.arrow_downward),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sortTile(ProductSortOption option, String title, IconData icon) {
    final provider = context.watch<ProductsProvider>();
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: provider.sortOption == option
          ? const Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: () {
        context.read<ProductsProvider>().setSortOption(option);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsProvider>();
    final session = widget.session ??
        context.findAncestorStateOfType<HomePageState>()?.widget.session;
    
    final roleString = session?['role']?.toString().toLowerCase() ?? 'user';
    final userRole = PermissionHelper.fromString(roleString);

    final canViewPrices = PermissionHelper.hasPermission(
            userRole, AppPermission.viewProductPrices) ||
        PermissionHelper.hasPermission(
            userRole, AppPermission.viewSellingPriceOnly);
    final canViewStock = PermissionHelper.hasPermission(
        userRole, AppPermission.viewProductQuantities);

    return Column(
      children: [
        _buildHeader(provider),
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(provider.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchProducts,
            child: _buildContent(provider, canViewPrices, canViewStock),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ProductsProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: provider.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن منتج، كود، أو OEM...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(provider.viewMode == ProductViewMode.grid
                    ? Icons.view_list
                    : Icons.grid_view),
                onPressed: () => provider.setViewMode(
                    provider.viewMode == ProductViewMode.grid
                        ? ProductViewMode.list
                        : ProductViewMode.grid),
                tooltip: 'تبديل وضع العرض',
              ),
              IconButton(
                icon: const Icon(Icons.sort),
                onPressed: _showSortBottomSheet,
                tooltip: 'ترتيب',
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'الكل',
                  isSelected: provider.selectedCategory == null,
                  onSelected: (_) => provider.setCategory(null),
                ),
                ...provider.categories.map((cat) => _buildFilterChip(
                      label: cat,
                      isSelected: provider.selectedCategory == cat,
                      onSelected: (_) => provider.setCategory(cat),
                    )),
              ],
            ),
          ),
          if (provider.selectedCategory != null && provider.subGroups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'الكل في ${provider.selectedCategory}',
                      isSelected: provider.selectedSubGroup == null,
                      onSelected: (_) => provider.setSubGroup(null),
                      isSub: true,
                    ),
                    ...provider.subGroups.map((sub) => _buildFilterChip(
                          label: sub,
                          isSelected: provider.selectedSubGroup == sub,
                          onSelected: (_) => provider.setSubGroup(sub),
                          isSub: true,
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
    bool isSub = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: isSub ? 12 : 13)),
        selected: isSelected,
        onSelected: onSelected,
        visualDensity: VisualDensity.compact,
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildContent(
      ProductsProvider provider, bool canViewPrices, bool canViewStock) {
    if (provider.isInitialLoading) {
      return provider.viewMode == ProductViewMode.grid
          ? GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 6,
              itemBuilder: (_, __) => const ProductSkeletonWidget(isGrid: true),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: 6,
              itemBuilder: (_, __) => const ProductSkeletonWidget(isGrid: false),
            );
    }

    if (provider.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('لا توجد منتجات مطابقة للبحث'),
            TextButton(
              onPressed: provider.resetFilters,
              child: const Text('إعادة تعيين الفلاتر'),
            ),
          ],
        ),
      );
    }

    if (provider.viewMode == ProductViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: provider.products.length,
        itemBuilder: (context, index) {
          final p = provider.products[index];
          return ProductCardWidget(
            product: p,
            onTap: () => _showProductDetails(p),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: provider.products.length,
      itemBuilder: (context, index) {
        final p = provider.products[index];
        return _buildListTile(p, canViewPrices, canViewStock);
      },
    );
  }

  Widget _buildListTile(Product p, bool canViewPrices, bool canViewStock) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ProductImageWidget(
          imageUrl: p.imageUrl,
          width: 70,
          height: 70,
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(
          p.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${p.code}${p.oem.isNotEmpty ? ' | OEM: ${p.oem}' : ''}',
                style: const TextStyle(fontSize: 12)),
            Text(p.category,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.secondary)),
            if (canViewStock)
              Text('المتوفر: ${p.stock}',
                  style: const TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (canViewPrices)
              Text(
                p.price > 0 ? '\$${formatMoneyShort(p.price)}' : 'اتصل للسعر',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: () => _showProductDetails(p),
      ),
    );
  }
}
