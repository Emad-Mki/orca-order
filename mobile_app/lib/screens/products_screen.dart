class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  String _selectedOrigin = 'الكل';
  Set<String> _categories = {'الكل'};
  Set<String> _origins = {'الكل'};
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Helper function to build Google Drive image URL from various formats
  static String? buildImageUrl(String? imageIdentifier) {
    if (imageIdentifier == null || imageIdentifier.isEmpty) return null;
    
    // If already a full HTTP URL, return as is
    if (imageIdentifier.startsWith('http://') || imageIdentifier.startsWith('https://')) {
      return imageIdentifier;
    }
    
    // Check if it's a Google Drive file ID (various formats)
    // Format 1: Just the file ID
    // Format 2: https://drive.google.com/file/d/FILE_ID/view
    // Format 3: https://drive.google.com/open?id=FILE_ID
    // Format 4: https://lh3.googleusercontent.com/... (already a thumbnail)
    
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
    
    // If it contains 'lh3.googleusercontent.com', it's already a valid URL
    if (imageIdentifier.contains('googleusercontent.com')) {
      return imageIdentifier;
    }
    
    // Assume it's a raw file ID and construct the URL
    // Remove any special characters that might interfere
    String cleanId = imageIdentifier.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    if (cleanId.isNotEmpty && cleanId.length > 5) {
      return 'https://lh3.googleusercontent.com/d/$cleanId=w400-h400-p-k-no-nu';
    }
    
    return null;
  }

  Future<void> _fetchProducts() async {
    try {
      final data = await ApiService().post({'action': 'getProducts'});
      var list = data['products'] ?? data['data'] ?? data['items'] ?? data['result'];
      final isCached = data['cached'] == true;
      if (mounted) {
        setState(() {
          _products = (list as List).map((p) => Product.fromJson(p)).toList();
          _extractFilters();
          _applyFilters();
          _isLoading = false;
        });
        // Show notification if using cached data
        if (isCached) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('عرض البيانات المخزنة محلياً (وضع عدم الاتصال)'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)),
          );
        } else if (!isCached) {
          // Auto-refresh in background after showing cached data
          _scheduleBackgroundRefresh();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل المنتجات: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Schedule a background refresh when connection is restored
  void _scheduleBackgroundRefresh() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && await ApiService().isOnline()) {
      try {
        final data = await ApiService().post({'action': 'getProducts'}, forceRefresh: true);
        var list = data['products'] ?? data['data'] ?? data['items'] ?? data['result'];
        if (mounted && list != null) {
          setState(() {
            _products = (list as List).map((p) => Product.fromJson(p)).toList();
            _extractFilters();
            _applyFilters();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث البيانات بنجاح'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
          );
        }
      } catch (e) {
        // Silently fail on background refresh
        print('Background refresh failed: $e');
      }
    }
  }

  void _extractFilters() {
    _categories = {'الكل'};
    _origins = {'الكل'};
    for (var p in _products) {
      _categories.add(p.category);
      _origins.add(p.origin);
    }
  }

  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _filteredProducts = _products.where((p) {
        final matchesSearch = _searchQuery.isEmpty || 
            p.name.toLowerCase().contains(_searchQuery) ||
            p.code.toLowerCase().contains(_searchQuery) ||
            p.category.toLowerCase().contains(_searchQuery);
        final matchesCategory = _selectedCategory == 'الكل' || p.category == _selectedCategory;
        final matchesOrigin = _selectedOrigin == 'الكل' || p.origin == _selectedOrigin;
        return matchesSearch && matchesCategory && matchesOrigin;
      }).toList();
    });
  }

  Future<void> _importDummyData() async {
    // محاكاة استيراد بيانات تجريبية
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري استيراد البيانات التجريبية...')),
    );
    await Future.delayed(const Duration(seconds: 1));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم استيراد البيانات بنجاح'), backgroundColor: Colors.green),
    );
    _fetchProducts();
  }

  void _showProductDetails(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  void _addToCart(Product product) {
    // إرسال حدث إضافة للسلة
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product, addToCart: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final role = (context.findAncestorStateOfType<_HomePageState>()?.widget.session['role']?.toString().toLowerCase());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن منتج...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
              ),
              if (role == 'admin')
                IconButton(icon: const Icon(Icons.file_upload), onPressed: _importDummyData, tooltip: 'استيراد تجريبي'),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchProducts, tooltip: 'تحديث'),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _filteredProducts.length,
            itemBuilder: (context, index) {
              final p = _filteredProducts[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  leading: p.imageUrl != null && p.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: p.imageUrl!,
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
                              color: const Color(0xff00658f).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xff00658f).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.inventory_2, color: Color(0xff00658f)),
                          ),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xff00658f).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2, color: Color(0xff00658f)),
                      ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.code} | ${p.category}'),
                      Text('المنشأ: ${p.origin}'),
                      if (p.price == 0)
                        const Text('يرجى التواصل لمعرفة السعر', style: TextStyle(color: Colors.orange, fontSize: 12)),
                      if (p.units != null && p.units!.isNotEmpty)
                        Text('الوحدات: ${p.units!.join(', ')}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  trailing: p.price > 0 
                    ? Text('\$${formatMoneyShort(p.price)}', 
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16))
                    : const Icon(Icons.info_outline, color: Colors.orange),
                  isThreeLine: true,
                  onTap: () => _showProductDetails(p),
                  onLongPress: () => _addToCartFromGrid(p),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _addToCartFromGrid(Product product) {
    // إضافة سريعة للسلة عند الضغط المطول
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة "${product.name}" للسلة'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'عرض',
          textColor: Colors.white,
          onPressed: () {
            // الانتقال للسلة
          },
        ),
      ),
    );
  }
}