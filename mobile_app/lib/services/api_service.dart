import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../app_config.dart';

/// فئة مساعدة لإدارة عمليات المنتجات في API
class _ProductApiService {
  final ApiService _apiService;

  _ProductApiService(this._apiService);

  /// جلب المنتجات مع دعم الكاش
  Future<Map<String, dynamic>> getProducts({bool forceRefresh = false}) async {
    return _apiService.post({'action': 'getProducts'}, forceRefresh: forceRefresh);
  }

  /// البحث عن منتجات
  Future<Map<String, dynamic>> searchProducts(String query) async {
    return _apiService.post({
      'action': 'search_products',
      'query': query,
    });
  }

  /// جلب تصنيفات المنتجات
  Future<Map<String, dynamic>> getProductCategories() async {
    return _apiService.post({'action': 'get_product_categories'});
  }
}

/// فئة مساعدة لإدارة عمليات الطلبات في API
class _OrderApiService {
  final ApiService _apiService;

  _OrderApiService(this._apiService);

  /// جلب قائمة الطلبات
  Future<Map<String, dynamic>> getOrders({String? customerId, String? status}) async {
    final params = {'action': 'getOrders'};
    if (customerId != null) params['customer_id'] = customerId;
    if (status != null) params['status'] = status;
    return _apiService.post(params);
  }

  /// جلب تفاصيل الطلب
  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    return _apiService.post({
      'action': 'order_details',
      'order_id': orderId,
    });
  }

  /// إنشاء طلب جديد
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    return _apiService.post({
      'action': 'create_order',
      ...orderData,
    });
  }

  /// تحديث حالة الطلب
  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    return _apiService.post({
      'action': 'update_order_status',
      'order_id': orderId,
      'status': status,
    });
  }

  /// حفظ تسعير الطلب
  Future<Map<String, dynamic>> saveOrderPricing(String orderId, List<Map<String, dynamic>> items) async {
    return _apiService.post({
      'action': 'save_pricing',
      'order_id': orderId,
      'items': items,
    });
  }

  /// إلغاء طلب
  Future<Map<String, dynamic>> cancelOrder(String orderId, [String? reason]) async {
    final params = {
      'action': 'cancel_order',
      'order_id': orderId,
    };
    if (reason != null) params['reason'] = reason;
    return _apiService.post(params);
  }
}

/// فئة مساعدة لإدارة عمليات العملاء في API
class _CustomerApiService {
  final ApiService _apiService;

  _CustomerApiService(this._apiService);

  /// جلب بيانات العملاء
  Future<Map<String, dynamic>> getCustomers() async {
    return _apiService.post({'action': 'getCustomers'});
  }

  /// جلب كشف حساب العميل
  Future<Map<String, dynamic>> getCustomerStatement(String customerId) async {
    return _apiService.post({
      'action': 'get_customer_statement',
      'customer_id': customerId,
    });
  }

  /// إضافة عميل جديد
  Future<Map<String, dynamic>> addCustomer(Map<String, dynamic> customerData) async {
    return _apiService.post({
      'action': 'add_customer',
      ...customerData,
    });
  }

  /// تحديث بيانات عميل
  Future<Map<String, dynamic>> updateCustomer(String customerId, Map<String, dynamic> customerData) async {
    return _apiService.post({
      'action': 'update_customer',
      'customer_id': customerId,
      ...customerData,
    });
  }
}

/// فئة مساعدة لإدارة عمليات المصادقة في API
class _AuthApiService {
  final ApiService _apiService;

  _AuthApiService(this._apiService);

  /// تسجيل الدخول
  Future<Map<String, dynamic>> login(String username, String password) async {
    return _apiService.post({
      'action': 'login',
      'username': username,
      'password': password,
    });
  }

  /// تسجيل الخروج
  Future<Map<String, dynamic>> logout() async {
    return _apiService.post({'action': 'logout'});
  }

  /// تغيير كلمة المرور
  Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    return _apiService.post({
      'action': 'change_password',
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  /// التحقق من صلاحية الجلسة
  Future<Map<String, dynamic>> validateSession() async {
    return _apiService.post({'action': 'validate_session'});
  }
}

/// خدمة الاتصال مع API
/// مسؤولة عن جميع عمليات الشبكة والتخزين المؤقت
/// تم تقسيمها إلى فئات فرعية لكل مجال عمل
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // خدمات المجال المنفصلة
  late final _ProductApiService products;
  late final _OrderApiService orders;
  late final _CustomerApiService customers;
  late final _AuthApiService auth;

  void _initializeSubServices() {
    products = _ProductApiService(this);
    orders = _OrderApiService(this);
    customers = _CustomerApiService(this);
    auth = _AuthApiService(this);
  }

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

  /// التهيئة الأولية للخدمة
  void init() {
    _initializeSubServices();
  }

  /// Check if device is online
  Future<bool> isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
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
      await _cacheManager.putFile('products_cache.json', await cacheFile.readAsBytes());
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

  /// إرسال طلب POST إلى API
  /// 
  /// [body] - جسم الطلب يحتوي على action والبيانات
  /// [useCache] - استخدام التخزين المؤقت عند عدم الاتصال
  /// [forceRefresh] - تجاهل الكاش وجلب بيانات جديدة
  Future<Map<String, dynamic>> post(
    Map<String, dynamic> body, {
    bool useCache = true,
    bool forceRefresh = false,
  }) async {
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
      while ((response.statusCode == 302 || response.statusCode == 301 || 
              response.statusCode == 307 || response.statusCode == 308) && 
             redirectCount < 5) {
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

  // ==========================================
  // طرق قديمة للحفاظ على التوافقية (Deprecated)
  // يُفضل استخدام الخدمات المنفصلة بدلاً منها
  // ==========================================

  @Deprecated('استخدم ApiService().products.getProducts() بدلاً من ذلك')
  Future<Map<String, dynamic>> getProducts({bool forceRefresh = false}) async {
    return products.getProducts(forceRefresh: forceRefresh);
  }

  @Deprecated('استخدم ApiService().auth.login() بدلاً من ذلك')
  Future<Map<String, dynamic>> login(String username, String password) async {
    return auth.login(username, password);
  }

  @Deprecated('استخدم ApiService().orders.getOrders() بدلاً من ذلك')
  Future<Map<String, dynamic>> getOrders({String? customerId, String? status}) async {
    return orders.getOrders(customerId: customerId, status: status);
  }

  @Deprecated('استخدم ApiService().orders.getOrderDetails() بدلاً من ذلك')
  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    return orders.getOrderDetails(orderId);
  }

  @Deprecated('استخدم ApiService().orders.createOrder() بدلاً من ذلك')
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    return orders.createOrder(orderData);
  }

  @Deprecated('استخدم ApiService().orders.updateOrderStatus() بدلاً من ذلك')
  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    return orders.updateOrderStatus(orderId, status);
  }

  @Deprecated('استخدم ApiService().customers.getCustomers() بدلاً من ذلك')
  Future<Map<String, dynamic>> getCustomers() async {
    return customers.getCustomers();
  }

  @Deprecated('استخدم ApiService().customers.getCustomerStatement() بدلاً من ذلك')
  Future<Map<String, dynamic>> getCustomerStatement(String customerId) async {
    return customers.getCustomerStatement(customerId);
  }

  @Deprecated('استخدم ApiService().orders.saveOrderPricing() بدلاً من ذلك')
  Future<Map<String, dynamic>> saveOrderPricing(String orderId, List<Map<String, dynamic>> items) async {
    return orders.saveOrderPricing(orderId, items);
  }
}
