import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/screens/sales_settings_screen.dart';
import 'package:orca_order/services/api_service.dart';

Map<String, dynamic> salesSettings() => {
      'invoice_currency': 'USD',
      'sham_cash_currency': 'USD',
      'default_product_currency': 'USD',
      'rate_syp_per_usd': 14500,
      'usd_decimals': 2,
      'syp_decimals': 0,
    };

void main() {
  testWidgets('load failure is visible and retry can recover', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: SalesSettingsScreen(
        loadSettings: () async {
          if (attempts++ == 0) throw StateError('الشبكة غير متاحة');
          return {'settings': salesSettings()};
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('الشبكة غير متاحة'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('سعر الصرف (SYP لكل 1 USD)'), findsOneWidget);
  });

  testWidgets('invalid rate cannot be saved', (tester) async {
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      home: SalesSettingsScreen(
        loadSettings: () async => {'settings': salesSettings()},
        saveSettings: (_) async {
          saves++;
          return {};
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'سعر الصرف (SYP لكل 1 USD)'),
      '-3',
    );
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('حفظ الإعدادات'));
    await tester.tap(find.text('حفظ الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('أكمل إعداد العملات والدقة، وتحقق من سعر الصرف.'),
        findsOneWidget);
    expect(saves, 0);
  });

  testWidgets('conflict keeps edits and sends the original version',
      (tester) async {
    Map<String, dynamic>? submitted;
    final initial = salesSettings();
    await tester.pumpWidget(MaterialApp(
      home: SalesSettingsScreen(
        loadSettings: () async => {'settings': initial},
        saveSettings: (value) async {
          submitted = value;
          throw const ApiException(
            code: 'SALES_SETTINGS_CONFLICT',
            message: 'تغيرت الإعدادات لدى مستخدم آخر',
          );
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'سعر الصرف (SYP لكل 1 USD)'),
      '15000',
    );
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('حفظ الإعدادات'));
    await tester.tap(find.text('حفظ الإعدادات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد الحفظ'));
    await tester.pumpAndSettle();
    expect(submitted?['expected_settings'], initial);
    expect(submitted?['rate_syp_per_usd'], '15000');
    expect(find.text('تغيرت الإعدادات لدى مستخدم آخر'), findsOneWidget);
    expect(find.text('15000'), findsOneWidget);
    expect(find.text('توجد تعديلات غير محفوظة'), findsOneWidget);
  });

  testWidgets('successful save reloads persisted settings', (tester) async {
    final stored = salesSettings();
    await tester.pumpWidget(MaterialApp(
      home: SalesSettingsScreen(
        loadSettings: () async =>
            {'settings': Map<String, dynamic>.from(stored)},
        saveSettings: (value) async {
          expect(value['expected_settings']['rate_syp_per_usd'], 14500);
          stored['rate_syp_per_usd'] = 16000;
          return {'settings': Map<String, dynamic>.from(stored)};
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'سعر الصرف (SYP لكل 1 USD)'),
      '16000',
    );
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('حفظ الإعدادات'));
    await tester.tap(find.text('حفظ الإعدادات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد الحفظ'));
    await tester.pumpAndSettle();
    expect(find.text('16000'), findsOneWidget);
    expect(find.text('توجد تعديلات غير محفوظة'), findsNothing);
    expect(find.text('تم حفظ إعدادات البيع'), findsOneWidget);
  });

  testWidgets('back asks before discarding settings and then returns',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SalesSettingsScreen(
                  loadSettings: () async => {'settings': salesSettings()},
                ),
              ),
            ),
            child: const Text('open settings'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open settings'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'سعر الصرف (SYP لكل 1 USD)'),
      '15000',
    );
    tester.testTextInput.hide();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('تعديلات غير محفوظة'), findsOneWidget);
    await tester.tap(find.text('تجاهل التعديلات'));
    await tester.pumpAndSettle();
    expect(find.text('open settings'), findsOneWidget);
  });
}
