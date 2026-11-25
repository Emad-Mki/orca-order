import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/providers/products_provider.dart';
import 'package:orca_order/repositories/product_repository.dart';
import 'package:orca_order/screens/offers_admin_screen.dart';
import 'package:orca_order/services/database_service.dart';
import 'package:orca_order/services/offers_change_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Products extends ProductRepository {
  _Products(super.db);

  @override
  Future<List<Product>> getProducts({bool forceRefresh = false}) async => [
        Product(
          code: 'P1',
          name: 'منتج',
          category: '',
          origin: '',
          unit: 'قطعة',
          unit2: 'علبة',
          factor2: 10,
          units: ['قطعة', 'علبة'],
          price: 10,
          price2: 80,
        )
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProductsProvider products;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    products = ProductsProvider(_Products(db));
    await products.fetchProducts();
  });
  tearDown(() async {
    products.dispose();
    await db.close();
  });

  Widget app(String role, OfferRequest request) => ChangeNotifierProvider.value(
        value: products,
        child: MaterialApp(
          home: OffersAdminScreen(session: {'role': role}, request: request),
        ),
      );

  testWidgets('denies unauthorized users without making requests',
      (tester) async {
    var requests = 0;
    await tester.pumpWidget(app('customer', (_) async {
      requests++;
      return {};
    }));
    await tester.pumpAndSettle();
    expect(find.text('غير مصرح بإدارة العروض'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('duplicates inactive, retains unit pricing, and refreshes once',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    final initialRevision = offersRevision.value;
    final requests = <Map<String, dynamic>>[];
    final offer = <String, dynamic>{
      'offer_id': 'O1',
      'revision': 3,
      'product_code': 'P1',
      'title': 'عرض خاص',
      'unit': 'علبة',
      'old_price': 80,
      'offer_price': 60,
      'currency': 'USD',
      'min_quantity': 1,
      'enabled': true,
      'sort_order': 0,
      'status': 'active',
    };
    await tester.pumpWidget(app('manager', (body) async {
      requests.add(body);
      if (body['action'] == 'offer_save') return pending.future;
      return {
        'offers': [offer],
        'server_time': '2026-01-01T00:00:00Z'
      };
    }));
    await tester.pumpAndSettle();
    expect(find.text('عرض خاص'), findsOneWidget);
    await tester.tap(find.byTooltip('خيارات العرض'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نسخ كعرض غير مفعّل'));
    await tester.pumpAndSettle();
    expect(find.text('السعر السابق لكل علبة (USD)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('معاينة العرض'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('معاينة العرض'));
    await tester.pumpAndSettle();
    expect(find.textContaining('سعر العرض: 60.0 USD / علبة'), findsOneWidget);
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('حفظ العرض'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('حفظ العرض'));
    await tester.pump(const Duration(milliseconds: 500));
    final save = requests.singleWhere((r) => r['action'] == 'offer_save');
    final saved = save['offer'] as Map<String, dynamic>;
    expect(saved['enabled'], false);
    expect(saved.containsKey('offer_id'), false);
    expect(saved.containsKey('revision'), false);
    expect(saved['unit'], 'علبة');
    expect(saved['old_price'], 80);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(offersRevision.value, initialRevision);
    pending.complete({'offer': saved});
    await tester.pumpAndSettle();
    expect(offersRevision.value, initialRevision + 1);
    expect(requests.where((r) => r['action'] == 'offer_list').length, 2);
  });

  testWidgets('archive requires confirmation and refreshes', (tester) async {
    final requests = <Map<String, dynamic>>[];
    final initialRevision = offersRevision.value;
    await tester.pumpWidget(app('accountant', (body) async {
      requests.add(body);
      return {
        'offers': [
          {'offer_id': 'O1', 'revision': 4, 'title': 'عرض', 'status': 'active'}
        ]
      };
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('خيارات العرض'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أرشفة').last);
    await tester.pumpAndSettle();
    expect(requests.where((r) => r['action'] == 'offer_archive'), isEmpty);
    expect(offersRevision.value, initialRevision);
    await tester.tap(find.text('أرشفة').last);
    await tester.pumpAndSettle();
    expect(
        requests
            .where((r) => r['action'] == 'offer_archive')
            .single['offer_id'],
        'O1');
    expect(
        requests
            .where((r) => r['action'] == 'offer_archive')
            .single['revision'],
        4);
    expect(requests.where((r) => r['action'] == 'offer_list').length, 2);
    expect(offersRevision.value, initialRevision + 1);
  });

  testWidgets('new offer chooses catalog product and defaults unit price',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    await tester.pumpWidget(app('admin', (body) async {
      requests.add(body);
      return {'offers': []};
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عرض جديد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اختر منتجاً من الكتالوج'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'بحث بالاسم أو الرمز'), 'P1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('منتج').last);
    await tester.pumpAndSettle();
    expect(find.text('10.0'), findsOneWidget);
    await tester.tap(find.text('قطعة').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('علبة').last);
    await tester.pumpAndSettle();
    expect(find.text('80.0'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('حفظ العرض'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('حفظ العرض'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r['action'] == 'offer_save'), isEmpty);
  });
}
