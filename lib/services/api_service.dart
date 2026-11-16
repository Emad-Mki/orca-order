import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../app_config.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final bool retryable;
  final String? requestId;

  const ApiException({
    required this.code,
    required this.message,
    this.retryable = false,
    this.requestId,
  });

  @override
  String toString() => message;
}

class _TimedProductResponse {
  final Map<String, dynamic> response;
  final DateTime cachedAt;

  const _TimedProductResponse(this.response, this.cachedAt);
}

const _actionAliases = <String, String>{
  'getProducts': 'product_list',
  'products': 'product_list',
  'search_products': 'product_search',
  'searchProducts': 'product_search',
  'getProductCategories': 'product_categories',
  'get_product_categories': 'product_categories',
  'getOrders': 'order_list',
  'getOrderDetails': 'order_details',
  'createOrder': 'create_order',
  'updateOrderStatus': 'order_status_update',
  'update_order_status': 'order_status_update',
  'price_order': 'order_price',
  'updateOrderPricing': 'order_price',
  'cancel_order': 'order_cancel',
  'cancelOrder': 'order_cancel',
  'deleteOrder': 'order_delete',
  'delete_order': 'order_delete',
  'getCustomers': 'customer_list',
  'add_customer': 'customer_create',
  'createCustomer': 'customer_create',
  'update_customer': 'customer_update',
  'updateCustomer': 'customer_update',
  'getCustomerStatement': 'customer_statement',
  'get_customer_statement': 'customer_statement',
  'getPayments': 'payment_list',
  'record_payment': 'recordPayment',
  'add_payment': 'recordPayment',
  'addPayment': 'recordPayment',
  'getInventoryMovements': 'inventory_movements',
  'getShipments': 'shipment_list',
  'updateShipmentStatus': 'shipment_status_update',
  'shipment': 'shipment_save',
  'createLowStockRequest': 'low_stock_create',
  'getLowStockRequests': 'low_stock_list',
  'getNotifications': 'notification_list',
  'markNotificationRead': 'notification_read',
  'markNotificationAsRead': 'notification_read',
  'sendNotification': 'notification_send',
  'syncFromDrive': 'sync_drive',
  'updateConfig': 'config_update',
  'getReports': 'reports',
  'getDashboardStats': 'dashboard_stats',
  'getBestSellers': 'best_sellers',
  'getNewProducts': 'new_products',
  'change_password': 'user_update',
};

/// فئة مساعدة لإدارة عمليات المنتجات في API
class ProductApiService {
  static const Duration _dashboardResponseCacheDuration = Duration(seconds: 30);

  final ApiService _apiService;
  final Map<String, Future<Map<String, dynamic>>> _requests = {};
  final Map<String, _TimedProductResponse> _responseCache = {};
  final Map<String, DateTime> _lastManualRefreshByResource = {};
  final Map<String, DateTime> _lastRefreshNoticeByAccount = {};
  final Map<String, bool> _throttledResources = {};

  ProductApiService(this._apiService);

  void clearCachedResponses() {
    _responseCache.clear();
    _lastManualRefreshByResource.clear();
    _lastRefreshNoticeByAccount.clear();
    _throttledResources.clear();
  }

  bool shouldShowRefreshThrottleNotice() {
    final accountKey =
        '${_apiService.currentUser?['user_id'] ?? ''}:${_apiService.token ?? ''}';
    final lastNotice = _lastRefreshNoticeByAccount[accountKey];
    if (lastNotice != null &&
        DateTime.now().difference(lastNotice) <
            ApiService.minimumManualRefreshInterval) {
      return false;
    }
    _lastRefreshNoticeByAccount[accountKey] = DateTime.now();
    return true;
  }

  bool wasRefreshThrottled(String resource) =>
      _throttledResources[_scopedRequestKey(resource)] ?? false;

  Duration refreshRemaining(String resource) {
    final lastRefresh =
        _lastManualRefreshByResource[_scopedRequestKey(resource)];
    if (lastRefresh == null) return Duration.zero;
    final remaining = ApiService.minimumManualRefreshInterval -
        DateTime.now().difference(lastRefresh);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String _scopedRequestKey(String resource) =>
      '$resource:${_apiService.currentUser?['user_id'] ?? ''}:${_apiService.token ?? ''}';

  Future<Map<String, dynamic>> _singleFlight(
    String key,
    Future<Map<String, dynamic>> Function() request,
  ) {
    final activeRequest = _requests[key];
    if (activeRequest != null) return activeRequest;

    final nextRequest = request();
    _requests[key] = nextRequest;
    return nextRequest.whenComplete(() {
      if (identical(_requests[key], nextRequest)) _requests.remove(key);
    });
  }

  /// جلب المنتجات مع دعم الكاش
  Future<Map<String, dynamic>> getProducts({bool forceRefresh = false}) async {
    return _singleFlight(
      _scopedRequestKey('products'),
      () => _apiService.post(
        {'action': 'getProducts'},
        forceRefresh: forceRefresh,
      ),
    );
  }

  Future<Map<String, dynamic>> getNewProducts({
    bool forceRefresh = false,
  }) {
    return _cachedDashboardRequest(
      'new_products',
      'getNewProducts',
      forceRefresh: forceRefresh,
    );
  }

  Future<Map<String, dynamic>> getBestSellers({
    bool forceRefresh = false,
  }) {
    return _cachedDashboardRequest(
      'best_sellers',
      'getBestSellers',
      forceRefresh: forceRefresh,
    );
  }

  Future<Map<String, dynamic>> _cachedDashboardRequest(
    String resource,
    String action, {
    required bool forceRefresh,
  }) {
    final key = _scopedRequestKey(resource);
    final requestToken = _apiService.token;
    final activeRequest = _requests[key];
    if (activeRequest != null) return activeRequest;

    final cached = _responseCache[key];
    if (forceRefresh && refreshRemaining(resource) > Duration.zero) {
      _throttledResources[key] = true;
      if (cached != null) {
        return Future<Map<String, dynamic>>.value(cached.response);
      }
      throw const ApiException(
        code: 'REFRESH_THROTTLED',
        message: 'يرجى الانتظار قليلًا قبل التحديث مجددًا',
      );
    }

    if (forceRefresh) {
      _lastManualRefreshByResource[key] = DateTime.now();
    }
    _throttledResources[key] = false;

    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.cachedAt) <
            _dashboardResponseCacheDuration) {
      return Future<Map<String, dynamic>>.value(cached.response);
    }

    return _singleFlight(
      key,
      () async {
        final response = await _apiService.post({'action': action});
        if (_apiService.token == requestToken) {
          _responseCache[key] = _TimedProductResponse(response, DateTime.now());
        }
        return response;
      },
    );
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

  Future<Map<String, dynamic>> createProduct(
      Map<String, dynamic> product) async {
    return _apiService.post({'action': 'product_create', ...product});
  }

  Future<Map<String, dynamic>> updateProductPrice({
    required String code,
    required double price,
    String? currency,
  }) async {
    return _apiService.post({
      'action': 'product_price_update',
      'code': code,
      'display_price': price,
      if (currency != null) 'currency': currency,
    });
  }
}

/// فئة مساعدة لإدارة عمليات الطلبات في API
class OrderApiService {
  final ApiService _apiService;

  OrderApiService(this._apiService);

  /// جلب قائمة الطلبات
  Future<Map<String, dynamic>> getOrders(
      {String? customerId, String? status}) async {
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
  Future<Map<String, dynamic>> createOrder(
      Map<String, dynamic> orderData) async {
    return _apiService.post({
      'action': 'create_order',
      ...orderData,
    });
  }

  /// تحديث حالة الطلب
  Future<Map<String, dynamic>> updateOrderStatus(
      String orderId, String status) async {
    return _apiService.post({
      'action': 'update_order_status',
      'order_id': orderId,
      'status': status,
    });
  }

  Future<Map<String, dynamic>> editOrder({
    required String orderId,
    required String note,
    required List<Map<String, dynamic>> items,
  }) async {
    return _apiService.post({
      'action': 'edit_order',
      'order_id': orderId,
      'note': note,
      'items': items,
    });
  }

  Future<Map<String, dynamic>> confirmWarehousePrep({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required String warehouseNote,
  }) async {
    return _apiService.post({
      'action': 'confirmWarehousePrep',
      'order_id': orderId,
      'items': items,
      'warehouse_note': warehouseNote,
    });
  }

  /// حفظ تسعير الطلب
  Future<Map<String, dynamic>> saveOrderPricing({
    required String orderId,
    required List<Map<String, dynamic>> items,
    double? subtotal,
    double? total,
    String? notes,
    bool submitForCustomer = false,
    Map<String, dynamic>? extraParams,
  }) async {
    final payload = {
      'action': 'price_order',
      'order_id': orderId,
      'items': items,
      'subtotal': subtotal,
      'total': total,
      'notes': notes,
      'submitForCustomer': submitForCustomer,
      if (extraParams != null) ...extraParams,
    };
    return _apiService.post(payload);
  }

  /// إلغاء طلب
  Future<Map<String, dynamic>> cancelOrder(String orderId,
      [String? reason]) async {
    final params = {
      'action': 'cancel_order',
      'order_id': orderId,
    };
    if (reason != null) params['reason'] = reason;
    return _apiService.post(params);
  }
}

/// فئة مساعدة لإدارة عمليات العملاء في API
class CustomerApiService {
  final ApiService _apiService;

  CustomerApiService(this._apiService);

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
  Future<Map<String, dynamic>> addCustomer(
      Map<String, dynamic> customerData) async {
    return _apiService.post({
      'action': 'add_customer',
      ...customerData,
    });
  }

  /// تحديث بيانات عميل
  Future<Map<String, dynamic>> updateCustomer(
      String customerId, Map<String, dynamic> customerData) async {
    return _apiService.post({
      'action': 'update_customer',
      'customer_id': customerId,
      ...customerData,
    });
  }
}

/// فئة مساعدة لإدارة عمليات المصادقة في API
class AuthApiService {
  final ApiService _apiService;

  AuthApiService(this._apiService);

  /// تسجيل الدخول
  Future<Map<String, dynamic>> login(String username, String password) async {
    final requestTimer = Stopwatch()..start();
    late final Map<String, dynamic> data;
    try {
      data = await _apiService.post({
        'action': 'login',
        'username': username,
        'password': password,
      });
    } finally {
      if (kDebugMode) {
        debugPrint('login_api_request_ms=${requestTimer.elapsedMilliseconds}');
      }
    }

    if (data['ok'] == true || data['success'] == true) {
      final rawSession = data['session'];
      if (rawSession is! Map ||
          rawSession['token'] is! String ||
          (rawSession['token'] as String).isEmpty) {
        throw const ApiException(
          code: 'INVALID_RESPONSE',
          message: 'استجابة تسجيل الدخول لا تحتوي على جلسة صالحة',
        );
      }
      final session = Map<String, dynamic>.from(rawSession)
        ..['user_id'] = rawSession['user_id'] ?? rawSession['id']
        ..['id'] = rawSession['id'] ?? rawSession['user_id']
        ..['full_name'] = rawSession['full_name'] ?? rawSession['name']
        ..['name'] = rawSession['name'] ?? rawSession['full_name'];
      final sessionTimer = Stopwatch()..start();
      await _apiService.setSession(session['token'] as String, session);
      if (kDebugMode) {
        debugPrint(
            'login_session_persist_ms=${sessionTimer.elapsedMilliseconds}');
      }
      data['session'] = session;
      data['user'] = data['user'] ?? session;
    }
    return data;
  }

  /// تسجيل الخروج
  Future<Map<String, dynamic>> logout({String? deviceId}) async {
    Object? logoutError;
    try {
      if (_apiService.token != null) {
        await _apiService.post({
          'action': 'logout',
          if (deviceId != null) 'device_id': deviceId,
        });
      }
    } catch (error) {
      logoutError = error;
    }

    await _apiService.setSession(null);
    await ApiService._cacheManager.emptyCache();
    if (logoutError != null) throw logoutError;
    return {'success': true};
  }

  /// مسح الكاش المحلي للبيانات الحساسة
  Future<void> clearLocalCache() async {
    await ApiService._cacheManager.emptyCache();
  }

  /// تغيير كلمة المرور
  Future<Map<String, dynamic>> changePassword(
      String oldPassword, String newPassword) async {
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

/// فئة مساعدة لإدارة العمليات الإدارية في API
class AdminApiService {
  final ApiService _apiService;

  AdminApiService(this._apiService);

  /// جلب سجل التدقيق
  Future<Map<String, dynamic>> getAuditLogs() async {
    return _apiService.post({'action': 'getAuditLogs'});
  }

  /// تنفيذ نسخة احتياطية
  Future<Map<String, dynamic>> backupData() async {
    return _apiService.post({'action': 'backupData'});
  }
}

class SalesApiService {
  final ApiService _apiService;

  SalesApiService(this._apiService);

  Future<Map<String, dynamic>> getConfiguration() =>
      _apiService.post({'action': 'sales_configuration'});

  Future<List<Map<String, dynamic>>> getCustomers({String query = ''}) async {
    final response = await _apiService.post({
      'action': 'sales_customer_list',
      if (query.trim().isNotEmpty) 'query': query.trim(),
    });
    final rows = response['customers'];
    if (rows is! List) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'استجابة قائمة زبائن المبيعات غير صالحة',
      );
    }
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> createCustomer({
    required String fullName,
    String phone = '',
    required String clientRequestId,
  }) =>
      _apiService.post({
        'action': 'sales_customer_create',
        'full_name': fullName,
        'phone': phone,
        'client_request_id': clientRequestId,
      });

  Future<Map<String, dynamic>> getSettings() =>
      _apiService.post({'action': 'sales_settings_get'});

  Future<Map<String, dynamic>> saveSettings(
    Map<String, dynamic> settings,
  ) =>
      _apiService.post({'action': 'sales_settings_update', ...settings});

  Future<Map<String, dynamic>> createInvoice(
    Map<String, dynamic> invoice,
  ) =>
      _apiService.post({'action': 'sales_invoice_create', ...invoice});

  Future<Map<String, dynamic>> createCustomerReceipt(
    Map<String, dynamic> receipt,
  ) =>
      _apiService.post({'action': 'customer_receipt_create', ...receipt});

  Future<Map<String, dynamic>> collectInvoicePayment(
    Map<String, dynamic> collection,
  ) =>
      _apiService.post({'action': 'sales_invoice_collect', ...collection});

  Future<Map<String, dynamic>> allocateReceipt({
    required String receiptId,
    required String invoiceId,
    required double amountUsd,
    required String clientRequestId,
  }) =>
      _apiService.post({
        'action': 'sales_invoice_allocate',
        'receipt_id': receiptId,
        'invoice_id': invoiceId,
        'amount_usd': amountUsd,
        'client_request_id': clientRequestId,
      });

  Future<Map<String, dynamic>> getCashBoxStatement({
    required String boxName,
    required String currency,
  }) =>
      _apiService.post({
        'action': 'cash_box_statement',
        'box_name': boxName,
        'currency': currency,
      });

  Future<Map<String, dynamic>> getCashBoxBalances() =>
      _apiService.post({'action': 'box_balances'});

  Future<Map<String, dynamic>> setCashBoxOpeningBalance({
    required String boxName,
    required String currency,
    required double amount,
    required String reason,
    double? exchangeRate,
    required String clientRequestId,
  }) =>
      _apiService.post({
        'action': 'cash_box_opening_balance',
        'box_name': boxName,
        'currency': currency,
        'amount': amount,
        'reason': reason,
        if (exchangeRate != null) 'exchange_rate': exchangeRate,
        'client_request_id': clientRequestId,
      });

  Future<List<Map<String, dynamic>>> getSalespeople() async {
    final response = await _apiService.post({'action': 'salespeople_list'});
    final rows = response['salespeople'];
    if (rows is! List) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'استجابة قائمة المندوبين غير صالحة',
      );
    }
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> voidInvoice({
    required String invoiceId,
    required String reason,
  }) =>
      _apiService.post({
        'action': 'sales_invoice_void',
        'invoice_id': invoiceId,
        'reason': reason,
      });

  Future<Map<String, dynamic>> getInvoices({
    String query = '',
    String? fromDate,
    String? toDate,
    String? paymentMethod,
    String? status,
    String? financialStatus,
    String? customerId,
    String? sellerId,
  }) =>
      _apiService.post({
        'action': 'sales_invoice_list',
        if (query.trim().isNotEmpty) 'query': query.trim(),
        if (fromDate != null) 'from_date': fromDate,
        if (toDate != null) 'to_date': toDate,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (status != null) 'status': status,
        if (financialStatus != null) 'financial_status': financialStatus,
        if (customerId != null) 'customer_id': customerId,
        if (sellerId != null) 'seller_id': sellerId,
      });

  Future<Map<String, dynamic>> getSummary({
    String? fromDate,
    String? toDate,
    String? sellerId,
    String? customerId,
  }) =>
      _apiService.post({
        'action': 'sales_summary',
        if (fromDate != null) 'from_date': fromDate,
        if (toDate != null) 'to_date': toDate,
        if (sellerId != null) 'seller_id': sellerId,
        if (customerId != null) 'customer_id': customerId,
      });
}

/// خدمة الاتصال مع API
class ApiService {
  static const Duration minimumManualRefreshInterval = Duration(seconds: 15);
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _initializeSubServices();
  }

  // خدمات المجال المنفصلة
  late final ProductApiService products;
  late final OrderApiService orders;
  late final CustomerApiService customers;
  late final AuthApiService auth;
  late final AdminApiService admin;
  late final SalesApiService sales;

  String? _sessionToken;
  Map<String, dynamic>? _currentUser;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  void Function()? onSessionExpired;
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Duration _loginRequestTimeout = Duration(seconds: 90);

  Duration _timeoutForAction(String action) =>
      action == 'login' ? _loginRequestTimeout : _requestTimeout;

  String get _productsCacheKey {
    final account =
        _currentUser?['user_id'] ?? _currentUser?['customer_id'] ?? 'anonymous';
    final role = _currentUser?['role'] ?? 'anonymous';
    final environment = AppConfig.environmentName;
    return 'products_${environment}_${account}_$role.json'
        .replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  }

  void _initializeSubServices() {
    products = ProductApiService(this);
    orders = OrderApiService(this);
    customers = CustomerApiService(this);
    auth = AuthApiService(this);
    admin = AdminApiService(this);
    sales = SalesApiService(this);
  }

  /// تهيئة الجلسة من التخزين المحلي
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSession = await _secureStorage.read(key: 'orca_session');
    if (savedSession != null) {
      final session = jsonDecode(savedSession);
      if (session is Map<String, dynamic> &&
          session['token'] is String &&
          (session['token'] as String).isNotEmpty &&
          session['user'] is Map<String, dynamic>) {
        _sessionToken = session['token'] as String;
        _currentUser = Map<String, dynamic>.from(session['user'] as Map);
      } else {
        await _secureStorage.delete(key: 'orca_session');
      }
    } else {
      final legacyToken = prefs.getString('session_token');
      final legacyUser = prefs.getString('current_user');
      if (legacyToken != null && legacyToken.isNotEmpty && legacyUser != null) {
        final decodedUser = jsonDecode(legacyUser);
        if (decodedUser is Map<String, dynamic>) {
          _sessionToken = legacyToken;
          _currentUser = Map<String, dynamic>.from(decodedUser);
          await _secureStorage.write(
            key: 'orca_session',
            value: jsonEncode({'token': _sessionToken, 'user': _currentUser}),
          );
        }
      }
    }

    await prefs.remove('session_token');
    await prefs.remove('current_user');
    await prefs.remove('saved_pass');
    await prefs.remove('saved_user');
  }

  /// تحديث بيانات الجلسة
  Future<void> setSession(String? token, [Map<String, dynamic>? user]) async {
    if (token != null && token.trim().isEmpty) {
      throw const FormatException('رمز الجلسة غير صالح');
    }

    final previousToken = _sessionToken;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      _sessionToken = null;
      _currentUser = null;
      await _secureStorage.delete(key: 'orca_session');
    } else {
      final sessionUser = Map<String, dynamic>.from(user ?? _currentUser ?? {});
      sessionUser['token'] = token;
      await _secureStorage.write(
        key: 'orca_session',
        value: jsonEncode({'token': token, 'user': sessionUser}),
      );
      _sessionToken = token;
      _currentUser = sessionUser;
    }
    if (previousToken != _sessionToken) products.clearCachedResponses();
    await prefs.remove('session_token');
    await prefs.remove('current_user');
    await prefs.remove('saved_pass');
    await prefs.remove('saved_user');
  }

  String? get token => _sessionToken;
  Map<String, dynamic>? get currentUser => _currentUser;

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
      final List<ConnectivityResult> connectivityResult =
          await Connectivity().checkConnectivity();
      return connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Get cached products from local storage
  Future<List<Map<String, dynamic>>> getCachedProducts() async {
    try {
      final cacheKey = _productsCacheKey;
      final file = await _cacheManager.getFileFromCache(cacheKey);
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

  /// Get the last time products were cached
  Future<DateTime?> getLastCacheTimestamp() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheFile = File('${tempDir.path}/$_productsCacheKey');
      if (await cacheFile.exists()) {
        final content = await cacheFile.readAsString();
        final data = jsonDecode(content);
        if (data['timestamp'] != null) {
          return DateTime.parse(data['timestamp']);
        }
      }
    } catch (e) {
      print('Error getting cache timestamp: $e');
    }
    return null;
  }

  /// Save products to cache
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheKey = _productsCacheKey;
      final cacheFile = File('${tempDir.path}/$cacheKey');
      await cacheFile.writeAsString(jsonEncode({
        'products': products,
        'timestamp': DateTime.now().toIso8601String()
      }));
      await _cacheManager.putFile(cacheKey, await cacheFile.readAsBytes());
    } catch (e) {
      print('Error caching products: $e');
    }
  }

  /// إرسال طلب POST إلى API
  Future<Map<String, dynamic>> post(
    Map<String, dynamic> body, {
    bool useCache = true,
    bool forceRefresh = false,
  }) async {
    final requestedAction = body['action']?.toString();
    if (requestedAction == null || requestedAction.isEmpty) {
      throw const ApiException(
        code: 'INVALID_REQUEST',
        message: 'عملية API مطلوبة',
      );
    }

    final action = _actionAliases[requestedAction] ?? requestedAction;
    final requestTimeout = _timeoutForAction(action);
    final requestBody = Map<String, dynamic>.from(body)..['action'] = action;
    const publicActions = {'login'};
    if (!publicActions.contains(action)) {
      final token = _sessionToken;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          code: 'AUTH_REQUIRED',
          message: 'انتهت الجلسة، يرجى تسجيل الدخول مجدداً',
        );
      }
      requestBody.remove('sessionToken');
      requestBody['token'] = token;
    } else {
      requestBody.remove('token');
      requestBody.remove('sessionToken');
    }

    final String cleanUrl = AppConfig.apiUrl.trim().replaceAll(' ', '');
    if (cleanUrl.isEmpty || cleanUrl.contains('PASTE_')) {
      throw const ApiException(
        code: 'API_NOT_CONFIGURED',
        message: 'إعداد رابط API لهذه البيئة غير مكتمل',
      );
    }

    http.Client? client;
    final requestTimer = Stopwatch()..start();
    var responseBytes = 0;
    try {
      client = http.Client();
      final uri = Uri.parse(cleanUrl);
      final requestStartedAt = DateTime.now();
      if (!uri.hasScheme ||
          !uri.hasAuthority ||
          !{'https', 'http'}.contains(uri.scheme)) {
        throw const ApiException(
          code: 'API_NOT_CONFIGURED',
          message: 'رابط API غير صالح',
        );
      }

      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(requestTimeout);
      responseBytes = utf8.encode(response.body).length;

      // التعامل مع إعادة التوجيه في Apps Script (302)
      if (response.statusCode == 302) {
        final location = response.headers['location'];
        if (location != null) {
          final remaining =
              requestTimeout - DateTime.now().difference(requestStartedAt);
          if (remaining <= Duration.zero) {
            throw TimeoutException('API request timed out');
          }
          final redirectedResponse =
              await client.get(Uri.parse(location)).timeout(remaining);
          responseBytes = utf8.encode(redirectedResponse.body).length;
          final result =
              await _handleResponse(redirectedResponse, requestBody, useCache);
          if (kDebugMode) {
            debugPrint(
                'api_request_ms action=$action elapsed=${requestTimer.elapsedMilliseconds} response_bytes=$responseBytes');
          }
          return result;
        }
      }

      final result = await _handleResponse(response, requestBody, useCache);
      if (kDebugMode) {
        debugPrint(
            'api_request_ms action=$action elapsed=${requestTimer.elapsedMilliseconds} response_bytes=$responseBytes');
      }
      return result;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint(
            'api_request_timeout action=$action elapsed=${requestTimer.elapsedMilliseconds}');
      }
      throw const ApiException(
        code: 'TIMEOUT',
        message: 'انتهت مهلة الاتصال بالخادم',
        retryable: true,
      );
    } on SocketException {
      if (kDebugMode) {
        debugPrint(
            'api_request_network_error action=$action elapsed=${requestTimer.elapsedMilliseconds}');
      }
      final cached = await _offlineProductsResponse(
        action,
        useCache: useCache,
        forceRefresh: forceRefresh,
        requestToken: requestBody['token']?.toString(),
      );
      if (cached != null) return cached;
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'فشل الاتصال بالخادم، تحقق من شبكة الإنترنت',
        retryable: true,
      );
    } on http.ClientException {
      if (kDebugMode) {
        debugPrint(
            'api_request_client_error action=$action elapsed=${requestTimer.elapsedMilliseconds}');
      }
      final cached = await _offlineProductsResponse(
        action,
        useCache: useCache,
        forceRefresh: forceRefresh,
        requestToken: requestBody['token']?.toString(),
      );
      if (cached != null) return cached;
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'خطأ في الاتصال بالخادم',
        retryable: true,
      );
    } catch (e) {
      rethrow;
    } finally {
      client?.close();
    }
  }

  Future<Map<String, dynamic>?> _offlineProductsResponse(
    String action, {
    required bool useCache,
    required bool forceRefresh,
    required String? requestToken,
  }) async {
    if (action != 'product_list' ||
        !useCache ||
        forceRefresh ||
        requestToken != _sessionToken) {
      return null;
    }
    final products = await getCachedProducts();
    if (products.isEmpty) return null;
    return {
      'ok': true,
      'success': true,
      'api_version': '1.3.0',
      'data': {'products': products},
      'products': products,
      'cached': true,
    };
  }

  Future<Map<String, dynamic>> _handleResponse(
    http.Response response,
    Map<String, dynamic> body,
    bool useCache,
  ) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        code: 'HTTP_${response.statusCode}',
        message: response.statusCode >= 500
            ? 'خطأ في الخادم الداخلي (${response.statusCode})'
            : 'رفض الخادم الطلب (HTTP ${response.statusCode})',
        retryable: response.statusCode >= 500,
      );
    }

    final bodyText = response.body.trim();

    // التعامل مع ردود HTML (غالباً أخطاء Apps Script أو صفحة دخول Google)
    if (bodyText.startsWith('<!DOCTYPE html>') ||
        bodyText.startsWith('<html')) {
      if (bodyText.contains('Google Account')) {
        throw const ApiException(
          code: 'DEPLOYMENT_AUTH_REQUIRED',
          message: 'يجب مراجعة صلاحيات نشر Web App في Apps Script',
        );
      }
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'استجابة غير صالحة من الخادم (HTML)',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(bodyText);
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'استجابة غير صالحة: تعذر قراءة بيانات JSON',
      );
    }

    if (decoded is! Map) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'استجابة غير صالحة: الشكل المتوقع لكائن JSON',
      );
    }

    final data = Map<String, dynamic>.from(decoded);
    final okFlag = data['ok'];
    final successFlag = data['success'];
    if ((okFlag != null && okFlag is! bool) ||
        (successFlag != null && successFlag is! bool) ||
        (okFlag is bool && successFlag is bool && okFlag != successFlag)) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'استجابة غير صالحة: تناقض حالة نجاح الطلب',
      );
    }

    final isOk = okFlag is bool ? okFlag : successFlag;
    if (isOk is! bool) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'استجابة غير صالحة: حالة النجاح غير موجودة',
      );
    }

    final requestId = data['request_id']?.toString();
    if (!isOk) {
      final rawError = data['error'];
      final error = rawError is Map ? rawError : const <String, dynamic>{};
      final code = error['code']?.toString() ??
          (rawError is String ? 'SERVER_ERROR' : 'SERVER_ERROR');
      final message = error['message']?.toString() ??
          (rawError is String ? rawError : data['message']?.toString()) ??
          'حدث خطأ أثناء معالجة الطلب';
      if (const {
        'AUTH_REQUIRED',
        'SESSION_EXPIRED',
        'ACCOUNT_INACTIVE',
        'ROLE_NOT_ALLOWED',
      }.contains(code)) {
        await setSession(null);
        onSessionExpired?.call();
      }
      throw ApiException(
        code: code,
        message: message,
        retryable: error['retryable'] == true,
        requestId: requestId,
      );
    }

    data['ok'] = true;
    data['success'] = true;
    data.putIfAbsent('api_version', () => 'legacy');
    if (data['session_revoked'] == true) {
      await setSession(null);
      onSessionExpired?.call();
    }
    if (useCache &&
        body['action'] == 'product_list' &&
        body['token'] == _sessionToken) {
      final resultData = data['data'] is Map ? data['data'] : data;
      final products = resultData['products'] ?? data['products'];
      if (products is List && products.every((item) => item is Map)) {
        await cacheProducts(
          products
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(),
        );
      }
    }

    return data;
  }
}
