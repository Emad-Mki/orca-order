import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../order_status_mapper.dart';
import 'order_details_screen.dart';
import 'new_order_screen.dart';
import '../utils/permissions.dart';

class OrdersScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const OrdersScreen({super.key, required this.session});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _orders = [];
  List<dynamic> _allOrders = [];
  bool _isLoading = true;
  String? _selectedCustomerId;
  String _currentStatusFilter = OrderStatusMapper.processing;
  late TabController _tabController;
  final List<String> _statusTabs = [
    OrderStatusMapper.processing,
    OrderStatusMapper.priced,
    OrderStatusMapper.approved,
    OrderStatusMapper.preparing,
    OrderStatusMapper.readyForShipping,
    OrderStatusMapper.completed,
    OrderStatusMapper.cancelled,
  ];

  // قائمة الزبائن للفلترة
  List<dynamic> _customers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _fetchCustomers();
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    try {
      final data = await ApiService().post({
        'action': 'getCustomers',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        setState(() {
          _customers = data['customers'] ?? [];
        });
      }
    } catch (e) {
      print('Error fetching customers: $e');
    }
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> params = {
        'action': 'getOrders',
        'username': widget.session['username'],
        'token': widget.session['token'],
      };

      // إضافة فلترة الزبون إذا تم اختياره
      if (_selectedCustomerId != null) {
        params['customer_id'] = _selectedCustomerId;
      }

      final data = await ApiService().post(params);
      var list =
          data['orders'] ?? data['data'] ?? data['items'] ?? data['result'];
      if (mounted) {
        setState(() {
          _allOrders = list is List ? list : [];
          // ترتيب حسب الأحدث أولاً
          _allOrders.sort((a, b) {
            final dateA = a['created_at'] ?? a['date'] ?? '';
            final dateB = b['created_at'] ?? b['date'] ?? '';
            return dateB.toString().compareTo(dateA.toString());
          });
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في تحميل الطلبات: $e'),
          backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _orders = _allOrders.where((order) {
        final status = order['status']?.toString().toLowerCase() ?? '';
        final normalizedStatus = OrderStatusMapper.normalizeStatus(status);
        return normalizedStatus == _currentStatusFilter;
      }).toList();
    });
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentStatusFilter = _statusTabs[index];
      _applyFilters();
    });
  }

  // تعليم الطلب كمقروء
  Future<void> _markOrderAsRead(String orderId) async {
    try {
      await ApiService().post({
        'action': 'markOrderAsRead',
        'order_id': orderId,
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
    } catch (e) {
      print('Error marking order as read: $e');
    }
  }

  bool _canCancelOrder(Map<String, dynamic> order) {
    final role = PermissionHelper.fromString(
      widget.session['role']?.toString() ?? '',
    );
    final status = (order['status'] ?? '').toString().trim().toLowerCase();
    if (status == 'cancelled' || status == 'deleted') return false;
    if (role == AppRole.admin ||
        role == AppRole.manager ||
        role == AppRole.accountant) {
      return true;
    }
    return role == AppRole.customer &&
        ['pending', 'submitted', 'processing', 'customer_changed', 'priced']
            .contains(status);
  }

  Future<void> _showOrderActions(Map<String, dynamic> order) async {
    if (!_canCancelOrder(order)) return;
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إجراءات الفاتورة'),
        content: const Text('يمكنك إلغاء هذه الفاتورة ونقلها إلى قسم الملغاة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إغلاق'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('إلغاء فاتورة'),
          ),
        ],
      ),
    );
    if (shouldCancel == true && mounted) {
      await _cancelOrder(order);
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد إلغاء الفاتورة'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'سبب الإلغاء (اختياري)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('رجوع'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null) return;

    try {
      final orderId = (order['order_id'] ?? order['id'] ?? '').toString();
      await ApiService().orders.cancelOrder(orderId, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الفاتورة ونقلها إلى الملغاة')),
      );
      await _fetchOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إلغاء الفاتورة: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // عرض حوار اختيار الزبون
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
                  _fetchOrders();
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
              _fetchOrders();
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
    final canViewPrice = PermissionHelper.hasPermission(
            userRole, AppPermission.viewProductPrices) ||
        PermissionHelper.hasPermission(
            userRole, AppPermission.viewSellingPriceOnly);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات'),
        actions: [
          if (canViewAll)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showCustomerFilterDialog,
              tooltip: 'فلترة حسب الزبون',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrders,
            tooltip: 'تحديث',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'new_order') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => NewOrderScreen(session: widget.session)),
                ).then((_) => _fetchOrders());
              }
            },
            itemBuilder: (context) => [
              if (canCreateOrder)
                const PopupMenuItem(
                  value: 'new_order',
                  child: ListTile(
                    leading: Icon(Icons.add_shopping_cart),
                    title: Text('طلب جديد'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: _onTabSelected,
          isScrollable: true,
          tabs: _statusTabs.map((status) {
            final count = _allOrders
                .where((o) =>
                    OrderStatusMapper.normalizeStatus(
                        o['status']?.toString().toLowerCase()) ==
                    status)
                .length;
            return Tab(
              text: '${OrderStatusMapper.getArabicStatus(status)} ($count)',
            );
          }).toList(),
        ),
      ),
      floatingActionButton: canCreateOrder
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => NewOrderScreen(session: widget.session)),
                ).then((_) => _fetchOrders());
              },
              icon: const Icon(Icons.add),
              label: const Text('طلب جديد'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedCustomerId != null
                            ? 'لا توجد طلبات لهذا الزبون'
                            : 'لا توجد طلبات في هذه المرحلة',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (canCreateOrder)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      NewOrderScreen(session: widget.session)),
                            ).then((_) => _fetchOrders());
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('أنشئ أول طلب الآن'),
                        ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.only(bottom: 80), // Avoid FAB overlap
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      final isNew = order['is_new'] == true ||
                          order['is_read'] == false ||
                          order['is_read'] == '0' ||
                          order['is_read'] == 'false';
                      final orderId =
                          (order['order_id'] ?? order['id'] ?? '').toString();
                      final orderDate =
                          order['created_at'] ?? order['date'] ?? '';
                      final customerName = order['customer_name'] ??
                          order['full_name'] ??
                          order['username'] ??
                          'زبون';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: InkWell(
                          onTap: () async {
                            // تعليم الطلب كمقروء
                            if (isNew && canViewAll) {
                              _markOrderAsRead(orderId);
                            }
                            final refresh = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailsScreen(
                                  orderId: orderId,
                                  session: widget.session,
                                ),
                              ),
                            );
                            if (refresh == true) _fetchOrders();
                          },
                          onLongPress: () => _showOrderActions(
                            Map<String, dynamic>.from(order as Map),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // النقطة الخضراء للطلبات الجديدة
                                    if (isNew && canViewAll)
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        margin: const EdgeInsets.only(left: 8),
                                      ),
                                    Expanded(
                                      child: Text(
                                        'طلب #${orderId.padLeft(4, '0')}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(order['status'])
                                            .withAlpha(30),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getStatusText(order['status']),
                                        style: TextStyle(
                                          color:
                                              _getStatusColor(order['status']),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      customerName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      orderDate.isNotEmpty
                                          ? _formatDate(orderDate)
                                          : 'غير محدد',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                if (order['total_amount'] != null &&
                                    canViewPrice)
                                  const SizedBox(height: 4),
                                if (order['total_amount'] != null &&
                                    canViewPrice)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.attach_money,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '\$${order['total_amount']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
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
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
