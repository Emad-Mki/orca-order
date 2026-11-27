import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../order_status_mapper.dart';
import 'order_details_screen.dart';
import 'new_order_screen.dart';
import 'sales_invoice_screen.dart';
import '../utils/permissions.dart';
import '../providers/orders_provider.dart';
import '../widgets/order_skeleton.dart';
import '../utils/number_utils.dart';
import '../widgets/app_motion.dart';

class OrdersScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  final String? customerId;
  final bool motionVisible;
  const OrdersScreen(
      {super.key,
      required this.session,
      this.customerId,
      this.motionVisible = true});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with TickerProviderStateMixin {
  String? _selectedCustomerId;
  String _currentStatusFilter = 'all';
  late TabController _tabController;
  late final List<String> _statusTabs;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _customers = [];
  DateTime? _lastRefreshNotice;
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppMotion.duration + AppMotion.staggerInterval * 3,
  );
  bool _entranceScheduled = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.customerId;
    final provider = context.read<OrdersProvider>();
    final isWarehouse = PermissionHelper.fromString(
            widget.session['role']?.toString() ?? 'user') ==
        AppRole.warehouse;
    _statusTabs = isWarehouse
        ? [
            'all',
            OrderStatusMapper.approved,
            OrderStatusMapper.preparing,
            OrderStatusMapper.readyForShipping,
            OrderStatusMapper.completed,
          ]
        : [
            'all',
            OrderStatusMapper.processing,
            OrderStatusMapper.priced,
            OrderStatusMapper.approved,
            OrderStatusMapper.preparing,
            OrderStatusMapper.readyForShipping,
            OrderStatusMapper.completed,
            OrderStatusMapper.cancelled,
          ];
    _currentStatusFilter = _statusTabs.contains(provider.currentFilter)
        ? provider.currentFilter
        : 'all';
    if (_currentStatusFilter != provider.currentFilter) {
      provider.setFilter(_currentStatusFilter);
    }
    _searchController.text = provider.searchQuery;
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    final initialTab = _statusTabs.indexOf(_currentStatusFilter);
    if (initialTab >= 0) _tabController.index = initialTab;
    _fetchCustomers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshOrders(force: true, bypassMinimumInterval: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _entrance.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    final role = PermissionHelper.fromString(
        widget.session['role']?.toString() ?? 'user');
    if (!PermissionHelper.hasPermission(role, AppPermission.viewAllOrders)) {
      return;
    }
    try {
      final data = await ApiService().customers.getCustomers();
      if (mounted) {
        setState(() {
          _customers = data['customers'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    }
  }

  Future<void> _refreshOrders({
    bool force = false,
    bool bypassMinimumInterval = false,
  }) async {
    final provider = Provider.of<OrdersProvider>(context, listen: false);
    await provider.fetchOrders(
      forceRefresh: force,
      bypassMinimumInterval: bypassMinimumInterval,
    );
    if (!mounted) return;
    if (force && provider.lastRefreshThrottled) {
      final now = DateTime.now();
      if (_lastRefreshNotice == null ||
          now.difference(_lastRefreshNotice!) >=
              OrdersProvider.minimumManualRefreshInterval) {
        _lastRefreshNotice = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى الانتظار 15 ثانية بين التحديثات')),
        );
      }
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentStatusFilter = _statusTabs[index];
    });
    Provider.of<OrdersProvider>(context, listen: false)
        .setFilter(_currentStatusFilter);
  }

  Future<void> _pickDateRange(OrdersProvider provider) async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: provider.fromDate != null || provider.toDate != null
          ? DateTimeRange(
              start: provider.fromDate ?? provider.toDate!,
              end: provider.toDate ?? provider.fromDate!,
            )
          : null,
      helpText: 'تصفية الطلبات حسب التاريخ',
      cancelText: 'إلغاء',
      confirmText: 'تطبيق',
    );
    if (selected != null) {
      provider.setDateRange(from: selected.start, to: selected.end);
    }
  }

  void _showCustomerFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر الزبون'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _customers.length,
            itemBuilder: (context, index) {
              final customer = _customers[index];
              return ListTile(
                title: Text(customer['full_name'] ?? customer['name'] ?? ''),
                subtitle: Text(customer['company_name'] ?? ''),
                onTap: () {
                  setState(() {
                    _selectedCustomerId =
                        customer['customer_id'] ?? customer['id'];
                  });
                  Navigator.pop(context);
                  // In a real scenario, we might need to update the provider to filter by customer
                  // For now, let's assume local filtering or re-fetch
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCustomerId = null;
              });
              Navigator.pop(context);
            },
            child: const Text('عرض الكل'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    return Color(OrderStatusMapper.getStatusColorHex(status));
  }

  String _getStatusText(String? status) {
    return OrderStatusMapper.getArabicStatus(status);
  }

  @override
  Widget build(BuildContext context) {
    final roleString =
        widget.session['role']?.toString().toLowerCase() ?? 'user';
    final userRole = PermissionHelper.fromString(roleString);
    final canViewAll =
        PermissionHelper.hasPermission(userRole, AppPermission.viewAllOrders);
    final canCreateOrder =
        PermissionHelper.hasPermission(userRole, AppPermission.createOrder);
    final canCreateInvoice = (userRole == AppRole.admin ||
            userRole == AppRole.manager ||
            userRole == AppRole.accountant) &&
        PermissionHelper.hasPermission(userRole, AppPermission.createCashSale);
    final canViewPrice = PermissionHelper.hasPermission(
            userRole, AppPermission.viewProductPrices) ||
        PermissionHelper.hasPermission(
            userRole, AppPermission.viewSellingPriceOnly);
    final canViewAccountingInvoiceNo = const {
      AppRole.admin,
      AppRole.manager,
      AppRole.accountant,
    }.contains(userRole);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات'),
        actions: [
          if (canViewAll && widget.customerId == null)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showCustomerFilterDialog,
              tooltip: 'فلترة حسب الزبون',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshOrders(force: true),
            tooltip: 'تحديث',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      Provider.of<OrdersProvider>(context, listen: false)
                          .setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'بحث برقم الطلب أو اسم الزبون...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                onTap: _onTabSelected,
                isScrollable: true,
                tabs: _statusTabs.map((status) {
                  return Tab(
                      text: status == 'all'
                          ? 'الكل'
                          : OrderStatusMapper.getArabicStatus(status));
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: MediaQuery.viewInsetsOf(context).bottom > 0 ||
              (!canCreateOrder && !canCreateInvoice)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (canCreateInvoice) ...[
                  FloatingActionButton.extended(
                    heroTag: 'new-sales-invoice',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SalesInvoiceScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('فاتورة جديدة'),
                  ),
                  if (canCreateOrder) const SizedBox(height: 12),
                ],
                if (canCreateOrder)
                  FloatingActionButton.extended(
                    heroTag: 'new-order',
                    onPressed: () {
                      final ordersProvider = context.read<OrdersProvider>();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                NewOrderScreen(session: widget.session)),
                      ).then((created) {
                        if (created == true && mounted) {
                          ordersProvider.syncAfterMutation();
                        }
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('طلب جديد'),
                  ),
              ],
            ),
      body: Consumer<OrdersProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.orders.isEmpty) {
            return const OrderListSkeleton();
          }

          if (provider.errorMessage != null && provider.orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('خطأ: ${provider.errorMessage}'),
                  ElevatedButton(
                      onPressed: () => _refreshOrders(force: true),
                      child: const Text('إعادة المحاولة')),
                ],
              ),
            );
          }

          final warehouseOnly = userRole == AppRole.warehouse
              ? provider.orders.where((order) =>
                  OrderStatusMapper.isVisibleToWarehouse(order.status))
              : provider.orders;
          final filteredOrders = _selectedCustomerId != null
              ? warehouseOnly
                  .where((o) => o.customerId == _selectedCustomerId)
                  .toList()
              : warehouseOnly.toList();

          if (widget.motionVisible &&
              filteredOrders.isNotEmpty &&
              !_entranceScheduled) {
            _entranceScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _entrance.forward();
            });
          }

          return RefreshIndicator(
            onRefresh: () => _refreshOrders(force: true),
            child: CustomScrollView(
              key: const PageStorageKey<String>('orders-list'),
              slivers: [
                if (provider.isLoading)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('عدد الطلبات: ${filteredOrders.length}',
                            style: Theme.of(context).textTheme.labelLarge),
                        PopupMenuButton<String>(
                          onSelected: (choice) {
                            final now = DateTime.now();
                            if (choice == 'today') {
                              provider.setDateRange(
                                from: DateTime(now.year, now.month, now.day),
                                to: now,
                              );
                            } else if (choice == 'month') {
                              provider.setDateRange(
                                from: DateTime(now.year, now.month),
                                to: now,
                              );
                            } else if (choice == 'custom') {
                              _pickDateRange(provider);
                            } else {
                              provider.setDateRange();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'today', child: Text('اليوم')),
                            PopupMenuItem(
                                value: 'month', child: Text('هذا الشهر')),
                            PopupMenuItem(
                                value: 'custom', child: Text('فترة مخصصة')),
                            PopupMenuItem(
                                value: 'clear', child: Text('مسح الفترة')),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Theme.of(context).colorScheme.outline),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.date_range, size: 18),
                                const SizedBox(width: 6),
                                Text(provider.fromDate == null &&
                                        provider.toDate == null
                                    ? 'الفترة'
                                    : 'تغيير الفترة'),
                              ],
                            ),
                          ),
                        ),
                        PopupMenuButton<OrderSortOption>(
                          tooltip: 'ترتيب الطلبات',
                          initialValue: provider.sortOption,
                          onSelected: provider.setSortOption,
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: OrderSortOption.newest,
                              child: Text('الأحدث أولاً'),
                            ),
                            const PopupMenuItem(
                              value: OrderSortOption.oldest,
                              child: Text('الأقدم أولاً'),
                            ),
                            if (canViewPrice) ...const [
                              PopupMenuItem(
                                value: OrderSortOption.valueHighToLow,
                                child: Text('الأعلى قيمة'),
                              ),
                              PopupMenuItem(
                                value: OrderSortOption.valueLowToHigh,
                                child: Text('الأقل قيمة'),
                              ),
                            ],
                          ],
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.sort),
                          ),
                        ),
                        if (_selectedCustomerId != null &&
                            widget.customerId == null)
                          InputChip(
                            label: const Text('زبون محدد'),
                            onDeleted: () =>
                                setState(() => _selectedCustomerId = null),
                          ),
                        if (provider.currentFilter != 'all')
                          InputChip(
                            label: Text(OrderStatusMapper.getArabicStatus(
                                provider.currentFilter)),
                            onDeleted: () {
                              provider.setFilter('all');
                              _currentStatusFilter = 'all';
                              _tabController.animateTo(0);
                            },
                          ),
                        if (provider.searchQuery.isNotEmpty)
                          InputChip(
                            label: Text('بحث: ${provider.searchQuery}'),
                            onDeleted: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          ),
                        if (provider.fromDate != null ||
                            provider.toDate != null)
                          InputChip(
                            label: const Text('فترة محددة'),
                            onDeleted: () => provider.setDateRange(),
                          ),
                        if (provider.currentFilter != 'all' ||
                            provider.searchQuery.isNotEmpty ||
                            provider.fromDate != null ||
                            provider.toDate != null)
                          TextButton(
                            onPressed: () {
                              provider.resetFilters();
                              setState(() =>
                                  _selectedCustomerId = widget.customerId);
                              _searchController.clear();
                              _currentStatusFilter = 'all';
                              _tabController.animateTo(0);
                            },
                            child: const Text('مسح الفلاتر'),
                          ),
                      ],
                    ),
                  ),
                ),
                if (provider.errorMessage != null)
                  SliverToBoxAdapter(
                    child: MaterialBanner(
                      content: Text(
                        'تعذر تحديث الطلبات. ${provider.errorMessage}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => _refreshOrders(force: true),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                if (filteredOrders.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text(provider.searchQuery.isNotEmpty ||
                                  provider.fromDate != null ||
                                  provider.toDate != null
                              ? 'لا توجد نتائج مطابقة للفلاتر'
                              : 'لا توجد طلبات في هذه المرحلة'),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final order = filteredOrders[index];
                        final isNew = order.isNew;

                        return InitialListEntrance(
                          animation: _entrance,
                          index: index,
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final ordersProvider =
                                    context.read<OrdersProvider>();
                                final refresh = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderDetailsScreen(
                                      orderId: order.orderId,
                                      session: widget.session,
                                    ),
                                  ),
                                );
                                if (!mounted) return;
                                if (refresh == true) {
                                  await ordersProvider.syncAfterMutation(
                                    orderId: order.orderId,
                                    status: 'cancelled',
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (isNew)
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle),
                                            margin:
                                                const EdgeInsets.only(left: 8),
                                          ),
                                        Expanded(
                                          child: Text(
                                            order.orderNumber,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                        ),
                                        _buildStatusBadge(order.status),
                                      ],
                                    ),
                                    if (canViewAccountingInvoiceNo &&
                                        order.accountingInvoiceNo
                                                ?.trim()
                                                .isNotEmpty ==
                                            true)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'الفاتورة المحاسبية: ${order.accountingInvoiceNo}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    if (canViewAll) ...[
                                      Row(
                                        children: [
                                          Icon(Icons.person,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(order.customerName,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 14,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant),
                                            const SizedBox(width: 4),
                                            Text(
                                              order.createdAt != null
                                                  ? _formatDate(
                                                      order.createdAt!)
                                                  : '---',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                        if (order.totalAmount != null &&
                                            canViewPrice)
                                          Text(
                                            formatMoneyShort(
                                              order.totalAmount!,
                                              currency: order.currency,
                                            ),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filteredOrders.length,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                      height: canCreateInvoice && canCreateOrder ? 160 : 90),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _getStatusText(status),
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
