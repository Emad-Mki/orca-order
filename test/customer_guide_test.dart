import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/notification_model.dart';
import 'package:orca_order/providers/notification_provider.dart';
import 'package:orca_order/providers/products_provider.dart';
import 'package:orca_order/repositories/notification_repository.dart';
import 'package:orca_order/repositories/product_repository.dart';
import 'package:orca_order/screens/homepage_screen.dart';
import 'package:orca_order/screens/settings_screen.dart';
import 'package:orca_order/services/app_update_service.dart';
import 'package:orca_order/services/database_service.dart';
import 'package:orca_order/services/guide_coordinator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyNotifications extends NotificationRepository {
  @override
  Future<List<NotificationModel>> getNotifications(
          {bool forceRefresh = false}) async =>
      [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings guide reaches offscreen notification and theme steps',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    GuideCoordinator.ready = true;
    addTearDown(() => GuideCoordinator.ready = false);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppUpdateService(),
      child: const MaterialApp(
        home: SettingsScreen(
          session: {'role': 'customer', 'user_id': 'settings-user'},
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (final description in [
      'تحقق من تحديث التطبيق وتفاصيل الإصدار من هنا.',
      'راجع حالة الإشعارات وأعد مزامنة الجهاز عند الحاجة.',
      'اختر المظهر الفاتح أو الداكن أو إعداد الجهاز.',
    ]) {
      expect(find.text(description), findsOneWidget);
      await tester.tap(find.text('التالي'));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('guide.settings.v1.settings-user'), 'completed');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('customer guide persists skip and supports manual replay',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'guide.settings.v1.guide-user': 'skipped',
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final db = AppDatabase(NativeDatabase.memory());
    final products = ProductsProvider(ProductRepository(db));
    final notifications = NotificationProvider(_EmptyNotifications());
    final gate = Completer<void>();

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: products),
        ChangeNotifierProvider.value(value: notifications),
        ChangeNotifierProvider(create: (_) => AppUpdateService()),
      ],
      child: MaterialApp(
        home: HomePage(
          session: const {'role': 'customer', 'user_id': 'guide-user'},
          onLogout: () {},
          tutorialGate: gate.future,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('guide.home.v1.guide-user'), isNull);
    expect(find.text('تخطي'), findsNothing);
    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تخطي'), findsOneWidget);
    expect(prefs.getString('guide.home.v1.guide-user'), isNull);
    GuideCoordinator.interrupt();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تخطي'), findsNothing);
    expect(prefs.getString('guide.home.v1.guide-user'), isNull);
    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(find.text('إعادة عرض الشرح'), 200,
        scrollable: find
            .descendant(
                of: find.byType(SettingsScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('إعادة عرض الشرح'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('تخطي'), findsOneWidget);
    await tester.tap(find.text('تخطي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(prefs.getString('guide.home.v1.guide-user'), 'skipped');
    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(find.text('إعادة عرض الشرح'), 200,
        scrollable: find
            .descendant(
                of: find.byType(SettingsScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('إعادة عرض الشرح'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (var index = 0; index < 3; index++) {
      expect(find.text('التالي'), findsOneWidget, reason: 'step $index');
      await tester.tap(find.text('التالي'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(prefs.getString('guide.home.v1.guide-user'), 'completed');
    await tester.pumpWidget(const SizedBox());
    products.dispose();
    notifications.dispose();
    await db.close();
    debugDefaultTargetPlatformOverride = null;
  });
}
