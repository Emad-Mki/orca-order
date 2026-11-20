// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orca_order/app_config.dart';
import 'package:orca_order/main.dart';
import 'package:orca_order/screens/settings_screen.dart';
import 'package:orca_order/services/app_update_service.dart';

void main() {
  test('test environment does not fall back to production', () {
    if (AppConfig.isTesting) {
      expect(AppConfig.apiUrl, isEmpty);
    } else {
      expect(AppConfig.isProduction, isTrue);
    }
  });

  testWidgets('shows the Arabic login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OrcaApp());
    await tester.pumpAndSettle();

    expect(find.text('أوركا أوردر'), findsOneWidget);
    expect(find.text('اسم المستخدم'), findsOneWidget);
    expect(find.text('دخول'), findsOneWidget);
  });

  testWidgets('settings displays the active account and hides admin actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppUpdateService(),
        child: const MaterialApp(
          home: SettingsScreen(
            session: {
              'full_name': 'عميل حالي',
              'username': 'current-customer',
              'role': 'customer',
            },
          ),
        ),
      ),
    );

    expect(find.text('عميل حالي'), findsOneWidget);
    expect(find.text('عميل'), findsOneWidget);
    expect(find.text('إعدادات النظام'), findsNothing);
    expect(find.text('مزامنة البيانات'), findsNothing);
  });

  testWidgets('settings supports a small RTL screen with larger dark text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppUpdateService(),
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: const Directionality(
              textDirection: TextDirection.rtl,
              child: SettingsScreen(session: {
                'username': 'customer',
                'role': 'customer',
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
