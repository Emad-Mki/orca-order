import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../models/product.dart';
import '../screens/notifications_screen.dart';
import '../screens/order_details_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/customer_statement_screen.dart';
import '../screens/sales_invoices_screen.dart';
import '../services/api_service.dart';
import '../utils/permissions.dart';
import 'guide_coordinator.dart';

class DeepLinkService {
  DeepLinkService._();

  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static Map<String, dynamic>? _pendingNotification;
  static bool navigationReady = false;

  static bool get hasPendingNotification => _pendingNotification != null;

  static void resetNavigator() {
    navigationReady = false;
    navigatorKey = GlobalKey<NavigatorState>();
  }

  static void clearSession() {
    _pendingNotification = null;
    navigationReady = false;
  }

  static bool canOpenForSession(
    NotificationModel notification,
    Map<String, dynamic> session,
  ) {
    final role = PermissionHelper.fromString(
      session['role']?.toString().trim() ?? '',
    );
    final targetRole = notification.targetRole?.trim() ?? '';
    final targetUser = notification.targetUserId?.trim() ?? '';
    return role != AppRole.user &&
        (targetRole.isEmpty ||
            PermissionHelper.fromString(targetRole) == role) &&
        (targetUser.isEmpty || targetUser == session['user_id']?.toString());
  }

  static Future<void> openNotification(Map<String, dynamic> data) async {
    _pendingNotification = Map<String, dynamic>.from(data);
    GuideCoordinator.interrupt();
    await resumePendingNotification();
  }

  static Future<void> resumePendingNotification() async {
    final context = navigatorKey.currentContext;
    final navigator = navigatorKey.currentState;
    final session = ApiService().currentUser;
    if (!navigationReady ||
        context == null ||
        navigator == null ||
        session == null) {
      return;
    }
    final data = _pendingNotification;
    if (data == null) return;
    _pendingNotification = null;
    final messenger = ScaffoldMessenger.maybeOf(context);

    final notification = NotificationModel.fromJson(data);
    final role = PermissionHelper.fromString(
      session['role']?.toString().trim() ?? '',
    );
    if (!canOpenForSession(notification, session)) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('لا تملك صلاحية فتح هذا الإشعار')),
      );
      return;
    }
    final uri = Uri.tryParse(notification.deepLink);
    if (uri == null || uri.hasScheme || uri.hasAuthority) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('رابط الإشعار غير صالح')),
      );
      return;
    }
    final segments = uri.pathSegments;
    final kind = segments.isNotEmpty ? segments.first : '';
    final id = segments.length > 1 ? segments[1] : '';

    try {
      if (notification.orderId != null ||
          notification.eventType.startsWith('order') ||
          notification.eventType.startsWith('shipping') ||
          kind == 'orders' ||
          kind == 'order') {
        final orderId = notification.orderId ??
            (kind == 'orders' || kind == 'order' ? id : null);
        if (orderId == null || orderId.isEmpty) return;
        if (!PermissionHelper.hasPermission(role, AppPermission.viewOrders)) {
          throw StateError('لا تملك صلاحية عرض الطلبات');
        }
        final token = ApiService().token;
        await ApiService().orders.getOrderDetails(orderId);
        if (token == null ||
            ApiService().token != token ||
            navigatorKey.currentState != navigator ||
            !navigationReady) {
          return;
        }
        navigator.push(MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(
            orderId: orderId,
            session: session,
          ),
        ));
        return;
      }

      if (notification.eventType == 'invoice.sales_created') {
        if (!PermissionHelper.hasPermission(role, AppPermission.viewOwnSales) &&
            !PermissionHelper.hasPermission(
                role, AppPermission.viewAllStatements)) {
          throw StateError('لا تملك صلاحية عرض الفواتير');
        }
        navigator.push(MaterialPageRoute(
          builder: (_) => SalesInvoicesScreen(session: session),
        ));
        return;
      }

      if (notification.invoiceId != null ||
          notification.eventType.startsWith('invoice') ||
          notification.eventType.startsWith('payment') ||
          notification.eventType.startsWith('account') ||
          kind == 'invoices' ||
          kind == 'invoice' ||
          kind == 'payment' ||
          kind == 'statement') {
        if (!PermissionHelper.hasPermission(
                role, AppPermission.viewOwnStatement) &&
            !PermissionHelper.hasPermission(
                role, AppPermission.viewAllStatements)) {
          throw StateError('لا تملك صلاحية عرض كشف الحساب');
        }
        navigator.push(MaterialPageRoute(
          builder: (_) => const CustomerStatementScreen(),
        ));
        return;
      }

      if (notification.productId != null ||
          notification.eventType.startsWith('inventory') ||
          notification.eventType.startsWith('alert') ||
          kind == 'products' ||
          kind == 'product') {
        if (!PermissionHelper.hasPermission(role, AppPermission.viewProducts)) {
          throw StateError('لا تملك صلاحية عرض المنتجات');
        }
        final productId = notification.productId ??
            (kind == 'products' || kind == 'product' ? id : null);
        if (productId == null || productId.isEmpty) return;
        final token = ApiService().token;
        final response = await ApiService().post({
          'action': 'product_search',
          'q': productId,
        });
        final products = response['products'];
        if (products is List) {
          final match = products.whereType<Map>().firstWhere(
                (product) =>
                    product['code']?.toString() == productId ||
                    product['id']?.toString() == productId,
                orElse: () => const {},
              );
          if (match.isNotEmpty &&
              token != null &&
              ApiService().token == token &&
              navigatorKey.currentState == navigator &&
              navigationReady) {
            navigatorKey.currentState!.push(MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                product: Product.fromJson(Map<String, dynamic>.from(match)),
                session: session,
              ),
            ));
            return;
          }
        }
      }
    } catch (error) {
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('تعذر فتح تفاصيل الإشعار: $error')),
        );
      }
      return;
    }

    navigator.push(MaterialPageRoute(
      builder: (_) => const NotificationsScreen(),
    ));
  }
}
