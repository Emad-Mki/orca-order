import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/order_item.dart';
import '../utils/number_utils.dart';

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

  // Helper function to build Google Drive image URL from various formats
  static String? buildImageUrl(String? imageIdentifier) {
    if (imageIdentifier == null || imageIdentifier.isEmpty) return null;
    
    // If already a full HTTP URL, return as is
    if (imageIdentifier.startsWith('http://') || imageIdentifier.startsWith('https://')) {
      return imageIdentifier;
    }
    
    // Check if it's a Google Drive file ID (various formats)
    if (imageIdentifier.contains('drive.google.com')) {
      // Extract file ID from Google Drive URL
      RegExp regExp = RegExp(r'/d/([a-zA-Z0-9_-]+)');
      Match? match = regExp.firstMatch(imageIdentifier);
      if (match != null) {
        String fileId = match.group(1)!;
        return 'https://lh3.googleusercontent.com/d/$fileId=w400-h400-p-k-no-nu';
      }
      
      // Try another pattern for ?id= format
      regExp = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
      match = regExp.firstMatch(imageIdentifier);
      if (match != null) {
        String fileId = match.group(1)!;
        return 'https://lh3.googleusercontent.com/d/$fileId=w400-h400-p-k-no-nu';
      }
    }
    
    // If it contains 'googleusercontent.com', it's already a valid URL
    if (imageIdentifier.contains('googleusercontent.com')) {
      return imageIdentifier;
    }
    
    // Assume it's a raw file ID and construct the URL
    String cleanId = imageIdentifier.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    if (cleanId.isNotEmpty && cleanId.length > 5) {
      return 'https://lh3.googleusercontent.com/d/$cleanId=w400-h400-p-k-no-nu';
    }
    
    return null;
  }

  void _showProductDetails(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          onAddToCart: (item) {
            // التحقق من عدم التكرار
            final existingIndex = _cart.indexWhere((i) => 
              i.product.code == item.product.code && 
              (i.selectedUnit ?? i.product.unit) == (item.selectedUnit ?? item.product.unit)
            );
            
            if (existingIndex >= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('هذا المنتج موجود مسبقاً في السلة بنفس الوحدة'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            
            setState(() => _cart.add(item));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تمت إضافة "${product.name}" للسلة'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'عرض',
                  textColor: Colors.white,
                  onPressed: () {
                    // يمكن الانتقال لعرض السلة هنا
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _addToCartSimple(Product product) {
    // إضافة سريعة بدون تفاصيل (للتوافق مع الكود القديم)
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: isDark ? Colors.blueGrey[900] : Colors.blue[50],
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الزبون: ${_customerName ?? "جاري التحميل..."}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          
          // حقل البحث
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'ابحث عن منتج...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
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
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showProductDetails(p),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // صورة المنتج
                              Expanded(
                                child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: p.imageUrl!,
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      imageBuilder: (context, imageProvider) => Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: imageProvider,
                                            fit: BoxFit.contain,
                                          ),
                                          color: Colors.white,
                                        ),
                                      ),
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[200],
                                        child: const Center(child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.inventory_2, size: 40, color: Colors.grey),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.inventory_2, size: 40, color: Colors.grey),
                                    ),
                              ),
                              
                              // معلومات المنتج
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      p.code,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 4),
                                    p.price > 0
                                      ? Text(
                                          '\$${formatMoneyShort(p.price)}',
                                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                        )
                                      : const Text(
                                          'يرجى التواصل للسعر',
                                          style: TextStyle(color: Colors.orange, fontSize: 11),
                                        ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // منطقة السلة والإرسال
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // عرض السلة
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'السلة: ${_cart.length} أصناف',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    if (_cart.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          // عرض تفاصيل السلة للمراجعة
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('مراجعة الطلب قبل الإرسال'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _cart.length,
                                  itemBuilder: (context, index) {
                                    final item = _cart[index];
                                    return ListTile(
                                      leading: item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: CachedNetworkImage(
                                              imageUrl: item.product.imageUrl!,
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.contain,
                                              imageBuilder: (context, imageProvider) => Container(
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  image: DecorationImage(
                                                    image: imageProvider,
                                                    fit: BoxFit.contain,
                                                  ),
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              placeholder: (context, url) => Container(
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                              ),
                                              errorWidget: (context, error, stackTrace) => Container(
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.inventory_2, size: 30),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.inventory_2, size: 30),
                                          ),
                                      title: Text(item.product.name),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('الكمية: ${item.quantity} ${item.selectedUnit ?? item.product.unit}'),
                                          if (item.note != null && item.note!.isNotEmpty)
                                            Text('ملاحظة: ${item.note}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                      trailing: Text('\$${formatMoneyShort(item.total)}'),
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('إغلاق'),
                                ),
                                FilledButton(
                                  onPressed: _isSubmitting ? null : _submitOrder,
                                  child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('تأكيد وإرسال'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('مراجعة'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // ملاحظات عامة
                TextField(
                  controller: _orderNoteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات عامة للطلب (اختياري)',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                
                // زر الإرسال
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _cart.isEmpty || _isSubmitting ? null : _submitOrder,
                    icon: const Icon(Icons.send),
                    label: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('إرسال الطلب للمراجعة'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// شاشات فرعية
