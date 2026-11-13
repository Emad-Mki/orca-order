import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';
import '../utils/permissions.dart';
import '../widgets/product_image_widget.dart';
import 'product_detail_screen.dart';
import 'products_screen.dart';

/// لوحة التحكم الرئيسية المخصصة حسب دور المستخدم
class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  final AppRole userRole;

  const DashboardScreen({
    super.key,
    required this.session,
    required this.userRole,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final List<dynamic> _stats = [];
  List<Product> _latestProducts = [];
  List<Product> _bestSellers = [];
  bool _latestLoading = true;
  bool _bestSellersLoading = true;
  bool _isRefreshing = false;
  bool _financialLoading = true;
  String? _latestError;
  String? _bestSellersError;
  String? _financialError;
  Map<String, dynamic> _financialSummary = {};
  Future<void>? _loadRequest;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runLoad(manual: false, forceProductsRefresh: false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _shimmerController
        ..stop()
        ..value = 0.5;
    } else if (!_shimmerController.isAnimating) {
      _shimmerController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _refreshAllData() =>
      _runLoad(manual: true, forceProductsRefresh: true);

  void _showRefreshThrottled(Duration remaining) {
    if (!mounted || !ApiService().products.shouldShowRefreshThrottleNotice()) {
      return;
    }
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'يرجى الانتظار قليلًا قبل التحديث مجددًا'
          '${seconds > 0 ? ' (باقي $seconds ثانية)' : ''}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _runLoad({
    required bool manual,
    required bool forceProductsRefresh,
    Future<void> Function()? operation,
  }) {
    final activeRequest = _loadRequest;
    if (activeRequest != null) return activeRequest;

    final loadTimer = Stopwatch()..start();
    if (mounted && manual) setState(() => _isRefreshing = true);
    final request = Future<void>.microtask(() async {
      if (operation != null) {
        await operation();
        return;
      }
      await Future.wait([
        _loadLatestProducts(forceRefresh: manual),
        _loadBestSellers(forceRefresh: manual),
        if (widget.userRole != AppRole.customer &&
            widget.userRole != AppRole.salesperson)
          _fetchDashboardStats(),
        if (widget.userRole == AppRole.customer) _fetchFinancialSummary(),
        _loadProductCatalog(forceRefresh: forceProductsRefresh),
      ]);
    });
    _loadRequest = request;

    return request.whenComplete(() {
      if (identical(_loadRequest, request)) _loadRequest = null;
      if (mounted && manual) setState(() => _isRefreshing = false);
      if (!manual && kDebugMode) {
        debugPrint(
            'home_initial_data_load_ms=${loadTimer.elapsedMilliseconds}');
      }
    });
  }

  Future<void> _loadProductCatalog({required bool forceRefresh}) async {
    await context
        .read<ProductsProvider>()
        .fetchProducts(forceRefresh: forceRefresh);
  }

  List<Product> _parseProducts(Map<String, dynamic> response) {
    final nestedData = response['data'];
    final rawProducts = response['products'] ??
        (nestedData is Map ? nestedData['products'] : null);
    if (rawProducts is! List) return [];
    return rawProducts
        .whereType<Map>()
        .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _loadLatestProducts({bool forceRefresh = false}) async {
    if (_latestProducts.isEmpty && mounted) {
      setState(() {
        _latestLoading = true;
        _latestError = null;
      });
    }
    try {
      final response = await ApiService()
          .products
          .getNewProducts(forceRefresh: forceRefresh);
      if (forceRefresh &&
          ApiService().products.wasRefreshThrottled('new_products')) {
        _showRefreshThrottled(
          ApiService().products.refreshRemaining('new_products'),
        );
      }
      final products = _parseProducts(response)
        ..removeWhere((product) => product.createdAt == null)
        ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      if (mounted) {
        setState(() {
          _latestProducts = products.take(10).toList();
          _latestError = null;
        });
      }
    } catch (error) {
      if (error is ApiException && error.code == 'REFRESH_THROTTLED') {
        _showRefreshThrottled(
          ApiService().products.refreshRemaining('new_products'),
        );
        return;
      }
      if (mounted) setState(() => _latestError = error.toString());
    } finally {
      if (mounted) setState(() => _latestLoading = false);
    }
  }

  Future<void> _loadBestSellers({bool forceRefresh = false}) async {
    if (_bestSellers.isEmpty && mounted) {
      setState(() {
        _bestSellersLoading = true;
        _bestSellersError = null;
      });
    }
    try {
      final response = await ApiService()
          .products
          .getBestSellers(forceRefresh: forceRefresh);
      if (forceRefresh &&
          ApiService().products.wasRefreshThrottled('best_sellers')) {
        _showRefreshThrottled(
          ApiService().products.refreshRemaining('best_sellers'),
        );
      }
      final products = _parseProducts(response);
      if (mounted) {
        setState(() {
          _bestSellers = products;
          _bestSellersError = null;
        });
      }
    } catch (error) {
      if (error is ApiException && error.code == 'REFRESH_THROTTLED') {
        _showRefreshThrottled(
          ApiService().products.refreshRemaining('best_sellers'),
        );
        return;
      }
      if (mounted) setState(() => _bestSellersError = error.toString());
    } finally {
      if (mounted) setState(() => _bestSellersLoading = false);
    }
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final data = await ApiService().post({
        'action': 'getDashboardStats',
        'token': widget.session['token'],
      });
      if (mounted && data['success'] == true) {
        final stats = data['stats'];
        setState(() {
          _stats
            ..clear()
            ..addAll(stats is List ? stats : const []);
        });
      }
    } catch (error) {
      debugPrint('Error fetching dashboard stats: $error');
    }
  }

  Future<void> _fetchFinancialSummary() async {
    if (_financialSummary.isEmpty && mounted) {
      setState(() {
        _financialLoading = true;
        _financialError = null;
      });
    }
    try {
      final data = await ApiService().post({
        'action': 'getCustomerStatement',
        'customer_id': widget.session['customer_id'],
        'token': widget.session['token'],
      });
      if (mounted && data['success'] == true) {
        setState(() {
          _financialSummary = {
            'balance': data['finalBalance'],
            'currency': 'USD',
          };
          _financialError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _financialError = error.toString());
      debugPrint('Error fetching financial summary: $error');
    } finally {
      if (mounted) setState(() => _financialLoading = false);
    }
  }

  Future<void> _retrySection(Future<void> Function() loadSection) {
    return _runLoad(
      manual: true,
      forceProductsRefresh: false,
      operation: loadSection,
    );
  }

  void _showAllProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('المنتجات')),
          body: ProductsScreen(
            session: widget.session,
            initialSortOption: ProductSortOption.newest,
          ),
        ),
      ),
    );
  }

  void _openProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          session: widget.session,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        (widget.session['full_name'] ?? widget.session['username'] ?? 'مستخدم')
            .toString();

    return RefreshIndicator(
      onRefresh: _refreshAllData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          if (_isRefreshing) const LinearProgressIndicator(minHeight: 2),
          _buildWelcomeCard(userName),
          if (widget.userRole == AppRole.customer) ...[
            const SizedBox(height: 16),
            _buildFinancialMiniCard(),
          ] else if (_stats.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildQuickStatsGrid(),
          ],
          const SizedBox(height: 22),
          _buildSectionHeader(
            'أحدث المنتجات',
            action: TextButton(
              onPressed: _showAllProducts,
              child: const Text('عرض الكل'),
            ),
          ),
          const SizedBox(height: 8),
          _buildProductSection(
            products: _latestProducts,
            loading: _latestLoading,
            error: _latestError,
            emptyMessage: 'لا توجد منتجات بتاريخ إضافة موثق حتى الآن.',
            retry: () => _retrySection(
              () => _loadLatestProducts(forceRefresh: true),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('الأكثر طلبًا'),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
            child: Text(
              'حسب إجمالي الوحدات المعتمدة أو المجهزة خلال آخر 30 يومًا',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _buildProductSection(
            products: _bestSellers,
            loading: _bestSellersLoading,
            error: _bestSellersError,
            emptyMessage: 'لا توجد بيانات كافية لعرض المنتجات الأكثر طلبًا.',
            retry: () => _retrySection(
              () => _loadBestSellers(forceRefresh: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(String userName) {
    final theme = Theme.of(context);
    final initial = userName.isEmpty ? 'م' : userName.substring(0, 1);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أهلاً بك، $userName',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    PermissionHelper.getRoleDescriptionAr(widget.userRole),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? action}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildProductSection({
    required List<Product> products,
    required bool loading,
    required String? error,
    required String emptyMessage,
    required VoidCallback retry,
  }) {
    if (loading && products.isEmpty) return _buildSkeletonProducts();
    if (products.isEmpty && error != null) {
      return _buildSectionError(error, retry);
    }
    if (products.isEmpty) {
      return _buildEmptyState(emptyMessage);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) _buildInlineError(error, retry),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _ProductCard(
              product: products[index],
              onTap: () => _openProduct(products[index]),
              showPrice: PermissionHelper.hasAnyPermission(
                widget.userRole,
                {
                  AppPermission.viewProductPrices,
                  AppPermission.viewSellingPriceOnly,
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonProducts() {
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => SizedBox(
          width: 156,
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, _) {
                final opacity = 0.30 + (_shimmerController.value * 0.18);
                final color = Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: opacity);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: ColoredBox(color: color)),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: 115,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Container(
                            height: 12,
                            width: 72,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionError(String error, VoidCallback retry) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(child: Text('تعذر تحميل البيانات. $error')),
            TextButton(onPressed: retry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineError(String error, VoidCallback retry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.orange),
          const SizedBox(width: 6),
          const Expanded(child: Text('تعذر تحديث البيانات؛ المعروض محفوظ.')),
          Tooltip(
            message: error,
            child: TextButton(
              onPressed: retry,
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        child: Row(
          children: [
            Icon(Icons.inventory_2_outlined,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialMiniCard() {
    if (_financialSummary.isEmpty && _financialLoading) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: LinearProgressIndicator(),
        ),
      );
    }
    if (_financialSummary.isEmpty && _financialError != null) {
      return _buildSectionError(
        _financialError!,
        () => _retrySection(_fetchFinancialSummary),
      );
    }

    final balance = _financialSummary['balance'];
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.account_balance_wallet_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('الرصيد الحالي'),
            subtitle: const Text('الملخص المالي'),
            trailing: Text(
              balance == null
                  ? 'غير متاح'
                  : '$balance ${_financialSummary['currency'] ?? 'USD'}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          if (_financialError != null)
            _buildInlineError(
              _financialError!,
              () => _retrySection(_fetchFinancialSummary),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final stat = _stats[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stat['title']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  stat['value']?.toString() ?? '0',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final bool showPrice;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.showPrice,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.all(8),
                  child: product.imageUrl?.isNotEmpty == true
                      ? ProductImageWidget(
                          imageUrl: product.imageUrl,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        )
                      : Icon(
                          Icons.inventory_2_outlined,
                          size: 42,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (showPrice && product.price > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${product.price.toStringAsFixed(2)} ${product.currency}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
