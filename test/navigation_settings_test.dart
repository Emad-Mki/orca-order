import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order.dart';
import 'package:orca_order/models/notification_model.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/providers/notification_provider.dart';
import 'package:orca_order/providers/products_provider.dart';
import 'package:orca_order/repositories/notification_repository.dart';
import 'package:orca_order/repositories/product_repository.dart';
import 'package:orca_order/screens/homepage_screen.dart';
import 'package:orca_order/screens/order_edit_screen.dart';
import 'package:orca_order/screens/profile_screen.dart';
import 'package:orca_order/screens/system_settings_screen.dart';
import 'package:orca_order/services/database_service.dart';
import 'package:orca_order/utils/permissions.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reset ignores notification responses from the previous session',
    () async {
      final repository = _PendingNotifications();
      final provider = NotificationProvider(repository);
      final request = provider.load();
      provider.reset();
      repository.pending.complete([
        NotificationModel.fromJson({
          'notification_id': 'old',
          'title': 'old session',
        }),
      ]);
      await request;
      expect(provider.notifications, isEmpty);
      expect(provider.isLoading, isFalse);
      provider.dispose();
    },
  );

  test(
    'an in-flight product request can finish after session disposal',
    () async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(NativeDatabase.memory());
      final repository = _PendingProducts(db);
      final provider = ProductsProvider(repository);
      final request = provider.fetchProducts();
      await Future<void>.delayed(Duration.zero);
      provider.dispose();
      repository.pending.complete([]);
      await request;
      await db.close();
    },
  );

  testWidgets('back closes menu, returns to home, then confirms exit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final products = ProductsProvider(ProductRepository(db));
    final notifications = NotificationProvider(NotificationRepository());
    final homeKey = GlobalKey<HomePageState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: products),
          ChangeNotifierProvider.value(value: notifications),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: HomePage(
              key: homeKey,
              session: const {'role': 'customer'},
              onLogout: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.image(const AssetImage('assets/images/logo.png')),
      findsOneWidget,
    );
    await tester.tap(find.text('المزيد'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('المزيد من الخيارات'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('المزيد من الخيارات'), findsNothing);
    expect(find.text('هل تريد إغلاق التطبيق؟'), findsNothing);

    await tester.tap(find.text('المنتجات').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(homeKey.currentState!.selectedIndex, 1);
    await tester.enterText(
      find.widgetWithText(TextField, 'ابحث بالاسم أو الرمز أو OEM'),
      'OEM-123',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(homeKey.currentState!.selectedIndex, 1);
    expect(find.text('هل تريد إغلاق التطبيق؟'), findsNothing);
    tester.view.resetViewInsets();
    tester.testTextInput.hide();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(homeKey.currentState!.selectedIndex, 2);
    expect(find.text('هل تريد إغلاق التطبيق؟'), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(-450, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(homeKey.currentState!.selectedIndex, 1);
    expect(find.text('OEM-123'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(homeKey.currentState!.selectedIndex, 2);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('هل تريد إغلاق التطبيق؟'), findsOneWidget);
    await tester.tap(find.text('متابعة الاستخدام'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
    products.dispose();
    notifications.dispose();
    await db.close();
  });

  testWidgets('order edits require confirmation before discarding', (
    tester,
  ) async {
    final order = Order(
      orderId: '1',
      orderNumber: 'ORD-1',
      customerId: '1',
      customerName: 'عميل',
      status: 'pending',
      currency: 'USD',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      OrderEditScreen(order: order, role: AppRole.customer),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'تعديل');
    tester.testTextInput.hide();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('تعديلات غير محفوظة'), findsOneWidget);
    await tester.tap(find.text('متابعة التحرير'));
    await tester.pumpAndSettle();
    expect(find.text('تعديل'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('تجاهل التعديلات'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('system settings offers only supported entry points', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SystemSettingsScreen(session: {'role': 'admin'})),
    );
    expect(find.text('المبيعات والعملات'), findsOneWidget);
    expect(find.text('الجهاز والحساب والمزامنة'), findsOneWidget);
    expect(find.text('تنسيق أرقام الفواتير'), findsNothing);
    expect(find.text('حد الرصيد المسموح للعميل'), findsNothing);
  });

  testWidgets('profile edits are not discarded without confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(
                    session: {'full_name': 'الاسم الأصلي'},
                  ),
                ),
              ),
              child: const Text('open profile'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'اسم جديد');
    tester.testTextInput.hide();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('تعديلات غير محفوظة'), findsOneWidget);
    await tester.tap(find.text('متابعة التحرير'));
    await tester.pumpAndSettle();
    expect(find.text('اسم جديد'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('تجاهل التعديلات'));
    await tester.pumpAndSettle();
    expect(find.text('open profile'), findsOneWidget);
  });
}

class _PendingNotifications extends NotificationRepository {
  final pending = Completer<List<NotificationModel>>();

  @override
  Future<List<NotificationModel>> getNotifications({
    bool forceRefresh = false,
  }) =>
      pending.future;
}

class _PendingProducts extends ProductRepository {
  _PendingProducts(super.db);

  final pending = Completer<List<Product>>();

  @override
  Future<List<Product>> getProducts({bool forceRefresh = false}) =>
      pending.future;
}
