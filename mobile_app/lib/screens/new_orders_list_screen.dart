import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../repositories/order_repository.dart';
import 'order_details_screen.dart';

/// شاشة قائمة الطلبات الجديدة
/// تعرض الطلبات الحديثة التي لم يتم قراءتها بعد (is_new = true أو is_read = false)
class NewOrdersListScreen extends StatefulWidget {
  const NewOrdersListScreen({super.key});

  @override
  State<NewOrdersListScreen> createState() => _NewOrdersListScreenState();
}

class _NewOrdersListScreenState extends State<NewOrdersListScreen> {
  final OrderRepository _orderRepository = OrderRepository();
  final TextEditingController _searchController = TextEditingController();
  
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = false;
  String? _error;
  String _filterStatus = 'all'; // all, new, unread

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// جلب الطلبات الجديدة
  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allOrders = await _orderRepository.getOrders();
      final newOrders = allOrders.where((order) {
        return order.isNew || !order.isRead;
      }).toList();

      setState(() {
        _allOrders = newOrders;
        _filteredOrders = newOrders;
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      setState(() {
        _error = 'فشل جلب الطلبات الجديدة: $e';
        _isLoading = false;
      });
    }
  }

  /// تطبيق الفلاتر والبحث
  void _applyFilters() {
    var filtered = _allOrders;

    if (_filterStatus == 'new') {
      filtered = filtered.where((o) => o.isNew).toList();
    } else if (_filterStatus == 'unread') {
      filtered = filtered.where((o) => !o.isRead).toList();
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((order) {
        return order.orderNumber.toLowerCase().contains(query) ||
               order.customerName.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredOrders = filtered;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'submitted': return Colors.blue;
      case 'processing': return Colors.purple;
      case 'approved': return Colors.green;
      case 'rejected':
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'بانتظار التسعير';
      case 'submitted': return 'مُرسَل';
      case 'processing': return 'قيد المعالجة';
      case 'approved': return 'مُعتمَد';
      case 'rejected': return 'مرفوض';
      case 'cancelled': return 'مُلغى';
      default: return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Icons.pending_actions;
      case 'submitted': return Icons.send;
      case 'processing': return Icons.hourglass_empty;
      case 'approved': return Icons.check_circle;
      case 'rejected':
      case 'cancelled': return Icons.cancel;
      default: return Icons.info;
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = value);
        _applyFilters();
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[700],
    );
  }

  Widget _buildOrderCard(Order order) {
    final isNew = order.isNew && !order.isRead;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isNew ? 4 : 2,
      color: isNew ? Colors.blue[50] : null,
      child: InkWell(
        onTap: () => _navigateToOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isNew) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'جديد',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              order.orderNumber,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(_formatDate(order.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getStatusColor(order.status), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getStatusIcon(order.status), size: 16, color: _getStatusColor(order.status)),
                        const SizedBox(width: 4),
                        Text(_getStatusText(order.status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getStatusColor(order.status))),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(order.customerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${order.items?.length ?? 0} بنود', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    ],
                  ),
                  if (order.totalAmount > 0)
                    Text('${order.totalAmount.toStringAsFixed(2)} ${order.currency}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _navigateToOrderDetails(order),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('التفاصيل'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
                  ),
                  if (isNew) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _navigateToOrderDetails(order),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('مراجعة'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToOrderDetails(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrderDetailsScreen(orderId: order.orderId)),
    ).then((_) => _loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات الجديدة'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders, tooltip: 'تحديث')],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث برقم الطلب أو اسم العميل...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _applyFilters(); }) : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [_buildFilterChip('الكل', 'all'), const SizedBox(width: 8), _buildFilterChip('جديدة', 'new'), const SizedBox(width: 8), _buildFilterChip('غير مقروءة', 'unread')]),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(onPressed: _loadOrders, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
                        ]),
                      )
                    : _filteredOrders.isEmpty
                        ? Center(
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(_searchController.text.isNotEmpty || _filterStatus != 'all' ? Icons.filter_list_off : Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(_searchController.text.isNotEmpty || _filterStatus != 'all' ? 'لا توجد طلبات تطابق البحث' : 'لا توجد طلبات جديدة', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                              if (_searchController.text.isNotEmpty || _filterStatus != 'all') ...[const SizedBox(height: 8), TextButton(onPressed: () { _searchController.clear(); setState(() => _filterStatus = 'all'); _applyFilters(); }, child: const Text('مسح الفلاتر'))],
                            ]),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: ListView.builder(itemCount: _filteredOrders.length, itemBuilder: (context, index) => _buildOrderCard(_filteredOrders[index])),
                          ),
          ),
        ],
      ),
    );
  }
}
