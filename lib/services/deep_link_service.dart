import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../models/product.dart';
import '../screens/notifications_screen.dart';
import '../screens/order_details_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/customer_statement_screen.dart';
import '../services/api_service.dart';

class DeepLinkService {
  DeepLinkService._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> openNotification(Map<String, dynamic> data) async {
    final context = navigatorKey.currentContext;
    final navigator = navigatorKey.currentState;
    final session = ApiService().currentUser;
    if (context == null || navigator == null || session == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);

    final notification = NotificationModel.fromJson(data);
    final uri = Uri.tryParse(notification.deepLink);
    final segments = uri?.pathSegments ?? const <String>[];
    final kind = segments.isNotEmpty ? segments.first : '';
    final id = segments.length > 1 ? segments[1] : '';

    try {
      if (notification.orderId != null ||
          notification.eventType.startsWith('order') ||
          notification.eventType.startsWith('shipping') ||
          kind == 'orders') {
        final orderId = notification.orderId ?? (kind == 'orders' ? id : null);
        if (orderId == null || orderId.isEmpty) return;
        navigator.push(MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(
            orderId: orderId,
            session: session,
          ),
        ));
        return;
      }

      if (notification.invoiceId != null ||
          notification.eventType.startsWith('invoice') ||
          notification.eventType.startsWith('payment') ||
          notification.eventType.startsWith('account') ||
          kind == 'invoices' ||
          kind == 'statement') {
        navigator.push(MaterialPageRoute(
          builder: (_) => const CustomerStatementScreen(),
        ));
        return;
      }

      if (notification.productId != null ||
          notification.eventType.startsWith('inventory') ||
          notification.eventType.startsWith('alert') ||
          kind == 'products') {
        final productId =
            notification.productId ?? (kind == 'products' ? id : null);
        if (productId == null || productId.isEmpty) return;
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
          if (match.isNotEmpty && navigatorKey.currentState != null) {
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
