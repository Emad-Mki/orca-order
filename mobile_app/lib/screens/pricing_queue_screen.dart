import 'package:flutter/material.dart';
import '../repositories/order_repository.dart';
import '../models/order.dart';
import 'order_details_screen.dart';

/// شاشة قائمة انتظار التسعير
/// تعرض الطلبات التي تحتاج إلى تسعير من قبل المحاسب أو المدير
class PricingQueueScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  
  const PricingQueueScreen({super.key, required this.session});

  @override
  State<PricingQueueScreen> createState() => _PricingQueueScreenState();
}

class _PricingQueueScreenState extends State<PricingQueueScreen> {
  final OrderRepository _orderRepository = OrderRepository();
  final TextEditingController _searchController = TextEditingController();
  
  List<Order> _orders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all'; // all, pending, customer_changed
  
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
  
  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // جلب الطلبات بحالات الانتظار
      final pendingOrders = await _orderRepository.getOrders(status: 'pending');
      final submittedOrders = await _orderRepository.getOrders(status: 'submitted');
      final customerChangedOrders = await _orderRepository.getOrders(status: 'customer_changed');
      
      // دمج القوائم
      final allOrders = [
        ...pendingOrders,
        ...submittedOrders.where((o) => !pendingOrders.any((p) => p.orderId == o.orderId)),
        ...customerChangedOrders.where((o) => !pendingOrders.any((p) => p.orderId == o.orderId) && 
                                              !submittedOrders.any((s) => s.orderId == o.orderId)),
      ];
      
      setState(() {
        _orders = allOrders;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'فشل تحميل قائمة التسعير: $e';
        _isLoading = false;
      });
    }
  }
  
  void _applyFilters() {
    String query = _searchController.text.toLowerCase();
    
    _filteredOrders = _orders.where((order) {
      // فلترة حسب الحالة
      bool statusMatch = _selectedFilter == 'all' || order.status == _selectedFilter;
      
      // فلترة حسب البحث
      bool searchMatch = query.isEmpty || 
                         order.orderNumber.toLowerCase().contains(query) ||
                         order.customerName.toLowerCase().contains(query);
      
      return statusMatch && searchMatch;
    }).toList();
  }
  
  void _onSearchChanged(String value) {
    setState(() {
      _applyFilters();
    });
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'submitted':
        return Colors.blue;
      case 'customer_changed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
  
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'بانتظار التسعير';
      case 'submitted':
        return 'مُرسَل';
      case 'customer_changed':
        return 'تم التعديل من الزبون';
      default:
        return status;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_actions;
      case 'submitted':
        return Icons.submit;
      case 'customer_changed':
        return Icons.edit_note;
      default:
        return Icons.receipt_long;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    String role = widget.session['role']?.toString().toLowerCase() ?? 'customer';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة التسعير'),
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
          // شريط البحث والفلترة
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث برقم الطلب أو اسم العميل...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: _onSearchChanged,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'الكل'),
                            const SizedBox(width: 8),
                            _buildFilterChip('pending', 'بانتظار التسعير'),
                            const SizedBox(width: 8),
                            _buildFilterChip('customer_changed', 'تم التعديل'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // عرض النتائج
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: TextStyle(color: Colors.red[700]),
                              textAlign: TextAlign.center,
                            ),
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
                                Icon(Icons.price_check_outlined, size: 80, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد طلبات في قائمة التسعير',
                                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'ستظهر هنا الطلبات الجديدة والتي تحتاج إلى تسعير',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (context, index) {
                                final order = _filteredOrders[index];
                                return _buildOrderCard(order, role);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String value, String label) {
    bool isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : 'all';
          _applyFilters();
        });
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[700],
    );
  }
  
  Widget _buildOrderCard(Order order, String role) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف العلوي: رقم الطلب والحالة
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
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _getStatusColor(order.status), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(order.status),
                          size: 14,
                          color: _getStatusColor(order.status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusText(order.status),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(order.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // معلومات العميل
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // تاريخ الإنشاء
              if (order.createdAt != null)
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(order.createdAt!),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              
              const SizedBox(height: 8),
              
              // عدد البنود
              if (order.items != null && order.items!.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${order.items!.length} بند',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              
              const SizedBox(height: 12),
              
              // زر التسعير
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if ((role == 'admin' || role == 'manager' || role == 'accountant') &&
                      (order.status == 'pending' || 
                       order.status == 'submitted' || 
                       order.status == 'customer_changed'))
                    ElevatedButton.icon(
                      onPressed: () => _navigateToOrderDetails(order),
                      icon: const Icon(Icons.price_check),
                      label: const Text('سعر الآن'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _navigateToOrderDetails(order),
                    icon: const Icon(Icons.visibility),
                    label: const Text('التفاصيل'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
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
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(
          order: order.toJson(),
          session: widget.session,
        ),
      ),
    ).then((_) {
      // تحديث القائمة عند العودة
      _loadOrders();
    });
  }
  
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
