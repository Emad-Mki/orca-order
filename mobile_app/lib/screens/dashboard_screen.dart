import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math';
import '../theme/app_theme.dart';
import '../utils/permissions.dart';
import '../widgets/widgets.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import 'package:provider/provider.dart';
import 'screens.dart';

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

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _stats = [];
  List<dynamic> _latestNotifications = [];
  bool _isLoading = true;
  List<Product> _suggestedProducts = [];
  bool _productsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _fetchSuggestedProducts();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // يمكن إضافة استدعاء API هنا لجلب الإحصائيات والإشعارات
      // مؤقتاً نستخدم بيانات وهمية للعرض
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSuggestedProducts() async {
    setState(() => _productsLoading = true);
    try {
      final productsProvider = context.read<ProductsProvider>();
      await productsProvider.fetchProducts();
      
      final allProducts = productsProvider.allProducts;
      final random = Random();
      
      // اختيار 5 منتجات عشوائية
      if (allProducts.isNotEmpty) {
        final shuffled = List<Product>.from(allProducts)..shuffle(random);
        setState(() {
          _suggestedProducts = shuffled.take(5).toList();
          _productsLoading = false;
        });
      } else {
        setState(() => _productsLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _productsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = widget.session['full_name'] ?? widget.session['username'] ?? 'مستخدم';
    final roleDescription = PermissionHelper.getRoleDescriptionAr(widget.userRole);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchDashboardData();
          await _fetchSuggestedProducts();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // الترحيب بالمستخدم
            _buildWelcomeCard(userName, roleDescription, isDark),
            
            const SizedBox(height: 24),
            
            // الاختصارات السريعة
            _buildQuickActions(isDark),
            
            const SizedBox(height: 24),
            
            // المنتجات المقترحة
            _buildSuggestedProductsSection(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(String userName, String roleDescription, bool isDark) {
    return GlassCard(
      opacity: isDark ? 0.1 : 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحباً، $userName',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roleDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 35,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  size: 30,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            'إجراءات سريعة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
          children: [
            // إنشاء طلب جديد
            if (widget.userRole.can(AppPermission.createOrder))
              _QuickActionItem(
                icon: Icons.add_shopping_cart,
                label: 'طلب جديد',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NewOrderScreen(session: widget.session),
                  ),
                ),
              ),
            
            // عرض الطلبات
            if (widget.userRole.can(AppPermission.viewOrders))
              _QuickActionItem(
                icon: Icons.shopping_cart,
                label: 'الطلبات',
                onTap: () {
                  // الانتقال لتبويب الطلبات
                  final homeState = context.findAncestorStateOfType<State>();
                  // يمكن تنفيذ منطق الانتقال هنا
                },
              ),
            
            // العملاء
            if (widget.userRole.can(AppPermission.viewCustomers))
              _QuickActionItem(
                icon: Icons.people,
                label: 'العملاء',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomersScreen(session: widget.session),
                  ),
                ),
              ),
            
            // المنتجات
            if (widget.userRole.can(AppPermission.viewProducts))
              _QuickActionItem(
                icon: Icons.inventory,
                label: 'المنتجات',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductsScreen(),
                  ),
                ),
              ),
            
            // المخزون
            if (widget.userRole.can(AppPermission.viewInventory))
              _QuickActionItem(
                icon: Icons.warehouse,
                label: 'المخزون',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InventoryScreen(session: widget.session),
                  ),
                ),
              ),
            
            // التقارير
            if (widget.userRole.can(AppPermission.viewReports))
              _QuickActionItem(
                icon: Icons.assessment,
                label: 'التقارير',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportsScreen(session: widget.session),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuggestedProductsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // زر استعراض المنتجات
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                'منتجات مقترحة',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProductsScreen()),
              ),
              icon: const Icon(Icons.grid_view),
              label: const Text('استعراض الكل'),
            ),
          ],
        ),
        
        if (_productsLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_suggestedProducts.isEmpty)
          GlassCard(
            opacity: isDark ? 0.1 : 0.8,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد منتجات متاحة',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestedProducts.length,
              itemBuilder: (context, index) {
                final product = _suggestedProducts[index];
                return Container(
                  width: 180,
                  margin: const EdgeInsets.only(left: 8, right: 8, top: 8),
                  child: _ProductCard(product: product),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// عنصر إجراء سريع
class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        margin: EdgeInsets.zero,
        opacity: isDark ? 0.1 : 0.7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة منتج مصغرة
class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      opacity: isDark ? 0.1 : 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // صورة المنتج
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                width: double.infinity,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: Colors.grey,
                        ),
                      )
                    : const Icon(
                        Icons.inventory,
                        size: 40,
                        color: Colors.grey,
                      ),
              ),
            ),
          ),
          
          // معلومات المنتج
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.price.toStringAsFixed(2)} ${product.currency}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
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
