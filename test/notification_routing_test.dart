import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/notification_model.dart';
import 'package:orca_order/services/deep_link_service.dart';
import 'package:orca_order/services/fcm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android denied status is prompted once when not yet requested', () {
    expect(
      FcmService.shouldRequestPermission(
        status: AuthorizationStatus.denied,
        prompted: false,
        isAndroid: true,
      ),
      isTrue,
    );
    expect(
      FcmService.shouldRequestPermission(
        status: AuthorizationStatus.denied,
        prompted: true,
        isAndroid: true,
      ),
      isFalse,
    );
    expect(
      FcmService.shouldRequestPermission(
        status: AuthorizationStatus.denied,
        prompted: false,
        isAndroid: false,
      ),
      isFalse,
    );
  });

  test('empty entity ids do not turn a general notice into an order', () {
    final notification = NotificationModel.fromJson({
      'order_id': '',
      'invoice_id': '',
      'product_id': '',
      'screenRoute': '/notifications',
    });
    expect(notification.orderId, isNull);
    expect(notification.invoiceId, isNull);
    expect(notification.productId, isNull);
    expect(notification.deepLink, '/notifications');
  });

  test('role and recipient are checked against the active session', () {
    final notification = NotificationModel.fromJson({
      'target_role': 'customer',
      'target_user_id': 'customer-1',
    });
    expect(
      DeepLinkService.canOpenForSession(
        notification,
        {'role': 'زبون', 'user_id': 'customer-1'},
      ),
      isTrue,
    );
    expect(
      DeepLinkService.canOpenForSession(
        notification,
        {'role': 'customer', 'user_id': 'customer-2'},
      ),
      isFalse,
    );
    expect(
      DeepLinkService.canOpenForSession(
        notification,
        {'role': 'admin', 'user_id': 'customer-1'},
      ),
      isFalse,
    );
    expect(
      DeepLinkService.canOpenForSession(
        NotificationModel.fromJson({}),
        {'role': 'unrecognized', 'user_id': 'customer-1'},
      ),
      isFalse,
    );
  });

  test('logout clears notification routes queued for the previous account',
      () async {
    DeepLinkService.navigationReady = false;
    await DeepLinkService.openNotification({
      'notification_id': 'old-account-notice',
      'title': 'Old account',
      'screenRoute': '/notifications',
    });
    expect(DeepLinkService.hasPendingNotification, isTrue);
    DeepLinkService.clearSession();
    expect(DeepLinkService.hasPendingNotification, isFalse);
    expect(DeepLinkService.navigationReady, isFalse);
  });
}
