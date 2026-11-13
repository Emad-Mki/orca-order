import 'package:flutter/material.dart';
import 'dart:async';
import '../models/order.dart';
import '../repositories/order_repository.dart';
import 'order_details_screen.dart';

/// شاشة طلبات التحضير - تعرض الطلبات الجاهزة للتجهيز في المستودع
/// الحالات: approved, preparing, ready_for_shipping
class PreparationOrdersScreen extends StatefulWidget {
  const PreparationOrdersScreen({super.key});

  @override
  State<PreparationOrdersScreen> createState() =>
      _PreparationOrdersScreenState();
}

class _PreparationOrdersScreenState extends State<PreparationOrdersScreen> {
  final OrderRepository _orderRepository = OrderRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = false;
  String? _error;
  String _selectedFilter = 'all'; // all, approved, preparing, prepared

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// جلب طلبات التحضير من الخادم
  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // جلب الطلبات بالحالات المتعلقة بالتجهيز
      final preparationStatuses = ['approved', 'preparing', 'prepared'];
      final List<Order> allPreparationOrders = [];

      for (var status in preparationStatuses) {
        try {
          final orders = await _orderRepository.getOrders(status: status);
          allPreparationOrders.addAll(orders);
        } catch (e) {
          print('Error fetching $status orders: $e');
        }
      }

      // إزالة التكرارات بناءً على orderId
      final uniqueOrders = <String, Order>{};
      for (var order in allPreparationOrders) {
        uniqueOrders[order.orderId] = order;
      }

      setState(() {
        _allOrders = uniqueOrders.values.toList();
        _filterOrders();
      });
    } catch (e) {
      setState(() {
        _error = 'فشل تحميل طلبات التحضير: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// فلترة الطلبات حسب البحث والفيلتر المختار
  void _filterOrders() {
    final query = _searchController.text.toLowerCase();

    var filtered = _allOrders.where((order) {
      // فلترة حسب الحالة
      if (_selectedFilter != 'all' && order.status != _selectedFilter) {
        return false;
      }

      // فلترة حسب البحث
      if (query.isNotEmpty) {
        final matchNumber = order.orderNumber.toLowerCase().contains(query);
        final matchCustomer = order.customerName.toLowerCase().contains(query);
        return matchNumber || matchCustomer;
      }

      return true;
    }).toList();

    // ترتيب حسب الأحدث
    filtered.sort((a, b) {
      final dateA = a.createdAt ?? DateTime(2000);
      final dateB = b.createdAt ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    setState(() {
      _filteredOrders = filtered;
    });
  }

  /// تحديث الفلتر المختار
  void _updateFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _filterOrders();
  }

  /// سحب لتحديث البيانات
  Future<void> _refreshData() async {
    await _loadOrders();
  }

  /// الانتقال لتفاصيل الطلب
  void _navigateToOrderDetails(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(orderId: order.orderId),
      ),
    ).then((_) {
      // إعادة تحميل القائمة عند العودة
      _loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات التحضير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث برقم الطلب أو اسم العميل...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),

          // أزرار الفلتر
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('الكل', 'all'),
                  _buildFilterChip('معتمد', 'approved'),
                  _buildFilterChip('قيد التحضير', 'preparing'),
                  _buildFilterChip('جاهز للشحن', 'prepared'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // عرض القائمة
          Expanded(
            child: _isLoading && _filteredOrders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64,
                                color: theme.colorScheme.error.withValues(
                                  alpha: 0.75,
                                )),
                            const SizedBox(height: 16),
                            Text(_error!,
                                style:
                                    TextStyle(color: theme.colorScheme.error)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadOrders,
                              icon: const Icon(Icons.refresh),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : _filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_shipping_outlined,
                                  size: 80,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد طلبات تحضير',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'الطلبات المعتمدة ستظهر هنا',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refreshData,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (context, index) {
                                final order = _filteredOrders[index];
                                return _buildOrderCard(order);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// إنشاء بطاقة فلتر
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => _updateFilter(value),
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
        labelStyle: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  /// إنشاء بطاقة طلب
  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: رقم الطلب والحالة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusBadge(order.status),
                ],
              ),

              const SizedBox(height: 12),

              // الصف الثاني: اسم العميل
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // الصف الثالث: التاريخ
              if (order.createdAt != null)
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(order.createdAt!),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              // زر التفاصيل
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToOrderDetails(order),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('تفاصيل التحضير'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// إنشاءشارة الحالة
  Widget _buildStatusBadge(String status) {
    final colors = Theme.of(context).colorScheme;
    Color statusColor;
    String text;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        text = 'معتمد';
        break;
      case 'preparing':
        statusColor = Colors.orange;
        text = 'قيد التحضير';
        break;
      case 'prepared':
      case 'ready_for_shipping':
        statusColor = colors.primary;
        text = 'جاهز للشحن';
        break;
      default:
        statusColor = colors.onSurfaceVariant;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: colors.onSurface,
        ),
      ),
    );
  }

  /// تنسيق التاريخ
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
