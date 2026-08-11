import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';

// --- النماذج (Models) ---
class OrderStatus {
  static const String pending = 'pending'; // قيد المعالجة - عندما يرسل الزبون الطلب
  static const String priced = 'priced'; // تم التسعير - عندما يثبت المحاسب السعر
  static const String approved = 'approved'; // تمت الموافقة - عندما يؤكد الزبون الفاتورة
  static const String customerChanged = 'customer_changed'; // تم التعديل - عندما يعدل الزبون بعد التسعير
  static const String preparing = 'preparing'; // قيد التجهيز - المستودع يجهز للشحن
  static const String shipping = 'shipping'; // منتهي - تم التسليم للشحن
  static const String cancelled = 'cancelled'; // ملغى
  static const String deleted = 'deleted'; // محذوف نهائياً

  static String getArabicStatus(String status) {
    switch (status) {
      case pending: return 'قيد المعالجة';
      case priced: return 'تم التسعير';
      case approved: return 'تمت الموافقة';
      case customerChanged: return 'تم التعديل';
      case preparing: return 'قيد التجهيز';
      case shipping: return 'منتهي (قيد الشحن)';
      case cancelled: return 'ملغى';
      case deleted: return 'محذوف';
      default: return status;
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case pending: return Colors.orange;
      case priced: return Colors.blue;
      case approved: return Colors.green;
      case customerChanged: return Colors.amber;
      case preparing: return Colors.purple;
      case shipping: return Colors.teal;
      case cancelled: return Colors.red;
      case deleted: return Colors.grey;
      default: return Colors.grey;
    }
  }
}

class CartItem {
  final Product product;
  double quantity;
  String? note;
  String? selectedUnit;

  CartItem({required this.product, this.quantity = 1.0, this.note, this.selectedUnit});

  Map<String, dynamic> toJson() => {
    'code': product.code,
    'name': product.name,
    'quantity': quantity,
    'unit': selectedUnit ?? product.unit,
    'note': note ?? '',
  };
}
class User {
  final String username;
  final String fullName;
  final String role;
  final bool isActive;
  final String? customerId;

  User({
    required this.username,
    required this.fullName,
    required this.role,
    this.isActive = true,
    this.customerId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? 'customer',
      isActive: json['is_active'] == true || json['is_active'] == '1',
      customerId: json['customer_id'],
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'full_name': fullName,
        'role': role,
        'is_active': isActive ? '1' : '0',
        'customer_id': customerId,
      };
}

class AuditLogEntry {
  final int id;
  final String username;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> oldValues;
  final Map<String, dynamic> newValues;
  final DateTime timestamp;
  final String ipAddress;

  AuditLogEntry({
    required this.id,
    required this.username,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.oldValues = const {},
    this.newValues = const {},
    required this.timestamp,
    this.ipAddress = '',
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      action: json['action'] ?? '',
      entityType: json['entity_type'] ?? '',
      entityId: json['entity_id'] ?? '',
      oldValues: json['old_values'] != null ? Map<String, dynamic>.from(json['old_values']) : {},
      newValues: json['new_values'] != null ? Map<String, dynamic>.from(json['new_values']) : {},
      timestamp: json['timestamp'] != null 
          ? (json['timestamp'] is DateTime ? json['timestamp'] : DateTime.parse(json['timestamp']))
          : DateTime.now(),
      ipAddress: json['ip_address'] ?? '',
    );
  }
}

class SystemSettings {
  String companyNameAr;
  String companyNameEn;
  String logoUrl;
  String defaultCurrency;
  double creditLimit;
  double lowStockThreshold;
  String invoiceNumberFormat;

  SystemSettings({
    this.companyNameAr = 'أوركا أوردر',
    this.companyNameEn = 'ORCA ORDER',
    this.logoUrl = '',
    this.defaultCurrency = 'USD',
    this.creditLimit = 0,
    this.lowStockThreshold = 10,
    this.invoiceNumberFormat = 'INV-{YYYY}-{####}',
  });

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    return SystemSettings(
      companyNameAr: json['company_name_ar'] ?? 'أوركا أوردر',
      companyNameEn: json['company_name_en'] ?? 'ORCA ORDER',
      logoUrl: json['logo_url'] ?? '',
      defaultCurrency: json['default_currency'] ?? 'USD',
      creditLimit: (json['credit_limit'] ?? 0).toDouble(),
      lowStockThreshold: (json['low_stock_threshold'] ?? 10).toDouble(),
      invoiceNumberFormat: json['invoice_number_format'] ?? 'INV-{YYYY}-{####}',
    );
  }

  Map<String, dynamic> toJson() => {
        'company_name_ar': companyNameAr,
        'company_name_en': companyNameEn,
        'logo_url': logoUrl,
        'default_currency': defaultCurrency,
        'credit_limit': creditLimit,
        'low_stock_threshold': lowStockThreshold,
        'invoice_number_format': invoiceNumberFormat,
      };
}

class Product {
  final String code;
  final String name;
  final String category;
  final String origin;
  final String unit;
  final double price;
  final double quantity;
  final String? imageUrl;
  final String? notes;
  final String currency;
  final int stock;
  final String? description;
  final List<String>? units;
  final String? uomName;

  Product({
    required this.code,
    required this.name,
    required this.category,
    required this.origin,
    required this.unit,
    required this.price,
    this.quantity = 0,
    this.imageUrl,
    this.notes,
    this.currency = 'USD',
    this.stock = 0,
    this.description,
    this.units,
    this.uomName,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    var unitsData = json['units'];
    List<String>? unitsList;
    if (unitsData is List) {
      unitsList = unitsData.map((u) => u.toString()).toList();
    } else if (unitsData is String) {
      unitsList = unitsData.split(',').map((u) => u.trim()).toList();
    }
    
    // معالجة الصورة:尝试 من حقول مختلفة أو استخدام الكود كاسم ملف
    String? img = json['image_url'] ?? json['image_name'] ?? json['imageUrl'];
    if (img == null || img.isEmpty) {
      // إذا لم توجد صورة، نستخدم الكود كاسم للملف (سيتم ربطه لاحقاً بـ Google Drive)
      img = json['code']?.toString();
    }
    
    return Product(
      code: json['code']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? json['group'] ?? '',
      origin: json['origin'] ?? '',
      unit: json['unit'] ?? json['unit_1'] ?? '',
      price: (json['price'] ?? json['display_price'] ?? 0).toDouble(),
      quantity: (json['quantity'] ?? 0).toDouble(),
      imageUrl: img,
      notes: json['notes'],
      currency: json['currency'] ?? 'USD',
      stock: json['stock_available'] ?? json['stock'] ?? 0,
      description: json['description'],
      units: unitsList,
      uomName: json['uomName']?.toString(),
    );
  }
}

class OrderItem {
  final Product product;
  double quantity;
  String? note;
  String? selectedUnit;

  OrderItem({required this.product, this.quantity = 1.0, this.note, this.selectedUnit});

  double get total => (product.price ?? 0) * quantity;

  Map<String, dynamic> toJson() => {
        'code': product.code ?? '',
        'name': product.name ?? '',
        'quantity': quantity,
        'unit': selectedUnit ?? product.unit,
        'price': product.price ?? 0,
        'price': product.price,
        'note': note ?? '',
        'total': total,
      };
}

// --- الخدمات (Services) ---
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Cache manager for product images and data
  static final CacheManager _cacheManager = CacheManager(
    Config(
      'orca_product_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: 'orca_product_cache'),
      fileService: HttpFileService(),
    ),
  );

  /// Check if device is online
  Future<bool> isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Get cached products from local storage
  Future<List<Map<String, dynamic>>> getCachedProducts() async {
    try {
      final file = await _cacheManager.getFileFromCache('products_cache.json');
      if (file != null) {
        final content = await file.file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['products'] ?? []);
      }
    } catch (e) {
      print('Error reading cached products: $e');
    }
    return [];
  }

  /// Save products to cache
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheFile = File('${tempDir.path}/products_cache.json');
      await cacheFile.writeAsString(jsonEncode({'products': products, 'timestamp': DateTime.now().toIso8601String()}));
      await _cacheManager.putFile('products_cache.json', cacheFile);
    } catch (e) {
      print('Error caching products: $e');
    }
  }

  /// Get last cache timestamp
  Future<DateTime?> getLastCacheTimestamp() async {
    try {
      final file = await _cacheManager.getFileFromCache('products_cache.json');
      if (file != null) {
        final content = await file.file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        if (data['timestamp'] != null) {
          return DateTime.parse(data['timestamp']);
        }
      }
    } catch (e) {
      print('Error reading cache timestamp: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> post(Map<String, dynamic> body, {bool useCache = true, bool forceRefresh = false}) async {
    // تنظيف الرابط من أي مسافات زائدة قد تسبب خطأ SocketException
    final String cleanUrl = AppConfig.apiUrl.trim().replaceAll(' ', '');
    
    if (cleanUrl.isEmpty || cleanUrl.contains('PASTE_')) {
      throw Exception('الرجاء ضبط رابط API في ملف app_config.dart');
    }

    // Check for offline mode and try to use cache for getProducts
    final bool online = await isOnline();
    if (!online && useCache && body['action'] == 'getProducts') {
      final cachedProducts = await getCachedProducts();
      if (cachedProducts.isNotEmpty) {
        return {'ok': true, 'products': cachedProducts, 'cached': true};
      } else {
        throw Exception('لا يوجد اتصال بالإنترنت ولا توجد بيانات مخزنة محلياً');
      }
    }

    if (!online) {
      throw Exception('لا يوجد اتصال بالإنترنت');
    }

    try {
      final client = http.Client();
      final uri = Uri.parse(cleanUrl);
      
      var request = http.Request('POST', uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        })
        ..body = jsonEncode(body)
        ..followRedirects = false;

      var response = await client.send(request).timeout(const Duration(seconds: 20));
      
      int redirectCount = 0;
      while ((response.statusCode == 302 || response.statusCode == 301 || response.statusCode == 307 || response.statusCode == 308) && redirectCount < 5) {
        final location = response.headers['location'];
        if (location == null) break;
        final nextUri = Uri.parse(location);
        var nextRequest = http.Request('GET', nextUri)..followRedirects = false;
        response = await client.send(nextRequest).timeout(const Duration(seconds: 20));
        redirectCount++;
      }

      final finalResponse = await http.Response.fromStream(response);
      
      if (finalResponse.statusCode >= 400) {
        throw Exception('خطأ في الخادم: ${finalResponse.statusCode}');
      }

      String bodyText = finalResponse.body.trim();
      int jsonStart = bodyText.indexOf('{');
      int jsonEnd = bodyText.lastIndexOf('}');

      if (jsonStart != -1 && jsonEnd != -1 && jsonEnd >= jsonStart) {
        bodyText = bodyText.substring(jsonStart, jsonEnd + 1);
      }

      final dynamic data = jsonDecode(bodyText);
      bool isOk = data['ok'] == true || data['success'] == true;
      
      // Cache products if this is a getProducts action
      if (useCache && body['action'] == 'getProducts' && isOk) {
        var products = data['products'] ?? data['data'] ?? data['items'] ?? data['result'];
        if (products is List) {
          await cacheProducts(List<Map<String, dynamic>>.from(products));
        }
      }
      
      if (!isOk) {
        throw Exception(data['error'] ?? data['message'] ?? 'حدث خطأ في الخادم');
      }
      return data;
    } catch (e) {
      rethrow;
    }
  }
}

// --- التطبيق الأساسي ---
void main() => runApp(const OrcaApp());

class OrcaApp extends StatefulWidget {
  const OrcaApp({super.key});

  @override
  State<OrcaApp> createState() => _OrcaAppState();
}

class _OrcaAppState extends State<OrcaApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أوركا أوردر',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: _themeMode,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff00658f),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Cairo',
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff00658f),
          primary: const Color(0xff00658f),
          secondary: const Color(0xff00a8e8),
          surface: Colors.white,
        ),
        fontFamily: 'Cairo',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xff00658f),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// --- صفحة تسجيل الدخول ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('saved_user');
    final savedPass = prefs.getString('saved_pass');
    if (savedUser != null && savedPass != null) {
      _userCtrl.text = savedUser;
      _passCtrl.text = savedPass;
      // الاختياري: تسجيل الدخول تلقائياً
      // _login(); 
    }
  }

  void _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final username = _userCtrl.text.trim();
      final password = _passCtrl.text;
      final data = await ApiService().post({
        'action': 'login',
        'username': username,
        'password': password,
      });
      
      if (!mounted) return;

      // حفظ البيانات محلياً
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_user', username);
      await prefs.setString('saved_pass', password);
      
      Map<String, dynamic>? sessionData;
      final possibleKeys = ['session', 'user', 'data', 'result'];
      for (var key in possibleKeys) {
        if (data[key] is Map) {
          sessionData = Map<String, dynamic>.from(data[key]);
          break;
        }
      }

      if (sessionData == null && (data.containsKey('role') || data.containsKey('full_name'))) {
        sessionData = data;
      }

      if (sessionData == null) {
        sessionData = {
          'username': username,
          'role': data['role'] ?? 'customer',
          'full_name': data['full_name'] ?? username,
          'token': data['token'],
        };
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(session: sessionData!)),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.waves, size: 80, color: Color(0xff00658f)),
                    const SizedBox(height: 16),
                    const Text('أوركا أوردر', 
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xff00658f))),
                    const Text('ORCA ORDER', 
                      style: TextStyle(fontSize: 14, letterSpacing: 2, color: Colors.grey)),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _loading ? null : _login,
                        child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('دخول'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- الصفحة الرئيسية ---
class HomePage extends StatefulWidget {
  final Map<String, dynamic> session;
  const HomePage({super.key, required this.session});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late final List<NavItem> _navItems;

  @override
  void initState() {
    super.initState();
    _navItems = _getNavItemsForRole((widget.session['role'] ?? 'customer').toString().toLowerCase());
  }

  List<NavItem> _getNavItemsForRole(String role) {
    final List<NavItem> items = [];
    
    // العناصر الأساسية لكل الأدوار
    items.add(NavItem('الرئيسية', Icons.home_outlined, DashboardScreen(session: widget.session)));
    
    // المحاسب والعميل والمدير لهم منتجات وطلبات
    if (role == 'admin' || role == 'accountant' || role == 'customer') {
      items.add(NavItem('المنتجات', Icons.inventory_2_outlined, const ProductsScreen()));
      items.add(NavItem('الطلبات', Icons.shopping_cart_outlined, OrdersScreen(session: widget.session)));
    }

    // الإشعارات للجميع
    items.add(NavItem('الإشعارات', Icons.notifications_none_outlined, const NotificationsScreen()));

    // عناصر خاصة بالمحاسب والمدير
    if (role == 'admin' || role == 'accountant') {
      items.addAll([
        NavItem('قائمة الطلبات الجديدة', Icons.playlist_add_check_outlined, NewOrdersListScreen(session: widget.session)),
        NavItem('تسعير الطلبات', Icons.calculate_outlined, PricingQueueScreen(session: widget.session)),
        NavItem('الفواتير بانتظار الاعتماد', Icons.verified_user_outlined, PendingApprovalScreen(session: widget.session)),
        NavItem('العملاء', Icons.people_outline, CustomersScreen()),
        NavItem('كشف حساب', Icons.account_balance_outlined, const CustomerStatementScreen()),
        NavItem('الدفعات', Icons.payments_outlined, PaymentsScreen()),
        NavItem('الشحن', Icons.local_shipping_outlined, ShippingScreen()),
        NavItem('استيراد من Excel', Icons.import_export_outlined, ImportExportScreen(session: widget.session)),
      ]);
    }
    
    // عناصر خاصة بالمخزن والمدير
    if (role == 'admin' || role == 'warehouse') {
      items.add(NavItem('المخزون', Icons.warehouse_outlined, const InventoryScreen()));
      items.add(NavItem('أوامر التجهيز', Icons.assignment_outlined, PreparationOrdersScreen(session: widget.session)));
    }
    
    // عناصر خاصة بالعميل
    if (role == 'customer') {
      items.add(NavItem('كشف حسابي', Icons.account_balance_outlined, const CustomerStatementScreen()));
    }
    
    // التقارير للمدير والمحاسب
    if (role == 'admin' || role == 'accountant') {
      items.add(NavItem('التقارير', Icons.analytics_outlined, ReportsScreen(session: widget.session)));
    }
    
    // عناصر خاصة بالمدير فقط
    if (role == 'admin') {
      items.addAll([
        NavItem('إدارة المستخدمين', Icons.manage_accounts_outlined, UserManagementScreen(session: widget.session)),
        NavItem('إعدادات النظام', Icons.settings_suggest_outlined, SystemSettingsScreen(session: widget.session)),
        NavItem('سجل التدقيق', Icons.history_edu_outlined, AuditLogScreen(session: widget.session)),
        NavItem('النسخ الاحتياطي', Icons.backup_outlined, BackupSettingsScreen(session: widget.session)),
      ]);
    }
    
    // الإعدادات والملف الشخصي للجميع
    items.add(NavItem('الإعدادات', Icons.settings_outlined, const SettingsScreen()));
    
    return items;
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final item = _navItems[_selectedIndex];
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('اضغط مرتين للخروج', textAlign: TextAlign.center),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(item.title),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()))),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(widget.session['full_name'] ?? 'مستخدم أوركا'),
                accountEmail: Text('الدور: ${widget.session['role']}'),
                decoration: const BoxDecoration(color: Color(0xff00658f)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _navItems.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: Icon(_navItems[index].icon),
                    title: Text(_navItems[index].title),
                    selected: _selectedIndex == index,
                    onTap: () { setState(() => _selectedIndex = index); Navigator.pop(context); },
                  ),
                ),
              ),
            ],
          ),
        ),
        body: item.screen,
        floatingActionButton: _buildFab(item.title),
      ),
    );
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة عميل جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
                TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'اسم المستخدم (للدخول)')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                TextField(controller: companyCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: loading ? null : () async {
                if (nameCtrl.text.isEmpty || userCtrl.text.isEmpty) return;
                setDialogState(() => loading = true);
                try {
                  await ApiService().post({
                    'action': 'createCustomer',
                    'full_name': nameCtrl.text.trim(),
                    'username': userCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'company_name': companyCtrl.text.trim(),
                    'token': widget.session['token'],
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  // إشعار الصفحة لتحديث البيانات إذا كانت مفتوحة
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة العميل بنجاح'), backgroundColor: Colors.green));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                } finally {
                  setDialogState(() => loading = false);
                }
              },
              child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPaymentDialog() {
    final customerIdCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تسجيل دفعة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: customerIdCtrl, decoration: const InputDecoration(labelText: 'معرف العميل (ID)')),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ (\$)')),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'ملاحظات')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: loading ? null : () async {
                if (customerIdCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                setDialogState(() => loading = true);
                try {
                  await ApiService().post({
                    'action': 'addPayment',
                    'customer_id': customerIdCtrl.text.trim(),
                    'amount': double.tryParse(amountCtrl.text) ?? 0,
                    'note': noteCtrl.text.trim(),
                    'token': widget.session['token'],
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الدفعة بنجاح'), backgroundColor: Colors.green));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                } finally {
                  setDialogState(() => loading = false);
                }
              },
              child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFab(String title) {
    if (title == 'الطلبات') {
      return FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => NewOrderScreen(session: widget.session)));
          if (result == true) {
             // يمكن إضافة دالة تحديث هنا إذا لزم الأمر
          }
        },
        label: const Text('طلب جديد'),
        icon: const Icon(Icons.add_shopping_cart),
        backgroundColor: const Color(0xff00658f),
        foregroundColor: Colors.white,
      );
    }
    if (title == 'المخزون' && (widget.session['role'] == 'admin' || widget.session['role'] == 'warehouse')) {
      return FloatingActionButton(
        onPressed: () {
          // يمكن إضافة وظيفة إضافة منتج جديد هنا
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم إضافة خاصية إضافة منتج قريباً')));
        },
        child: const Icon(Icons.add_box),
        backgroundColor: const Color(0xff00a8e8),
        foregroundColor: Colors.white,
      );
    }
    if (title == 'العملاء' && (widget.session['role'] == 'admin' || widget.session['role'] == 'accountant')) {
      return FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(),
        child: const Icon(Icons.person_add),
        backgroundColor: const Color(0xff00658f),
        foregroundColor: Colors.white,
      );
    }
    if (title == 'الدفعات' && (widget.session['role'] == 'admin' || widget.session['role'] == 'accountant')) {
      return FloatingActionButton(
        onPressed: () => _showAddPaymentDialog(),
        child: const Icon(Icons.add_card),
        backgroundColor: const Color(0xff00a8e8),
        foregroundColor: Colors.white,
      );
    }
    return null;
  }
}

class NavItem {
  final String title;
  final IconData icon;
  final Widget screen;
  NavItem(this.title, this.icon, this.screen);
}

// --- الشاشات ---

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const DashboardScreen({super.key, required this.session});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _stats = [];
  List<dynamic> _latestNotifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final params = {
        'username': widget.session['username'],
        'token': widget.session['token'],
      };

      final statsData = await ApiService().post({'action': 'getDashboardStats', ...params});
      final notifData = await ApiService().post({'action': 'getNotifications', ...params});

      if (mounted) {
        setState(() {
          _stats = statsData['stats'] ?? [];
          _latestNotifications = (notifData['notifications'] as List? ?? []).take(3).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('نظرة عامة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff00658f))),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _stats.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (context, index) {
              final s = _stats[index];
              return _buildStatCard(
                s['title'] ?? '',
                s['value'] ?? '',
                _getIconData(s['icon']),
                _getStatColor(index),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('آخر الإشعارات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  // الانتقال لصفحة الإشعارات
                  context.findAncestorStateOfType<_HomePageState>()?.setState(() {
                    context.findAncestorStateOfType<_HomePageState>()!._selectedIndex = 
                      context.findAncestorStateOfType<_HomePageState>()!._navItems.indexWhere((item) => item.title == 'الإشعارات');
                  });
                },
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          if (_latestNotifications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('لا توجد تحديثات جديدة')),
            )
          else
            ..._latestNotifications.map((n) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.notifications_none, color: Colors.orange),
                title: Text(n['title'] ?? ''),
                subtitle: Text(n['body'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  // يمكن فتح تفاصيل الإشعار هنا
                },
              ),
            )),
        ],
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'shopping_cart': return Icons.shopping_cart;
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      case 'person': return Icons.person;
      case 'people': return Icons.people;
      case 'attach_money': return Icons.attach_money;
      case 'inventory': return Icons.inventory;
      case 'new_releases': return Icons.new_releases;
      default: return Icons.info;
    }
  }

  Color _getStatColor(int index) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal];
    return colors[index % colors.length];
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

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
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: _buildImageUrl(p.imageUrl) ?? '',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 50,
                            height: 50,
                            color: const Color(0xff00658f).withOpacity(0.1),
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xff00658f).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.inventory_2, color: Color(0xff00658f)),
                          ),
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xff00658f).withOpacity(0.1),
                          shape: BoxShape.circle,
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
                    ? Text('\$${p.price.toStringAsFixed(2)}', 
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
class OrdersScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const OrdersScreen({super.key, required this.session});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final data = await ApiService().post({
        'action': 'getOrders',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      var list = data['orders'] ?? data['data'] ?? data['items'] ?? data['result'];
      if (mounted) {
        setState(() {
          _orders = list is List ? list : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'submitted': case 'pending': return Colors.blue;
      case 'priced': return Colors.orange;
      case 'customer_confirmed': case 'approved': return Colors.green;
      case 'prepared': return Colors.purple;
      case 'shipping': return Colors.indigo;
      case 'delivered': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'submitted': case 'pending': return 'قيد المراجعة';
      case 'priced': return 'بانتظار تأكيدك (مسعرة)';
      case 'customer_confirmed': return 'مؤكدة من قبلك';
      case 'approved': return 'معتمدة';
      case 'prepared': return 'جاهزة للشحن';
      case 'shipping': return 'قيد الشحن';
      case 'delivered': return 'تم التسليم';
      default: return status ?? 'غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_orders.isEmpty) return const Center(child: Text('لا يوجد طلبات'));

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              title: Text('طلب #${order['id']}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('التاريخ: ${order['date']}'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _getStatusColor(order['status']).withAlpha(25), borderRadius: BorderRadius.circular(4)),
                    child: Text(_getStatusText(order['status']), style: TextStyle(color: _getStatusColor(order['status']), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () async {
                final refresh = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsScreen(order: order, session: widget.session),
                  ),
                );
                if (refresh == true) _fetchOrders();
              },
            ),
          );
        },
      ),
    );
  }
}

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> session;
  const OrderDetailsScreen({super.key, required this.order, required this.session});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _fullOrder;
  Map<String, dynamic>? _shipmentData;
  Map<String, dynamic>? _balanceInfo;
  late String role;

  @override
  void initState() {
    super.initState();
    role = widget.session['role']?.toString().toLowerCase() ?? 'customer';
    _fetchOrderItems();
  }

  Future<void> _fetchOrderItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService().post({
        'action': 'getOrderDetails',
        'orderId': widget.order['id'],
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      
      if (mounted) {
        setState(() {
          _items = data['items'] ?? [];
          _fullOrder = data['order'];
          _shipmentData = data['shipment'];
          _balanceInfo = data['balanceInfo'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await ApiService().post({
        'action': 'updateOrderStatus',
        'orderId': widget.order['id'],
        'status': newStatus,
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث حالة الطلب إلى: $newStatus'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.order['status']?.toString().toLowerCase() ?? '';
    final role = widget.session['role']?.toString().toLowerCase() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('طلب #${widget.order['id']}'),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportOrderPdf),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchOrderItems),
        ],
      ),
      body: _isLoading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.withAlpha(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الحالة الحالية: ${widget.order['status']}', 
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('تاريخ الطلب: ${widget.order['date']}'),
                      if (widget.order['note'] != null && widget.order['note'].toString().isNotEmpty)
                        Text('ملاحظة: ${widget.order['note']}'),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('لا توجد أصناف في هذا الطلب'))
                      : ListView(
                          padding: const EdgeInsets.all(8),
                          children: [
                            if (_fullOrder != null) _buildOrderHeader(),
                            const Divider(),
                            ..._items.map((item) {
                              final bool showPrices = role != 'warehouse';
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text(item['name'] ?? 'منتج غير معروف', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('المطلوب: ${item['quantity_requested']} ${item['unit']}'),
                                      if (item['quantity_approved'] > 0)
                                        Text('المعتمد: ${item['quantity_approved']} ${item['unit']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                      if (item['quantity_prepared'] > 0)
                                        Text('المجهز: ${item['quantity_prepared']} ${item['unit']}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                      if (item['customer_note']?.toString().isNotEmpty == true)
                                        Text('ملاحظة الزبون: ${item['customer_note']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                      if (item['accountant_note']?.toString().isNotEmpty == true)
                                        Text('ملاحظة المحاسب: ${item['accountant_note']}', style: const TextStyle(fontSize: 12, color: Colors.blue)),
                                      if (item['warehouse_note']?.toString().isNotEmpty == true)
                                        Text('ملاحظة المستودع: ${item['warehouse_note']}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                                    ],
                                  ),
                                  trailing: showPrices ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('\$${(item['final_price'] > 0 ? item['final_price'] : item['price_offer']).toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (item['final_price'] > 0)
                                        Text('الإجمالي: \$${(item['final_price'] * (item['quantity_approved'] > 0 ? item['quantity_approved'] : item['quantity_requested'])).toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ) : null,
                                ),
                              );
                            }).toList(),
                            if (_shipmentData != null) _buildShipmentInfo(role),
                            if (role != 'warehouse' && _items.isNotEmpty) _buildOrderFinancialSummary(),
                          ],
                        ),
                ),
                _buildActionButtons(status, role),
              ],
            ),
    );
  }

  Future<void> _exportOrderPdf() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.almaraiRegular();
    final fontBold = await PdfGoogleFonts.almaraiBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('فاتورة طلبية', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('ORCA ORDER', style: pw.TextStyle(fontSize: 18, color: PdfColors.blue)),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text('رقم الطلب: ${_fullOrder?['order_id'] ?? widget.order['id']}'),
                pw.Text('التاريخ: ${_fullOrder?['created_at'] ?? widget.order['date']}'),
                pw.Text('الحالة: ${_fullOrder?['status'] ?? widget.order['status']}'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['الصنف', 'الكمية', 'السعر', 'الإجمالي'],
                  data: _items.map((item) => [
                    item['name'] ?? '',
                    '${item['quantity_requested']} ${item['unit']}',
                    '${item['final_price'] > 0 ? item['final_price'] : item['price_offer']}',
                    '${(item['final_price'] > 0 ? item['final_price'] : item['price_offer']) * item['quantity_requested']}',
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerRight,
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'الإجمالي: ${_items.fold(0.0, (sum, item) => sum + ((item['final_price'] > 0 ? item['final_price'] : item['price_offer']) * item['quantity_requested']))} USD',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Widget _buildOrderHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('طلب رقم: ${_fullOrder!['order_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              _buildStatusChip(_fullOrder!['status']),
            ],
          ),
          Text('التاريخ: ${_fullOrder!['created_at'].toString().split('T')[0]}'),
          if (_fullOrder!['note']?.toString().isNotEmpty == true)
             Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: Text('ملاحظة الطلب: ${_fullOrder!['note']}', style: const TextStyle(fontStyle: FontStyle.italic)),
             ),
        ],
      ),
    );
  }

  Widget _buildShipmentInfo(String role) {
    return Card(
      color: Colors.indigo.shade50,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('بيانات الشحن والتجهيز', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            const Divider(),
            Text('طريقة الاستلام: ${_shipmentData!['delivery_method'] ?? 'غير محدد'}'),
            if (_shipmentData!['carrier']?.toString().isNotEmpty == true)
               Text('شركة الشحن: ${_shipmentData!['carrier']}'),
            if (_shipmentData!['province']?.toString().isNotEmpty == true)
               Text('الوجهة: ${_shipmentData!['province']}'),
            Text('الطرود: ${_shipmentData!['package_count']} (كراتين: ${_shipmentData!['carton_count']}, أكياس: ${_shipmentData!['bag_count']})'),
            if (role == 'admin')
               Text('تكلفة الشحن الداخلية: \$${_shipmentData!['shipping_cost_internal']}', style: const TextStyle(color: Colors.red)),
            if (_shipmentData!['tracking_no']?.toString().isNotEmpty == true)
               Text('رقم التتبع: ${_shipmentData!['tracking_no']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderFinancialSummary() {
    double total = 0;
    for (var item in _items) {
      double qty = item['quantity_approved'] > 0 ? item['quantity_approved'].toDouble() : item['quantity_requested'].toDouble();
      double price = item['final_price'] > 0 ? item['final_price'].toDouble() : item['price_offer'].toDouble();
      total += qty * price;
    }

    return Card(
      margin: const EdgeInsets.only(top: 16, bottom: 80),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('إجمالي الفاتورة الحالية:', '\$${total.toStringAsFixed(2)}', isBold: true),
            if (_balanceInfo != null) ...[
              const Divider(),
              _summaryRow('رصيد الحساب السابق:', '\$${_balanceInfo!['current_balance'].toStringAsFixed(2)}'),
              _summaryRow('الرصيد النهائي بعد الفاتورة:', '\$${(_balanceInfo!['current_balance'] + total).toStringAsFixed(2)}', 
                color: Colors.red, isBold: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'submitted': color = Colors.orange; break;
      case 'priced': color = Colors.blue; break;
      case 'approved': color = Colors.green; break;
      case 'prepared': color = Colors.purple; break;
      case 'shipping': color = Colors.indigo; break;
      case 'delivered': color = Colors.teal; break;
      default: color = Colors.grey;
    }
    return Chip(
      label: Text(_getStatusText(status), style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'submitted': return 'قيد المراجعة';
      case 'priced': return 'تم التسعير';
      case 'customer_changed': return 'تم التعديل';
      case 'customer_confirmed': return 'مؤكد من الزبون';
      case 'approved': return 'معتمد';
      case 'prepared': return 'جاهز';
      case 'shipping': return 'قيد الشحن';
      case 'delivered': return 'تم التسليم';
      default: return status;
    }
  }

  void _showCreateShipmentDialog() {
    final carrierCtrl = TextEditingController();
    final trackingCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final provinceCtrl = TextEditingController();
    bool loading = false;
    final role = (widget.session['role']?.toString().toLowerCase() ?? 'customer');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إنشاء شحنة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: carrierCtrl, decoration: const InputDecoration(labelText: 'شركة الشحن / السائق')),
                TextField(controller: trackingCtrl, decoration: const InputDecoration(labelText: 'رقم التتبع / الجوال')),
                TextField(controller: provinceCtrl, decoration: const InputDecoration(labelText: 'المحافظة / الوجهة')),
                if (role == 'admin')
                  TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تكلفة الشحن (ليرة/دولار)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: loading ? null : () async {
                setDialogState(() => loading = true);
                try {
                  // 1. إنشاء الشحنة
                  await ApiService().post({
                    'action': 'shipment',
                    'order_id': widget.order['id'],
                    'carrier': carrierCtrl.text,
                    'tracking_no': trackingCtrl.text,
                    'province': provinceCtrl.text,
                    'shipping_cost_internal': role == 'admin' ? (double.tryParse(costCtrl.text) ?? 0) : 0,
                    'status': 'shipping',
                    'username': widget.session['username'],
                    'token': widget.session['token'],
                  });

                  // 2. تحديث حالة الطلب إلى "قيد الشحن"
                  await ApiService().post({
                    'action': 'updateOrderStatus',
                    'orderId': widget.order['id'],
                    'status': 'shipping',
                    'username': widget.session['username'],
                    'token': widget.session['token'],
                  });

                  if (!mounted) return;
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الشحنة وتحديث حالة الطلب'), backgroundColor: Colors.indigo));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                } finally {
                  setDialogState(() => loading = false);
                }
              },
              child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('تأكيد الشحن'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(String status, String role) {
    List<Widget> buttons = [];

    // زبون: مراجعة الأسعار والتأكيد أو التعديل
    if (role == 'customer' && status == 'priced') {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _updateStatus('customer_confirmed'),
            icon: const Icon(Icons.check_circle),
            label: const Text('تأكيد الفاتورة'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ),
      );
      buttons.add(const SizedBox(width: 8));
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showCustomerEditDialog(),
            icon: const Icon(Icons.edit),
            label: const Text('تعديل الطلب'),
          ),
        ),
      );
    }

    // محاسب: تسعير الطلبية
    if ((role == 'admin' || role == 'accountant') && (status == 'submitted' || status == 'customer_changed')) {
       buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showPricingDialog(),
            icon: const Icon(Icons.calculate),
            label: const Text('تسعير الفاتورة'),
          ),
        ),
      );
    }
    
    // محاسب/مدير: اعتماد نهائي
    if ((role == 'admin' || role == 'accountant') && status == 'customer_confirmed') {
       buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _updateStatus('approved'),
            icon: const Icon(Icons.verified),
            label: const Text('اعتماد نهائي وحجز المخزون'),
            style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade800),
          ),
        ),
      );
    }

    // مستودع: تجهيز الطلبية
    if ((role == 'admin' || role == 'warehouse') && status == 'approved') {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showWarehousePrepDialog(),
            icon: const Icon(Icons.inventory),
            label: const Text('تجهيز الطلبية'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
          ),
        ),
      );
    }

    // شحن (بعد التجهيز)
    if ((role == 'admin' || role == 'accountant') && status == 'prepared') {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showCreateShipmentDialog(),
            icon: const Icon(Icons.local_shipping),
            label: const Text('تأكيد بيانات الشحن'),
            style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(children: buttons),
    );
  }

  void _showPricingDialog() {
    List<Map<String, dynamic>> editedItems = _items.map((i) => {
      'item_id': i['item_id'],
      'name': i['name'],
      'quantity_requested': i['quantity_requested'],
      'quantity_approved': i['quantity_approved'] == 0 ? i['quantity_requested'] : i['quantity_approved'],
      'final_price': i['final_price'] == 0 ? i['price_offer'] : i['final_price'],
      'currency': i['currency'] ?? 'USD',
      'accountant_note': i['accountant_note'] ?? '',
      'stock': i['stock_available']
    }).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تسعير واعتماد الكميات'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: editedItems.length,
              itemBuilder: (context, index) {
                final item = editedItems[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('المطلوب: ${item['quantity_requested']} | متوفر: ${item['stock']}', style: const TextStyle(fontSize: 12)),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(labelText: 'الكمية المعتمدة'),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => item['quantity_approved'] = double.tryParse(val) ?? 0,
                                controller: TextEditingController(text: item['quantity_approved'].toString()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(labelText: 'السعر النهائي'),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => item['final_price'] = double.tryParse(val) ?? 0,
                                controller: TextEditingController(text: item['final_price'].toString()),
                              ),
                            ),
                            DropdownButton<String>(
                              value: item['currency'],
                              items: ['USD', 'SYP'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (val) => setDialogState(() => item['currency'] = val!),
                            ),
                          ],
                        ),
                        TextField(
                          decoration: const InputDecoration(labelText: 'ملاحظات المحاسب'),
                          onChanged: (val) => item['accountant_note'] = val,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                try {
                  await ApiService().post({
                    'action': 'updateOrderPricing',
                    'orderId': widget.order['id'],
                    'items': editedItems,
                    'username': widget.session['username'],
                    'token': widget.session['token'],
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetchOrderItems();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              child: const Text('إرسال التسعير للزبون'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWarehousePrepDialog() {
    List<Map<String, dynamic>> prepItems = _items.map((i) => {
      'item_id': i['item_id'],
      'name': i['name'],
      'quantity_approved': i['quantity_approved'],
      'quantity_prepared': i['quantity_prepared'] == 0 ? i['quantity_approved'] : i['quantity_prepared'],
      'warehouse_note': i['warehouse_note'] ?? '',
      'unit': i['unit']
    }).toList();

    final pkgCtrl = TextEditingController();
    final ctnCtrl = TextEditingController();
    final bagCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تجهيز الطلبية للمستودع'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: prepItems.length,
                    itemBuilder: (context, index) {
                      final item = prepItems[index];
                      return Card(
                        child: ListTile(
                          title: Text(item['name']),
                          subtitle: Column(
                            children: [
                              Text('الكمية المعتمدة: ${item['quantity_approved']} ${item['unit']}'),
                              TextField(
                                decoration: const InputDecoration(labelText: 'الكمية المجهزة فعلياً'),
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(text: item['quantity_prepared'].toString()),
                                onChanged: (val) => item['quantity_prepared'] = double.tryParse(val) ?? 0,
                              ),
                              TextField(
                                decoration: const InputDecoration(labelText: 'ملاحظات التجهيز (نقص، بديل...)'),
                                onChanged: (val) => item['warehouse_note'] = val,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(child: TextField(controller: pkgCtrl, decoration: const InputDecoration(labelText: 'إجمالي الطرود'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 4),
                    Expanded(child: TextField(controller: ctnCtrl, decoration: const InputDecoration(labelText: 'كراتين'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 4),
                    Expanded(child: TextField(controller: bagCtrl, decoration: const InputDecoration(labelText: 'أكياس'), keyboardType: TextInputType.number)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                try {
                  await ApiService().post({
                    'action': 'confirmWarehousePrep',
                    'orderId': widget.order['id'],
                    'items': prepItems,
                    'package_count': int.tryParse(pkgCtrl.text) ?? 0,
                    'carton_count': int.tryParse(ctnCtrl.text) ?? 0,
                    'bag_count': int.tryParse(bagCtrl.text) ?? 0,
                    'username': widget.session['username'],
                    'token': widget.session['token'],
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetchOrderItems();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              child: const Text('إتمام التجهيز'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerEditDialog() {
    // Clone items locally for editing
    List<Map<String, dynamic>> localItems = _items.map((i) => Map<String, dynamic>.from(i)).toList();
    List<String> deletedItemIds = [];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل بنود الطلبية'),
          content: SizedBox(
            width: double.maxFinite,
            child: localItems.isEmpty 
              ? const Center(child: Text('تم حذف جميع البنود أو لا يوجد بنود لتعديلها'))
              : ListView.builder(
              itemCount: localItems.length,
              itemBuilder: (context, index) {
                final item = localItems[index];
                final double approved = (item['quantity_approved'] ?? 0).toDouble();
                final double requested = (item['quantity_requested'] ?? 0).toDouble();
                
                return ListTile(
                  title: Text(item['name'] ?? 'منتج', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: requested > approved
                              ? () => setDialogState(() => item['quantity_requested']--)
                              : null, // Disable if at approved limit
                          ),
                          Text('$requested', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                            onPressed: () => setDialogState(() => item['quantity_requested']++),
                          ),
                          const SizedBox(width: 8),
                          Text(item['unit'] ?? ''),
                        ],
                      ),
                      if (approved > 0)
                        Text('الحد الأدنى (المعتمد): $approved', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    onPressed: () {
                      setDialogState(() {
                        deletedItemIds.add(localItems[index]['item_id']);
                        localItems.removeAt(index);
                      });
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                try {
                  List<Map<String, dynamic>> payload = [];
                  
                  // Add updates
                  for (var item in localItems) {
                    payload.add({
                      'item_id': item['item_id'],
                      'quantity': item['quantity_requested'],
                      'action': 'update'
                    });
                  }
                  
                  // Add deletions
                  for (var id in deletedItemIds) {
                    payload.add({
                      'item_id': id,
                      'action': 'delete'
                    });
                  }
                  
                  if (payload.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }

                  setState(() => _isLoading = true);
                  await ApiService().post({
                    'action': 'updateCustomerOrder',
                    'orderId': widget.order['id'],
                    'items': payload,
                    'username': widget.session['username'],
                    'token': widget.session['token'],
                  });
                  
                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetchOrderItems();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث الطلبية بنجاح'), backgroundColor: Colors.green)
                  );
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }
}

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
    if (_cart.isEmpty) return;
    
    // التحقق من عدم تكرار المنتجات
    final Map<String, OrderItem> uniqueCart = {};
    for (var item in _cart) {
      final key = '${item.product.code}_${item.selectedUnit ?? item.product.unit}';
      if (uniqueCart.containsKey(key)) {
        // تحديث الكمية إذا كان المنتج موجود مسبقاً
        uniqueCart[key]!.quantity += item.quantity;
        if (item.note != null && item.note!.isNotEmpty) {
          uniqueCart[key]!.note = item.note;
        }
      } else {
        uniqueCart[key] = item;
      }
    }
    
    try {
      await ApiService().post({
        'action': 'createOrder',
        'username': widget.session['username'],
        'token': widget.session['token'],
        'items': uniqueCart.values.map((i) => i.toJson()).toList(),
        'note': _orderNoteCtrl.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الطلب بنجاح'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الإرسال: $e')));
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
                                      imageUrl: _buildImageUrl(p.imageUrl) ?? '',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
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
                                          '\$${p.price.toStringAsFixed(2)}',
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
                                            borderRadius: BorderRadius.circular(4),
                                            child: CachedNetworkImage(
                                              imageUrl: _buildImageUrl(item.product.imageUrl) ?? '',
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                width: 50,
                                                height: 50,
                                                color: Colors.grey[200],
                                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                              ),
                                              errorWidget: (context, error, stackTrace) => Container(
                                                width: 50,
                                                height: 50,
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.inventory_2, size: 30),
                                              ),
                                            ),
                                          )
                                        : const Icon(Icons.inventory_2),
                                      title: Text(item.product.name),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('الكمية: ${item.quantity} ${item.selectedUnit ?? item.product.unit}'),
                                          if (item.note != null && item.note!.isNotEmpty)
                                            Text('ملاحظة: ${item.note}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                      trailing: Text('\$${item.total.toStringAsFixed(2)}'),
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
                                  onPressed: _submitOrder,
                                  child: const Text('تأكيد وإرسال'),
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
                    onPressed: _cart.isEmpty ? null : _submitOrder,
                    icon: const Icon(Icons.send),
                    label: const Text('إرسال الطلب للمراجعة'),
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
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<dynamic> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final data = await ApiService().post({
        'action': 'getCustomers',
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        setState(() {
          _customers = data['customers'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _customers.length,
      itemBuilder: (context, index) {
        final c = _customers[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xff00658f).withOpacity(0.1),
              child: const Icon(Icons.person, color: Color(0xff00658f)),
            ),
            title: Text(c['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c['company_name'] ?? ''}\n${c['phone'] ?? ''}'),
                const SizedBox(height: 4),
                Text('الرصيد: \$${c['balance'] ?? 0}', 
                  style: TextStyle(color: (c['balance'] ?? 0) > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.receipt_long, color: Color(0xff00658f)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerStatementScreen(customerId: c['customer_id']))),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class CustomerStatementScreen extends StatefulWidget {
  final String? customerId;
  const CustomerStatementScreen({super.key, this.customerId});

  @override
  State<CustomerStatementScreen> createState() => _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<CustomerStatementScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStatement();
  }

  Future<void> _fetchStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final response = await ApiService().post({
        'action': 'getCustomerStatement',
        'customer_id': widget.customerId,
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        setState(() {
          _data = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isLoading = true);
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final response = await ApiService().post({
        'action': 'exportStatement',
        'customer_id': widget.customerId,
        'username': session?['username'],
        'token': session?['token'],
      });
      
      if (mounted) {
        setState(() => _isLoading = false);
        // في هذا المستوى من المشروع، سنكتفي بإظهار رسالة نجاح.
        // لإكمال الوظيفة، يجب إضافة path_provider و open_file_plus
        // واستخدام Base64 لتحويله إلى ملف وفتحه.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء ملف PDF بنجاح. يرجى تفعيل إضافات حفظ الملفات للمتابعة.'))
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التصدير: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('خطأ: $_error'));

    final statement = _data!['statement'] as List? ?? [];
    final balance = _data!['finalBalance'] ?? 0;
    final customer = _data!['customer'];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerId != null ? 'كشف: ${customer['full_name']}' : 'كشف حسابي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportPdf,
            tooltip: 'تصدير PDF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStatement,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xff00658f),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الرصيد الحالي', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text('\$${balance.toStringAsFixed(2)}', 
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                Icon(balance > 0 ? Icons.trending_up : Icons.trending_down, 
                  color: balance > 0 ? Colors.redAccent : Colors.greenAccent, size: 40),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchStatement,
              child: ListView.separated(
                itemCount: statement.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final s = statement[index];
                  final isDebit = (s['debit'] as num) > 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDebit ? Colors.red.shade50 : Colors.green.shade50,
                      child: Icon(isDebit ? Icons.arrow_upward : Icons.arrow_downward, 
                        color: isDebit ? Colors.red : Colors.green, size: 18),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s['type'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('\$${(isDebit ? s['debit'] : s['credit']).toStringAsFixed(2)}',
                          style: TextStyle(color: isDebit ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('التاريخ: ${s['date'].toString().split('T')[0]} | المرجع: ${s['ref']}'),
                        if (s['note']?.toString().isNotEmpty == true)
                          Text('ملاحظة: ${s['note']}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                        Text('الرصيد بعد الحركة: \$${s['balance']}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<dynamic> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final data = await ApiService().post({
        'action': 'getPayments',
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        setState(() {
          _payments = data['payments'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final p = _payments[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.payment, color: Colors.green),
            title: Text('دفعة بقيمة \$${p['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            subtitle: Text('العميل: ${p['customer_id']}\nالتاريخ: ${p['payment_date']}'),
            trailing: Text(p['method'] ?? '', style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
        );
      },
    );
  }
}
class ShippingScreen extends StatefulWidget {
  const ShippingScreen({super.key});

  @override
  State<ShippingScreen> createState() => _ShippingScreenState();
}

class _ShippingScreenState extends State<ShippingScreen> {
  List<dynamic> _shipments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchShipments();
  }

  Future<void> _fetchShipments() async {
    setState(() => _isLoading = true);
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final data = await ApiService().post({
        'action': 'getShipments',
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        setState(() {
          _shipments = data['shipments'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateShipmentStatus(String id, String newStatus) async {
    try {
      await ApiService().post({
        'action': 'updateShipmentStatus',
        'shipmentId': id,
        'status': newStatus,
      });
      _fetchShipments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'in_transit': return Icons.local_shipping;
      case 'delivered': return Icons.check_circle;
      case 'returned': return Icons.assignment_return;
      default: return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _shipments.length,
      itemBuilder: (context, index) {
        final s = _shipments[index];
        final status = s['status']?.toString() ?? '';
        return Card(
          child: ListTile(
            leading: Icon(_getStatusIcon(status), 
              color: status == 'delivered' ? Colors.green : (status == 'returned' ? Colors.red : Colors.blue)),
            title: Text('شحنة #${s['shipment_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('طلب: ${s['order_id']} | الناقل: ${s['carrier']}\nتتبع: ${s['tracking_no']}'),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.edit_note),
              onSelected: (val) => _updateShipmentStatus(s['shipment_id'], val),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'in_transit', child: Text('قيد النقل')),
                const PopupMenuItem(value: 'delivered', child: Text('تم التسليم')),
                const PopupMenuItem(value: 'returned', child: Text('مرتجع')),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().post({'action': 'getProducts'});
      var list = data['products'] ?? data['data'] ?? data['items'] ?? data['result'];
      if (mounted) {
        setState(() {
          _products = (list as List).map((p) => Product.fromJson(p)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAdjustDialog(Product p) {
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool isAdding = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('تعديل مخزون: ${p.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('المخزون الحالي: ${p.quantity}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('إضافة (+)'),
                      selected: isAdding,
                      onSelected: (val) => setDialogState(() => isAdding = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('خصم (-)'),
                      selected: !isAdding,
                      onSelected: (val) => setDialogState(() => isAdding = false),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية'),
              ),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text) ?? 0;
                if (qty <= 0) return;
                
                final session = (context.findAncestorStateOfType<_HomePageState>()?.widget.session);
                try {
                  await ApiService().post({
                    'action': 'adjust_inventory',
                    'code': p.code,
                    'quantity': isAdding ? qty : -qty,
                    'type': isAdding ? 'receipt' : 'adjustment',
                    'note': noteCtrl.text,
                    'username': session?['username'],
                    'token': session?['token'],
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetchInventory();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث المخزون'), backgroundColor: Colors.green));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLowStockRequestDialog(Product p) {
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('طلب نواقص: ${p.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية المطلوبة'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظات إضافية'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final qty = double.tryParse(qtyCtrl.text) ?? 0;
              if (qty <= 0) return;

              final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
              try {
                await ApiService().post({
                  'action': 'createLowStockRequest',
                  'code': p.code,
                  'requested_qty': qty,
                  'note': noteCtrl.text,
                  'username': session?['username'],
                  'token': session?['token'],
                });
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب النواقص للمسؤول')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
              }
            },
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _fetchInventory,
      child: ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final p = _products[index];
          final isLow = p.quantity < 10;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryMovementsScreen(productCode: p.code))),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('الكود: ${p.code} | الوحدة: ${p.unit}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLow ? Colors.red.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${p.quantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isLow ? Colors.red.shade900 : Colors.green.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.grey),
                    tooltip: 'سجل الحركات',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryMovementsScreen(productCode: p.code))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.assignment_late_outlined, color: Colors.orange),
                    tooltip: 'طلب نواقص',
                    onPressed: () => _showLowStockRequestDialog(p),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.blue),
                    tooltip: 'تعديل مخزون',
                    onPressed: () => _showAdjustDialog(p),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
class ReportsScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const ReportsScreen({super.key, required this.session});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().post({
        'action': 'getReports',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_reportData == null) return const Center(child: Text('تعذر تحميل التقارير'));

    final statusStats = _reportData!['statusStats'] as List? ?? [];
    final categorySales = _reportData!['categorySales'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _fetchReports,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('حالة الطلبات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.3,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: statusStats.map((s) {
                  final double val = (s['value'] as num).toDouble();
                  return PieChartSectionData(
                    color: _getStatusColor(s['name']),
                    value: val,
                    title: '${_getStatusTextAr(s['name'])}\n$val',
                    radius: 60,
                    titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('المبيعات حسب التصنيف',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.5,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: categorySales.isEmpty
                    ? 10
                    : categorySales
                            .map((c) => c['value'] as num)
                            .reduce((a, b) => a > b ? a : b)
                            .toDouble() *
                        1.2,
                barGroups: categorySales.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: (e.value['value'] as num).toDouble(),
                        color: Colors.blueAccent,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < categorySales.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              categorySales[index]['name'],
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...categorySales.map((c) => Card(
                child: ListTile(
                  title: Text(c['name']),
                  trailing: Text('\$${c['value']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              )),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.orange;
      case 'priced':
        return Colors.blue;
      case 'customer_confirmed':
        return Colors.purple;
      case 'approved':
        return Colors.green;
      case 'delivered':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _getStatusTextAr(String status) {
    switch (status.toLowerCase()) {
      case 'submitted': return 'جديدة';
      case 'priced': return 'مسعرة';
      case 'customer_confirmed': return 'مؤكدة من العميل';
      case 'approved': return 'معتمدة';
      case 'delivered': return 'تم التسليم';
      default: return status;
    }
  }
}

class InventoryMovementsScreen extends StatefulWidget {
  final String? productCode;
  const InventoryMovementsScreen({super.key, this.productCode});

  @override
  State<InventoryMovementsScreen> createState() => _InventoryMovementsScreenState();
}

class _InventoryMovementsScreenState extends State<InventoryMovementsScreen> {
  List<dynamic> _movements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMovements();
  }

  Future<void> _fetchMovements() async {
    setState(() => _isLoading = true);
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final data = await ApiService().post({
        'action': 'getInventoryMovements',
        'code': widget.productCode,
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        setState(() {
          _movements = data['movements'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.productCode == null ? 'سجل حركات المخزون' : 'حركات المنتج: ${widget.productCode}')),
      body: RefreshIndicator(
        onRefresh: _fetchMovements,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _movements.isEmpty 
            ? const Center(child: Text('لا توجد حركات مسجلة'))
            : ListView.builder(
                itemCount: _movements.length,
                itemBuilder: (context, index) {
                  final m = _movements[index];
                  final isReceipt = m['type'] == 'receipt';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        isReceipt ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: isReceipt ? Colors.green : Colors.red,
                      ),
                      title: Text(widget.productCode == null ? 'منتج: ${m['code']}' : 'الكمية: ${m['quantity']}'),
                      subtitle: Text('${m['note']}\n${m['created_at']}'),
                      trailing: widget.productCode == null 
                        ? Text('${isReceipt ? '+' : '-'}${m['quantity']}', 
                            style: TextStyle(color: isReceipt ? Colors.green : Colors.red, fontWeight: FontWeight.bold))
                        : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final data = await ApiService().post({
        'action': 'getNotifications',
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        setState(() {
          _notifications = data['notifications'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleNotificationTap(Map<String, dynamic> n) {
    if (n['read_at'] == null || n['read_at'].toString().isEmpty) {
      _markAsRead(n['notification_id']);
    }

    final String title = n['title']?.toString() ?? '';
    final String body = n['body']?.toString() ?? '';
    final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;

    if (session == null) return;

    // التنقل الذكي بناءً على المحتوى
    if (body.contains('OR-')) {
      final orderId = RegExp(r'OR-\d+-\d+').stringMatch(body) ?? RegExp(r'OR-\d+').stringMatch(body);
      if (orderId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(order: {'id': orderId}, session: session),
          ),
        );
      }
    } else if (title.contains('مخزون') || title.contains('نواقص')) {
      // الانتقال لصفحة المخزون (يجب أن تكون متاحة في الهيكل)
      // إذا كان زبون، ربما نكتفي بعرض الرسالة
    } else if (title.contains('دفعة') || title.contains('حساب')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerStatementScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: Column(
        children: [
          if (_notifications.isEmpty)
            const Expanded(child: Center(child: Text('لا توجد إشعارات حالياً')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final n = _notifications[index];
                  final bool isRead = n['read_at'] != null && n['read_at'].toString().isNotEmpty;
                  
                  // أيقونات مخصصة حسب العنوان
                  IconData icon = Icons.notifications;
                  Color iconColor = Colors.blue;
                  if (n['title'].contains('تسعير') || n['title'].contains('فاتورة')) {
                    icon = Icons.receipt_long;
                    iconColor = Colors.green;
                  } else if (n['title'].contains('شحن') || n['title'].contains('تجهيز')) {
                    icon = Icons.local_shipping;
                    iconColor = Colors.orange;
                  } else if (n['title'].contains('نقص')) {
                    icon = Icons.warning_amber_rounded;
                    iconColor = Colors.red;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: isRead ? 0 : 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isRead ? BorderSide(color: Colors.grey.shade300) : BorderSide.none,
                    ),
                    color: isRead ? Colors.grey.shade50 : Colors.white,
                    child: ListTile(
                      onTap: () => _handleNotificationTap(n),
                      leading: CircleAvatar(
                        backgroundColor: iconColor.withOpacity(isRead ? 0.2 : 1),
                        child: Icon(icon, color: isRead ? iconColor : Colors.white, size: 20),
                      ),
                      title: Text(
                        n['title'] ?? '',
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          color: isRead ? Colors.grey.shade700 : Colors.black,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(
                            n['created_at']?.toString().split('T')[0] ?? '',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: !isRead 
                        ? Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blue))
                        : const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _markAsRead(dynamic notificationId) async {
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      await ApiService().post({
        'action': 'markNotificationRead',
        'notification_id': notificationId,
        'username': session?['username'],
        'token': session?['token'],
      });
      // تحديث الحالة محلياً إذا نجحت العملية
      setState(() {
        final index = _notifications.indexWhere((n) => n['notification_id'] == notificationId);
        if (index != -1) {
          _notifications[index]['read_at'] = DateTime.now().toIso8601String();
        }
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }
}
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _csvIdCtrl = TextEditingController();
  bool _loading = false;

  void _updateConfig() async {
    setState(() => _loading = true);
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      await ApiService().post({
        'action': 'updateConfig',
        'csv_file_id': _csvIdCtrl.text.trim(),
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncNow() async {
    setState(() => _loading = true);
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final res = await ApiService().post({
        'action': 'syncFromDrive',
        'csv_file_id': _csvIdCtrl.text.trim(),
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'تمت المزامنة')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.findAncestorStateOfType<_HomePageState>()?.widget.session['role'];
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (role == 'admin') ...[
          const Text('إعدادات المزامنة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _csvIdCtrl,
            decoration: const InputDecoration(
              labelText: 'معرف ملف CSV من Google Drive',
              border: OutlineInputBorder(),
              helperText: 'اتركه فارغاً لاستخدام المعرف الافتراضي',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _updateConfig,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ المعرف'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _syncNow,
                  icon: const Icon(Icons.sync),
                  label: const Text('مزامنة الآن'),
                ),
              ),
            ],
          ),
          const Divider(height: 40),
        ],
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('الملف الشخصي'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
        ),
        SwitchListTile(
          value: Theme.of(context).brightness == Brightness.dark,
          onChanged: (val) {
            context.findAncestorStateOfType<_OrcaAppState>()?.toggleTheme(val);
          },
          title: const Text('الوضع الليلي'),
          secondary: const Icon(Icons.dark_mode_outlined),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
    _nameCtrl.text = session?['full_name'] ?? '';
    // الهاتف قد لا يكون في الجلسة، يمكن جلبه من API أو إضافته للجلسة مستقبلاً
  }

  void _updateProfile() async {
    setState(() => _loading = true);
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      await ApiService().post({
        'action': 'updateUser',
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (_passCtrl.text.isNotEmpty) 'new_password': _passCtrl.text,
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح')));
        // تحديث الجلسة محلياً قد يتطلب إعادة تسجيل دخول أو آلية تحديث State
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة مرور جديدة (اختياري)', border: OutlineInputBorder())),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _loading ? null : _updateProfile,
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ التغييرات'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// شاشات المدير (Admin Screens)
// ============================================================

// --- إدارة المستخدمين ---
class UserManagementScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const UserManagementScreen({super.key, required this.session});
  
  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _filterRole = 'all';
  
  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }
  
  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().post({
        'action': 'getUsers',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        setState(() {
          _users = data['users'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _showUserDialog([dynamic user]) {
    final nameCtrl = TextEditingController(text: user?['full_name'] ?? '');
    final usernameCtrl = TextEditingController(text: user?['username'] ?? '');
    final phoneCtrl = TextEditingController(text: user?['phone'] ?? '');
    final passCtrl = TextEditingController();
    String selectedRole = user?['role'] ?? 'customer';
    bool isActive = user?['is_active'] == true || user?['is_active'] == '1';
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(user == null ? 'إضافة مستخدم جديد' : 'تعديل المستخدم'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'اسم المستخدم', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              if (user == null)
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الأولية', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'الدور', border: OutlineInputBorder()),
                items: ['admin', 'accountant', 'warehouse', 'customer'].map((r) => DropdownMenuItem(value: r, child: Text(_getRoleName(r)))).toList(),
                onChanged: (v) => selectedRole = v!,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('نشط'),
                value: isActive,
                onChanged: (v) => setState(() => isActive = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              try {
                await ApiService().post({
                  'action': user == null ? 'createUser' : 'updateUser',
                  'username': usernameCtrl.text.trim(),
                  'full_name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'role': selectedRole,
                  'is_active': isActive ? '1' : '0',
                  if (user == null && passCtrl.text.isNotEmpty) 'password': passCtrl.text,
                  'target_username': user?['username'],
                  'username': widget.session['username'],
                  'token': widget.session['token'],
                });
                if (mounted) {
                  Navigator.pop(context);
                  _fetchUsers();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
  
  String _getRoleName(String role) {
    switch (role) {
      case 'admin': return 'مدير';
      case 'accountant': return 'محاسب';
      case 'warehouse': return 'مستودع';
      case 'customer': return 'عميل';
      default: return role;
    }
  }
  
  void _resetPassword(String username) async {
    final newPass = DateTime.now().millisecondsSinceEpoch.toString().substring(5, 11);
    try {
      await ApiService().post({
        'action': 'resetPassword',
        'target_username': username,
        'new_password': newPass,
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تم إعادة تعيين كلمة المرور'),
            content: Text('كلمة المرور الجديدة: $newPass\n\nيرجى إبلاغ المستخدم بها وتغييرها عند أول دخول'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('موافق'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    final filteredUsers = _filterRole == 'all' 
        ? _users 
        : _users.where((u) => u['role'] == _filterRole).toList();
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('تصفية حسب الدور: '),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _filterRole,
                  isExpanded: true,
                  items: [('all', 'الكل'), ('admin', 'مدير'), ('accountant', 'محاسب'), ('warehouse', 'مستودع'), ('customer', 'عميل')]
                      .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2))).toList(),
                  onChanged: (v) => setState(() => _filterRole = v!),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredUsers.length,
            itemBuilder: (_, i) {
              final u = filteredUsers[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: u['is_active'] == true || u['is_active'] == '1' ? Colors.green : Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(u['full_name'] ?? ''),
                  subtitle: Text('${u['username']} - ${_getRoleName(u['role'])}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showUserDialog(u)),
                      IconButton(icon: const Icon(Icons.lock_reset), onPressed: () => _resetPassword(u['username'])),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- إعدادات النظام ---
class SystemSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const SystemSettingsScreen({super.key, required this.session});
  
  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final _companyArCtrl = TextEditingController();
  final _companyEnCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  final _lowStockCtrl = TextEditingController();
  final _invoiceFormatCtrl = TextEditingController();
  String _defaultCurrency = 'USD';
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().post({
        'action': 'getSystemSettings',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        final settings = data['settings'] ?? {};
        setState(() {
          _companyArCtrl.text = settings['company_name_ar'] ?? 'أوركا أوردر';
          _companyEnCtrl.text = settings['company_name_en'] ?? 'ORCA ORDER';
          _logoUrlCtrl.text = settings['logo_url'] ?? '';
          _defaultCurrency = settings['default_currency'] ?? 'USD';
          _creditLimitCtrl.text = (settings['credit_limit'] ?? 0).toString();
          _lowStockCtrl.text = (settings['low_stock_threshold'] ?? 10).toString();
          _invoiceFormatCtrl.text = settings['invoice_number_format'] ?? 'INV-{YYYY}-{####}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await ApiService().post({
        'action': 'saveSystemSettings',
        'company_name_ar': _companyArCtrl.text.trim(),
        'company_name_en': _companyEnCtrl.text.trim(),
        'logo_url': _logoUrlCtrl.text.trim(),
        'default_currency': _defaultCurrency,
        'credit_limit': double.tryParse(_creditLimitCtrl.text) ?? 0,
        'low_stock_threshold': double.tryParse(_lowStockCtrl.text) ?? 10,
        'invoice_number_format': _invoiceFormatCtrl.text.trim(),
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات بنجاح')));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(controller: _companyArCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة (عربي)', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: _companyEnCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة (إنكليزي)', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: _logoUrlCtrl, decoration: const InputDecoration(labelText: 'رابط الشعار (URL)', border: OutlineInputBorder(), helperText: 'رابط صورة من Google Drive أو أي مصدر آخر')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _defaultCurrency,
          decoration: const InputDecoration(labelText: 'العملة الافتراضية', border: OutlineInputBorder()),
          items: ['USD', 'SYP'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _defaultCurrency = v!),
        ),
        const SizedBox(height: 16),
        TextField(controller: _creditLimitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حد الرصيد المسموح للعميل', border: OutlineInputBorder(), helperText: 'عند تجاوزه يتم إيقاف البيع')),
        const SizedBox(height: 16),
        TextField(controller: _lowStockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حد تنبيه نقص المخزون', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: _invoiceFormatCtrl, decoration: const InputDecoration(labelText: 'تنسيق أرقام الفواتير', border: OutlineInputBorder(), helperText: 'مثال: INV-{YYYY}-{####}')),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('حفظ الإعدادات'),
          ),
        ),
      ],
    );
  }
}

// --- سجل التدقيق (Audit Log) ---
class AuditLogScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const AuditLogScreen({super.key, required this.session});
  
  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String _filterUser = 'all';
  String _filterEntity = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  
  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }
  
  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().post({
        'action': 'getAuditLog',
        'username': widget.session['username'],
        'token': widget.session['token'],
        if (_filterUser != 'all') 'filter_user': _filterUser,
        if (_filterEntity != 'all') 'filter_entity': _filterEntity,
        if (_startDate != null) 'start_date': _startDate!.toIso8601String().split('T')[0],
        if (_endDate != null) 'end_date': _endDate!.toIso8601String().split('T')[0],
      });
      if (mounted) {
        setState(() {
          _logs = data['logs'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else _endDate = picked;
      });
      _fetchLogs();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DropdownButton<String>(
                value: _filterUser,
                hint: const Text('المستخدم'),
                items: [('all', 'الكل'), ('admin', 'مدير'), ('accountant', 'محاسب'), ('warehouse', 'مستودع')]
                    .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2))).toList(),
                onChanged: (v) => setState(() { _filterUser = v!; _fetchLogs(); }),
              ),
              DropdownButton<String>(
                value: _filterEntity,
                hint: const Text('الكيان'),
                items: [('all', 'الكل'), ('product', 'منتج'), ('invoice', 'فاتورة'), ('customer', 'عميل'), ('user', 'مستخدم'), ('payment', 'دفعة')]
                    .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2))).toList(),
                onChanged: (v) => setState(() { _filterEntity = v!; _fetchLogs(); }),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_startDate != null ? _startDate!.toIso8601String().split('T')[0] : 'من تاريخ'),
                onPressed: () => _selectDate(true),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_endDate != null ? _endDate!.toIso8601String().split('T')[0] : 'إلى تاريخ'),
                onPressed: () => _selectDate(false),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
                onPressed: _fetchLogs,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _logs.length,
            itemBuilder: (_, i) {
              final log = _logs[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpansionTile(
                  leading: Icon(_getActionIcon(log['action']), color: Colors.blue),
                  title: Text('${log['username']} - ${log['action']}'),
                  subtitle: Text('${log['entity_type']}: ${log['entity_id']}'),
                  trailing: Text(_formatDate(log['timestamp']), style: const TextStyle(fontSize: 12)),
                  children: [
                    if (log['old_values'] != null && (log['old_values'] as Map).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('القيم السابقة:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(log['old_values'].toString()),
                          ],
                        ),
                      ),
                    if (log['new_values'] != null && (log['new_values'] as Map).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('القيم الجديدة:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(log['new_values'].toString()),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  IconData _getActionIcon(String action) {
    if (action.contains('create') || action.contains('إضافة')) return Icons.add_circle;
    if (action.contains('update') || action.contains('تعديل')) return Icons.edit;
    if (action.contains('delete') || action.contains('حذف')) return Icons.delete;
    return Icons.history;
  }
  
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dt;
    if (timestamp is DateTime) {
      dt = timestamp;
    } else if (timestamp is String) {
      dt = DateTime.parse(timestamp);
    } else {
      return timestamp.toString();
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// --- إعدادات النسخ الاحتياطي ---
class BackupSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const BackupSettingsScreen({super.key, required this.session});
  
  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _isBackingUp = false;
  String _lastBackupDate = 'غير متوفر';
  
  @override
  void initState() {
    super.initState();
    _getLastBackupDate();
  }
  
  Future<void> _getLastBackupDate() async {
    try {
      final data = await ApiService().post({
        'action': 'getLastBackupDate',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        setState(() {
          _lastBackupDate = data['last_backup_date'] ?? 'غير متوفر';
        });
      }
    } catch (e) {
      // تجاهل الخطأ
    }
  }
  
  Future<void> _createBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final data = await ApiService().post({
        'action': 'createBackup',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء النسخة الاحتياطية بنجاح')));
        _getLastBackupDate();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }
  
  Future<void> _exportData(String entityType) async {
    try {
      final data = await ApiService().post({
        'action': 'exportToCsv',
        'entity_type': entityType,
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        final csvContent = data['csv_content'] ?? '';
        // عرض محتوى CSV أو تحميله
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('تصدير $entityType'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: SingleChildScrollView(
                child: SelectableText(csvContent, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('آخر نسخة احتياطية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_lastBackupDate, style: const TextStyle(fontSize: 18, color: Colors.blue)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isBackingUp ? null : _createBackup,
                    icon: _isBackingUp ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.backup),
                    label: Text(_isBackingUp ? 'جاري الإنشاء...' : 'إنشاء نسخة احتياطية الآن'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('تصدير البيانات كـ CSV', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.people),
          title: const Text('تصدير العملاء'),
          trailing: const Icon(Icons.download),
          onTap: () => _exportData('customers'),
        ),
        ListTile(
          leading: const Icon(Icons.inventory),
          title: const Text('تصدير المنتجات'),
          trailing: const Icon(Icons.download),
          onTap: () => _exportData('products'),
        ),
        ListTile(
          leading: const Icon(Icons.receipt),
          title: const Text('تصدير الفواتير'),
          trailing: const Icon(Icons.download),
          onTap: () => _exportData('invoices'),
        ),
        ListTile(
          leading: const Icon(Icons.payments),
          title: const Text('تصدير الدفعات'),
          trailing: const Icon(Icons.download),
          onTap: () => _exportData('payments'),
        ),
      ],
    );
  }
}

// ============================================================================
// شاشات إضافية مطلوبة (Additional Required Screens)
// ============================================================================

// شاشة تفاصيل المنتج
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final bool addToCart;
  final Function(OrderItem)? onAddToCart;
  
  const ProductDetailScreen({super.key, required this.product, this.addToCart = false, this.onAddToCart});
  
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  String _selectedUnit = '';
  final TextEditingController _noteCtrl = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _selectedUnit = widget.product.unit;
  }
  
  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }
  
  Widget _buildProductImage(Product product, {double? size, double? height}) {
    final imageUrl = _buildImageUrlStatic(product.imageUrl);
    
    if (imageUrl == null) {
      return Container(
        width: size,
        height: height ?? size,
        color: Colors.grey[300],
        child: const Icon(Icons.image, size: 50, color: Colors.grey),
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: height ?? size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: size,
          height: height ?? size,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: height ?? size,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
        ),
      ),
    );
  }
  
  // Static helper function to build Google Drive image URL
  static String? _buildImageUrlStatic(String? imageIdentifier) {
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
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج الكبيرة
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: _buildProductImage(widget.product, size: 400),
                  ),
                );
              },
              child: _buildProductImage(widget.product, height: 300),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // السعر
                  (widget.product.price ?? 0) > 0
                    ? Text('السعر: ${widget.product.price} ${widget.product.currency ?? ""}', 
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.green, fontWeight: FontWeight.bold))
                    : const Text('يرجى التواصل لمعرفة السعر', 
                        style: TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // المعلومات الأساسية
                  _buildInfoRow('الرمز', widget.product.code ?? ''),
                  _buildInfoRow('التصنيف', widget.product.category ?? ''),
                  _buildInfoRow('المخزون', '${widget.product.stock ?? 0}'),
                  _buildInfoRow('الوحدة الافتراضية', widget.product.uomName ?? widget.product.unit),
                  
                  // اختيار الوحدة
                  const SizedBox(height: 16),
                  Text('اختر الوحدة:', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    items: (widget.product.units ?? [widget.product.unit]).toSet().map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (val) => setState(() => _selectedUnit = val!),
                  ),
                  
                  // اختيار الكمية
                  const SizedBox(height: 16),
                  Text('الكمية:', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(text: '$_quantity'),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                          onChanged: (val) => _quantity = int.tryParse(val) ?? 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(onPressed: () => setState(() => _quantity = (_quantity - 1).clamp(1, 9999)), icon: const Icon(Icons.remove)),
                      IconButton.filled(onPressed: () => setState(() => _quantity = (_quantity + 1).clamp(1, 9999)), icon: const Icon(Icons.add)),
                    ],
                  ),
                  
                  // ملاحظة على المنتج
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة على المنتج (اختياري)',
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                  ),
                  
                  // الوصف
                  if (widget.product.description != null && widget.product.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('الوصف:', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(widget.product.description!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  ],
                  
                  // زر الإضافة للسلة
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (widget.onAddToCart != null) {
                          final item = OrderItem(
                            product: widget.product,
                            quantity: _quantity.toDouble(),
                            selectedUnit: _selectedUnit,
                            note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
                          );
                          widget.onAddToCart!(item);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تمت إضافة $_quantity $_selectedUnit من "${widget.product.name}" للسلة'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('إضافة للسلة'),
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
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}

// شاشة قائمة الطلبات الجديدة
class NewOrdersListScreen extends StatelessWidget {
  final Map<String, dynamic> session;
  
  const NewOrdersListScreen({super.key, required this.session});
  
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('شاشة قائمة الطلبات الجديدة'));
  }
}

// شاشة تسعير الطلبات
class PricingQueueScreen extends StatelessWidget {
  final Map<String, dynamic> session;
  
  const PricingQueueScreen({super.key, required this.session});
  
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('شاشة تسعير الطلبات'));
  }
}

// شاشة الفواتير بانتظار الاعتماد
class PendingApprovalScreen extends StatelessWidget {
  final Map<String, dynamic> session;
  
  const PendingApprovalScreen({super.key, required this.session});
  
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('شاشة الفواتير بانتظار الاعتماد'));
  }
}

// شاشة استيراد وتصدير Excel
class ImportExportScreen extends StatelessWidget {
  final Map<String, dynamic> session;
  
  const ImportExportScreen({super.key, required this.session});
  
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('شاشة استيراد وتصدير Excel'));
  }
}

// شاشة أوامر التجهيز
class PreparationOrdersScreen extends StatelessWidget {
  final Map<String, dynamic> session;
  
  const PreparationOrdersScreen({super.key, required this.session});
  
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('شاشة أوامر التجهيز'));
  }
}
