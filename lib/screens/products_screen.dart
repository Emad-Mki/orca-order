import 'dart:async';

import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/products_provider.dart';
import '../utils/utils.dart';
import '../widgets/product_availability_badge.dart';
import '../widgets/product_card_widget.dart';
import '../widgets/product_image_widget.dart';
import '../widgets/product_skeleton_widget.dart';
import '../widgets/app_motion.dart';
import '../widgets/guided_tour.dart';
import '../services/guide_coordinator.dart';
import 'homepage_screen.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  final Map<String, dynamic>? session;
  final ProductSortOption? initialSortOption;
  final bool guideVisible;
  final int guideReplay;

  const ProductsScreen({
    super.key,
    this.session,
    this.initialSortOption,
    this.guideVisible = true,
    this.guideReplay = 0,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _throttleNoticeShown = false;
  String? _expandedCategory;
  bool _showCategoryFilters = true;
  bool _showScrollToTop = false;
  double _lastScrollOffset = 0;
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppMotion.duration + AppMotion.staggerInterval * 3,
  );
  bool _entranceScheduled = false;

  bool get _canViewWholesalePrices {
    final session = widget.session ?? const <String, dynamic>{};
    final role = PermissionHelper.fromString(
      session['role']?.toString() ?? '',
    );
    final permission = session['can_view_wholesale_price'];
    return role == AppRole.admin ||
        role == AppRole.accountant ||
        permission == true ||
        permission == 1 ||
        permission == '1' ||
        permission == 'true';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleProductScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ProductsProvider>();
      _searchController.text = provider.searchQuery;
      if (widget.initialSortOption != null) {
        provider.setSortOption(widget.initialSortOption!);
      }
      unawaited(provider.fetchProducts());
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleProductScroll);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _handleProductScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final atTop = offset <= 0;
    final showScrollToTop = offset > 180;
    final showCategoryFilters = atTop || offset < _lastScrollOffset;
    _lastScrollOffset = offset;

    if (_showScrollToTop != showScrollToTop ||
        _showCategoryFilters != showCategoryFilters) {
      setState(() {
        _showScrollToTop = showScrollToTop;
        _showCategoryFilters = showCategoryFilters;
      });
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _fetchProducts() async {
    final provider = context.read<ProductsProvider>();
    await provider.fetchProducts(forceRefresh: true);
    if (!mounted || !provider.lastRefreshThrottled) return;

    if (_throttleNoticeShown) return;
    _throttleNoticeShown = true;
    final seconds = provider.manualRefreshRemaining.inSeconds;
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text(
              'يرجى الانتظار ${seconds > 0 ? '$seconds ثانية' : 'قليلًا'} قبل التحديث مجددًا',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        )
        .closed
        .then((_) {
      _throttleNoticeShown = false;
    });
  }

  Future<void> _changeViewMode(
    ProductsProvider provider,
    ProductViewMode mode,
  ) async {
    try {
      await provider.setViewMode(mode);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ طريقة العرض: $error')),
      );
    }
  }

  Widget _productTransition(
      Product product, Widget Function(VoidCallback) card) {
    final session = widget.session ??
        context.findAncestorStateOfType<HomePageState>()?.widget.session;
    final colors = Theme.of(context).colorScheme;
    return OpenContainer<void>(
      tappable: false,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.duration,
      closedElevation: 0,
      openElevation: 0,
      closedColor: colors.surface,
      openColor: colors.surface,
      closedShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      openBuilder: (_, __) =>
          ProductDetailScreen(product: product, session: session),
      closedBuilder: (_, open) => HeroMode(enabled: false, child: card(open)),
    );
  }

  void _showSortBottomSheet(ProductsProvider provider, bool canViewPrices) {
    final options = <(ProductSortOption, String, IconData)>[
      (ProductSortOption.name, 'الاسم: أ إلى ي', Icons.sort_by_alpha_rounded),
      if (provider.hasValidCreationDates)
        (
          ProductSortOption.newest,
          'الأحدث أولًا',
          Icons.schedule_rounded,
        ),
      if (canViewPrices) ...[
        (
          ProductSortOption.priceLowHigh,
          'السعر: الأقل أولًا',
          Icons.arrow_upward_rounded,
        ),
        (
          ProductSortOption.priceHighLow,
          'السعر: الأعلى أولًا',
          Icons.arrow_downward_rounded,
        ),
      ],
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Text(
                'ترتيب المنتجات',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final (option, title, icon) in options)
              _buildSortOption(
                sheetContext,
                provider,
                option,
                title,
                icon,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(
    BuildContext sheetContext,
    ProductsProvider provider,
    ProductSortOption option,
    String title,
    IconData icon,
  ) {
    final selected = provider.sortOption == option;
    final colors = Theme.of(sheetContext).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? colors.primary : colors.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? colors.primary : null,
          fontWeight: selected ? FontWeight.w700 : null,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colors.primary)
          : null,
      onTap: () {
        provider.setSortOption(option);
        Navigator.pop(sheetContext);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsProvider>();
    final session = widget.session ??
        context.findAncestorStateOfType<HomePageState>()?.widget.session;
    final userRole =
        PermissionHelper.fromString(session?['role']?.toString() ?? 'user');
    final canViewPrices = PermissionHelper.hasPermission(
          userRole,
          AppPermission.viewProductPrices,
        ) ||
        PermissionHelper.hasPermission(
          userRole,
          AppPermission.viewSellingPriceOnly,
        );
    final canViewStock = PermissionHelper.hasPermission(
      userRole,
      AppPermission.viewProductQuantities,
    );

    return GuidedTour(
      accountId: userRole == AppRole.customer
          ? (session ?? const <String, dynamic>{})['user_id']?.toString()
          : null,
      name: 'products',
      targetCount: 4,
      replay: widget.guideReplay,
      ready: widget.guideVisible &&
          !provider.isInitialLoading &&
          GuideCoordinator.ready,
      builder: (context, target) => Scaffold(
        body: Column(
          children: [
            _buildSearchHeader(provider, canViewPrices, target),
            if (provider.isLoading && !provider.isInitialLoading)
              const LinearProgressIndicator(minHeight: 2),
            if (provider.errorMessage != null && provider.products.isNotEmpty)
              _buildRefreshError(provider),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchProducts,
                displacement: 20,
                child: _buildContent(provider, canViewPrices, canViewStock),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(
    ProductsProvider provider,
    bool canViewPrices,
    GuideTarget target,
  ) {
    final theme = Theme.of(context);
    final selectedCategory = provider.selectedCategory;
    final expandedCategory = _expandedCategory ??
        (provider.selectedSubGroup != null ? selectedCategory : null);
    final activeFilters = <String>[
      if (provider.searchQuery.trim().isNotEmpty)
        'بحث: ${provider.searchQuery}',
      if (selectedCategory != null) selectedCategory,
      if (provider.selectedSubGroup != null) provider.selectedSubGroup!,
    ];

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'المنتجات',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: _showScrollToTop
                      ? IconButton(
                          key: const ValueKey('products-scroll-to-top'),
                          tooltip: 'العودة إلى أعلى القائمة',
                          onPressed: _scrollToTop,
                          icon: const Icon(Icons.keyboard_arrow_up_rounded),
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          visualDensity: VisualDensity.compact,
                        )
                      : const SizedBox(
                          key: ValueKey('products-scroll-to-top-hidden'),
                          width: 0,
                          height: 36,
                        ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${provider.products.length} منتج',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: target(
                    0,
                    'ابحث عن المنتج بالاسم أو الرمز أو رقم OEM.',
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 220),
                          () {
                            if (mounted) provider.setSearchQuery(value);
                          },
                        );
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم أو الرمز أو OEM',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'مسح البحث',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchDebounce?.cancel();
                                  _searchController.clear();
                                  provider.setSearchQuery('');
                                },
                              ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.55),
                          ),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                target(1, 'بدّل بين عرض البطاقات وعرض السطور حسب تفضيلك.',
                    _viewModeToggle(provider)),
                const SizedBox(width: 4),
                target(
                  2,
                  'رتّب النتائج بالاسم أو الخيارات المتاحة لحسابك.',
                  IconButton.filledTonal(
                    tooltip: 'ترتيب المنتجات',
                    onPressed: () =>
                        _showSortBottomSheet(provider, canViewPrices),
                    icon: const Icon(Icons.sort_rounded),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _showCategoryFilters
                  ? target(
                      3,
                      'اختر مجموعة لتضييق النتائج، ثم افتح المنتج للاطلاع عليه وإضافته للطلب.',
                      _buildCategoryFilters(provider, expandedCategory),
                    )
                  : const SizedBox(
                      width: double.infinity,
                      height: 0,
                    ),
            ),
            if (activeFilters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'الفلاتر:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    for (final filter in activeFilters)
                      InputChip(
                        label: Text(filter, maxLines: 1),
                        onDeleted: () {
                          if (filter.startsWith('بحث: ')) {
                            _searchController.clear();
                            provider.setSearchQuery('');
                          } else if (filter == provider.selectedSubGroup) {
                            provider.selectSubGroup(null);
                          } else if (filter == provider.selectedCategory) {
                            provider.selectCategory(null);
                            setState(() => _expandedCategory = null);
                          }
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        provider.resetFilters();
                        setState(() => _expandedCategory = null);
                      },
                      child: const Text('مسح الكل'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _viewModeToggle(ProductsProvider provider) {
    return SegmentedButton<ProductViewMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ProductViewMode.grid,
          icon: Icon(Icons.grid_view_rounded),
          tooltip: 'عرض البطاقات',
        ),
        ButtonSegment(
          value: ProductViewMode.list,
          icon: Icon(Icons.view_list_rounded),
          tooltip: 'عرض السطور',
        ),
      ],
      selected: {provider.viewMode},
      style: SegmentedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelectionChanged: (selection) {
        unawaited(_changeViewMode(provider, selection.first));
      },
    );
  }

  Widget _buildCategoryFilters(
    ProductsProvider provider,
    String? expandedCategory,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: ChoiceChip(
                  label: const Text('الكل'),
                  selected: provider.selectedCategory == null,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onSelected: (_) {
                    provider.selectCategory(null);
                    setState(() => _expandedCategory = null);
                  },
                ),
              ),
              for (final category in provider.categories)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChoiceChip(
                        label: Text(category),
                        selected: provider.selectedCategory == category,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onSelected: (_) {
                          provider.selectCategory(category);
                          setState(() => _expandedCategory = category);
                        },
                      ),
                      if (provider.getSubGroupsForCategory(category).isNotEmpty)
                        IconButton(
                          tooltip: expandedCategory == category
                              ? 'طي المجموعات الفرعية'
                              : 'عرض المجموعات الفرعية',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() {
                            _expandedCategory =
                                expandedCategory == category ? null : category;
                          }),
                          icon: AnimatedRotation(
                            turns: expandedCategory == category ? 0.5 : 0,
                            duration: const Duration(milliseconds: 160),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: provider.selectedCategory == category
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (expandedCategory != null &&
            provider.getSubGroupsForCategory(expandedCategory).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: ChoiceChip(
                      label: const Text('كل المجموعة'),
                      selected: provider.selectedSubGroup == null,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onSelected: (_) => provider.selectSubGroup(null),
                    ),
                  ),
                  for (final subGroup
                      in provider.getSubGroupsForCategory(expandedCategory))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: ChoiceChip(
                        label: Text(subGroup),
                        selected: provider.selectedSubGroup == subGroup,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onSelected: (_) {
                          provider.selectCategory(expandedCategory);
                          provider.selectSubGroup(subGroup);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRefreshError(ProductsProvider provider) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تعذر تحديث البيانات؛ ما زالت النتائج السابقة معروضة.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: _fetchProducts,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    ProductsProvider provider,
    bool canViewPrices,
    bool canViewStock,
  ) {
    if (provider.isInitialLoading) {
      return _buildSkeletonLoader(provider.viewMode);
    }

    if (provider.products.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      provider.errorMessage != null
                          ? Icons.cloud_off_outlined
                          : Icons.inventory_2_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      provider.errorMessage != null
                          ? 'تعذر تحميل المنتجات'
                          : provider.searchQuery.isEmpty &&
                                  provider.selectedCategory == null
                              ? 'لا توجد منتجات حالياً'
                              : 'لا توجد نتائج مطابقة',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (provider.errorMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        provider.errorMessage!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _fetchProducts,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ] else if (provider.searchQuery.isNotEmpty ||
                        provider.selectedCategory != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          provider.resetFilters();
                          setState(() => _expandedCategory = null);
                        },
                        child: const Text('مسح البحث والفلاتر'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!_entranceScheduled) {
      _entranceScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entrance.forward();
      });
    }

    if (provider.viewMode == ProductViewMode.grid) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final fontScale = MediaQuery.textScalerOf(context).scale(16) / 16;
          final columns = fontScale > 1.18 || constraints.maxWidth < 340
              ? 1
              : constraints.maxWidth >= 1000
                  ? 4
                  : constraints.maxWidth >= 680
                      ? 3
                      : 2;
          if (columns == 1) {
            return _buildProductList(
              provider,
              canViewPrices,
              canViewStock,
            );
          }
          return GridView.builder(
            key: const PageStorageKey<String>('product-grid'),
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: columns == 2 ? 0.66 : 0.78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: provider.products.length,
            itemBuilder: (context, index) {
              final product = provider.products[index];
              return InitialListEntrance(
                animation: _entrance,
                index: index,
                child: _productTransition(
                  product,
                  (open) => ProductCardWidget(
                    product: product,
                    canViewPrice: canViewPrices,
                    canViewWholesale: _canViewWholesalePrices,
                    onTap: open,
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return _buildProductList(provider, canViewPrices, canViewStock);
  }

  Widget _buildProductList(
    ProductsProvider provider,
    bool canViewPrices,
    bool canViewStock,
  ) {
    return ListView.separated(
      key: const PageStorageKey<String>('product-list'),
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: provider.products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final product = provider.products[index];
        return InitialListEntrance(
          animation: _entrance,
          index: index,
          child: _productTransition(
            product,
            (open) =>
                _buildListTile(
                  product,
                  canViewPrices,
                  canViewStock,
                  open,
                  canViewWholesale: _canViewWholesalePrices,
                ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLoader(ProductViewMode mode) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (mode == ProductViewMode.grid &&
            constraints.maxWidth >= 340 &&
            MediaQuery.textScalerOf(context).scale(16) / 16 <= 1.18) {
          final columns = constraints.maxWidth >= 1000
              ? 4
              : constraints.maxWidth >= 680
                  ? 3
                  : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: columns == 2 ? 0.66 : 0.78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: columns * 3,
            itemBuilder: (_, __) => const ProductSkeletonWidget(isGrid: true),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          itemCount: 6,
          itemBuilder: (_, __) => const ProductSkeletonWidget(isGrid: false),
        );
      },
    );
  }

  Widget _buildListTile(
    Product product,
    bool canViewPrices,
    bool canViewStock,
    VoidCallback onTap,
    {required bool canViewWholesale}
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final availability = productAvailabilityFrom(
      value: product.availabilityStatus,
    );
    final heroTag = product.id != null || product.code.isNotEmpty
        ? 'product_image_${product.id ?? product.code}'
        : null;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: ProductImageWidget(
                    imageUrl: product.imageUrl,
                    width: 84,
                    height: 84,
                    fit: BoxFit.contain,
                    heroTag: heroTag,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name.trim().isEmpty
                          ? 'منتج بدون اسم'
                          : product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الرمز: ${product.code.trim().isEmpty ? '—' : product.code}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ProductAvailabilityBadge(
                          availability: availability,
                          compact: true,
                        ),
                        if (canViewPrices)
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
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: product.priceConfigured
                                  ? colors.primary
                                  : colors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (canViewWholesale &&
                            product.wholesalePrice != null)
                          Text(
                            'الجملة: ${formatMoneyShort(product.wholesalePrice!, currency: product.currency)}',
                            style: theme.textTheme.labelMedium?.copyWith(
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
              const SizedBox(width: 4),
              Icon(Icons.chevron_left_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
