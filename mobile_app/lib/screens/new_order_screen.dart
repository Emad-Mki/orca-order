import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../utils/number_utils.dart';
import 'product_detail_screen.dart';
import '../widgets/widgets.dart';

/// شاشة إنشاء طلب جديد
class NewOrderScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const NewOrderScreen({super.key, required this.session});
  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final List<OrderItem> _cart = [];
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _loading = true;
  bool _isSubmitting = false;
  final _orderNoteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String? _customerName;

  @override
  void initState() {
    super.initState();
    _loadCustomerName();
    _loadProducts();
    _searchCtrl.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _orderNoteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadCustomerName() {
    // محاولة جلب اسم الزبون من الجلسة أو عبر API
    setState(() {
      _customerName = widget.session['name'] ?? 
                      widget.session['customer_name'] ?? 
                      widget.session['username'];
    });
  }

  void _filterProducts() {
    setState(() {
      final query = _searchCtrl.text.toLowerCase();
      _filteredProducts = _allProducts.where((p) => 
        p.name.toLowerCase().contains(query) || 
        p.code.toLowerCase().contains(query) ||
        p.category.toLowerCase().contains(query)
      ).toList();
    });
  }

  Future<void> _loadProducts() async {
    try {
      final data = await ApiService().post({'action': 'getProducts'});
      var list = data['products'] ?? data['data'] ?? data['items'] ?? data['result'];
      if (mounted) {
        setState(() { 
          _allProducts = (list as List).map((p) => Product.fromJson(p)).toList();
          _filteredProducts = _allProducts;
          _loading = false; 
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل المنتجات: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showProductDetails(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
        ),
      ),
    );
  }

  void _addToCartSimple(Product product) {
    _showProductDetails(product);
  }

  void _submitOrder() async {
    if (_cart.isEmpty || _isSubmitting) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      await ApiService().post({
        'action': 'createOrder',
        'username': widget.session['username'],
        'token': widget.session['token'],
        'items': _cart.map((i) => i.toJson()).toList(),
        'note': _orderNoteCtrl.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الطلب بنجاح'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الإرسال: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب جديد'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط اسم الزبون
          CustomerInfoBarWidget(customerName: _customerName),
          
          // حقل البحث
          SearchFieldWidget(
            controller: _searchCtrl,
            hintText: 'ابحث عن منتج...',
            onChanged: (_) => _filterProducts(),
          ),
          
          // قائمة المنتجات
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator()) 
              : _filteredProducts.isEmpty
                ? const Center(child: Text('لا توجد منتجات'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final p = _filteredProducts[index];
                      return ProductCardWidget(
                        product: p,
                        onTap: () => _showProductDetails(p),
                      );
                    },
                  ),
          ),
          
          // منطقة السلة والإرسال
          CartSummaryWidget(
            cartItems: _cart,
            isSubmitting: _isSubmitting,
            onReviewTap: () => CartSummaryWidget.showReviewDialog(
              context: context,
              cartItems: _cart,
              onSubmit: _submitOrder,
              isSubmitting: _isSubmitting,
            ),
            onSubmitTap: _submitOrder,
          ),
          
          // ملاحظات عامة
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _orderNoteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات عامة للطلب (اختياري)',
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
