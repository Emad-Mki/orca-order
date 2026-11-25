import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order.dart';
import 'package:orca_order/models/order_draft.dart';
import 'package:orca_order/models/order_item.dart';
import 'package:orca_order/models/order_offer.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/providers/drafts_provider.dart';
import 'package:orca_order/providers/orders_provider.dart';
import 'package:orca_order/providers/products_provider.dart';
import 'package:orca_order/repositories/local_repository.dart';
import 'package:orca_order/repositories/order_repository.dart';
import 'package:orca_order/repositories/product_repository.dart';
import 'package:orca_order/screens/new_order_screen.dart';
import 'package:orca_order/services/api_service.dart';
import 'package:orca_order/services/database_service.dart';
import 'package:orca_order/widgets/cart_summary_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Orders extends OrdersProvider {
  _Orders() : super(OrderRepository());
  final requests = <Order>[];
  Object? nextError;

  @override
  Future<String> createOrder(Order order, {String? customerId}) async {
    requests.add(order);
    if (nextError != null) {
      final error = nextError!;
      nextError = null;
      throw error;
    }
    throw StateError('uncertain network failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final product = Product(
    code: 'A',
    name: 'منتج',
    category: '',
    origin: '',
    unit: 'قطعة',
    unit2: 'علبة',
    factor2: 10,
    price: 5,
    price2: 40,
  );
  final bundleProduct = Product(
    code: 'B',
    name: 'منتج آخر',
    category: '',
    origin: '',
    unit: 'قطعة',
    price: 20,
  );
  Map<String, dynamic> offer({int revision = 1, double price = 30}) => {
        'offer_id': 'O1',
        'product_code': 'A',
        'title': 'عرض',
        'unit': 'علبة',
        'currency': 'USD',
        'offer_price': price,
        'min_quantity': 2,
        'revision': revision,
        'enabled': true,
        'status': 'active',
        'starts_at': '2026-01-01T00:00:00Z',
        'ends_at': '2027-01-01T00:00:00Z',
      };
  final serverTime = DateTime.parse('2026-06-01T00:00:00Z');

  test('offer terms validate server time, minimum, unit and status', () {
    final value = OrderOffer(offer());
    bool valid(OrderOffer o, {double quantity = 2, String unit = 'علبة'}) =>
        o.usableFor(
          code: 'A',
          selectedUnit: unit,
          itemCurrency: 'USD',
          quantity: quantity,
          serverTime: serverTime,
        );
    expect(valid(value), isTrue);
    expect(valid(value, quantity: 1), isFalse);
    expect(valid(value, unit: 'قطعة'), isFalse);
    expect(valid(OrderOffer(offer(price: 0))), isFalse);
    expect(valid(OrderOffer({...offer(), 'status': 'paused'})), isFalse);
    expect(valid(OrderOffer({...offer(), 'ends_at': '2026-06-01T00:00:00Z'})),
        isFalse);
    expect(value.sameTerms(OrderOffer(offer(revision: 2))), isFalse);
  });

  test('historical offer snapshot preserves only fields returned by server',
      () {
    final item = OrderItem.fromJson({
      'offer_id': 'O1',
      'offer_revision': 2,
      'code': 'A',
      'unit': 'علبة',
      'currency': 'USD',
      'unit_price_snapshot': 30,
      'offer_old_price': 40,
      'offer_min_quantity': 2,
      'offer_starts_at': '2026-01-01T00:00:00Z',
      'offer_ends_at': '2027-01-01T00:00:00Z',
    });
    expect(item.offer!.id, 'O1');
    expect(item.offer!.revision, '2');
    expect(item.offer!.price, 30);
    expect(item.offer!.minimum, 2);
    final redacted = OrderItem.fromJson({'offer_id': 'O1', 'code': 'A'});
    expect(redacted.offer!.price, isNull);
    expect(redacted.offer!.data.containsKey('old_price'), isFalse);
    expect(OrderItem.fromJson({'offer_id': ''}).offer, isNull);
  });

  late AppDatabase db;
  late LocalRepository local;
  late ProductsProvider products;
  late DraftsProvider drafts;
  late _Orders orders;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    local = LocalRepository(db);
    await local.saveProducts([product, bundleProduct]);
    products = ProductsProvider(ProductRepository(db));
    await products.fetchProducts();
    drafts = DraftsProvider(local);
    orders = _Orders();
  });
  tearDown(() async {
    products.dispose();
    drafts.dispose();
    orders.dispose();
    await db.close();
  });

  Widget app(Future<Map<String, dynamic>> Function() loader,
          {OrderDraft? draft,
          Map<String, dynamic>? initialOffer,
          Future<Map<String, dynamic>> Function()? productLoader}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: products),
          ChangeNotifierProvider.value(value: drafts),
          ChangeNotifierProvider<OrdersProvider>.value(value: orders),
        ],
        child: MaterialApp(
          home: NewOrderScreen(
            session: const {'role': 'customer', 'customer_id': 'C1'},
            initialProduct: draft == null ? product : null,
            initialOffer: draft == null ? initialOffer ?? offer() : null,
            draft: draft,
            offerLoader: loader,
            productLoader: productLoader ??
                () async => {
                      'products': [product.toJson()],
                    },
          ),
        ),
      );

  Future<void> wait(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
  }

  testWidgets('zero-price initial offer cannot enter cart', (tester) async {
    await tester.pumpWidget(app(
      () async => {'server_time': serverTime.toIso8601String(), 'offers': []},
      initialOffer: offer(price: 0),
    ));
    await tester.pumpAndSettle();
    expect(find.text('إضافة للطلب'), findsNothing);
    expect(find.textContaining('بيانات العرض غير مكتملة'), findsOneWidget);
    expect(orders.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('initial bundle offer opens with all component details',
      (tester) async {
    final bundleOffer = {
      ...offer(),
      'old_price': 85,
      'offer_price': 65,
      'bundle_items': [
        {
          'product_code': 'A',
          'product_name': product.name,
          'unit': 'قطعة',
          'quantity': 5,
          'old_price': 5,
          'offer_price': 4,
        },
        {
          'product_code': 'B',
          'product_name': bundleProduct.name,
          'unit': 'قطعة',
          'quantity': 3,
          'old_price': 20,
          'offer_price': 15,
        },
      ],
    };
    await tester.pumpWidget(app(
      () async => {'server_time': serverTime.toIso8601String(), 'offers': []},
      initialOffer: bundleOffer,
    ));
    await tester.pumpAndSettle();
    expect(find.text('محتويات الحزمة وأسعار كل قطعة:'), findsOneWidget);
    expect(find.text('إضافة الحزمة للطلب'), findsOneWidget);
    await tester.tap(find.text('إضافة الحزمة للطلب'));
    await wait(tester);
    expect(find.text('تمت إضافة 1.0 حزمة كاملة إلى الطلب'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('changed offer requires confirmation and persists retry payload',
      (tester) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(app(() async {
      calls++;
      return {
        'server_time': serverTime.toIso8601String(),
        'offers': [offer(revision: 2, price: 35)],
      };
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('الحد الأدنى 2.0 علبة'), findsOneWidget);
    expect(find.text('2.0'), findsOneWidget);
    await tester.tap(find.text('إضافة للطلب'));
    await wait(tester);
    final saved = (await tester.runAsync(local.getAllDrafts))!.single;
    expect(saved.items.single.offer!.revision, '1');
    expect(saved.items.single.unit, 'علبة');
    expect(saved.items.single.quantity, 2);

    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تغيرت شروط العرض'), findsOneWidget);
    expect(orders.requests, isEmpty);
    await tester.tap(find.text('العودة للمراجعة'));
    await tester.pumpAndSettle();
    expect(orders.requests, isEmpty);

    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('أوافق على الأسعار'));
    await wait(tester);
    expect(orders.requests, hasLength(1));
    final item = orders.requests.single.items!.single.toJson();
    expect(item['offer_id'], 'O1');
    expect(item['offer_revision'], '2');
    expect(item['offer_price'], 35);
    final pending = (await tester.runAsync(local.getAllDrafts))!.single;
    expect(pending.items.single.offer!.revision, '2');
    expect(pending.clientRequestId, isNotEmpty);

    await tester.tap(find.text('تأكيد وإرسال'));
    await wait(tester);
    expect(orders.requests, hasLength(2));
    expect(orders.requests.last.clientRequestId, pending.clientRequestId);
    expect(orders.requests.last.items!.single.toJson()['offer_price'], 35);
    expect(calls, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unavailable offer needs explicit regular-price confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(() async => {
          'server_time': serverTime.toIso8601String(),
          'offers': [],
        }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة للطلب'));
    await wait(tester);
    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('السعر العادي المقترح 40.0'), findsOneWidget);
    expect(orders.requests, isEmpty);
    await tester.tap(find.text('أوافق على الأسعار'));
    await wait(tester);
    final item = orders.requests.single.items!.single.toJson();
    expect(item.containsKey('offer_id'), isFalse);
    expect(item['price_offer'], 40);
    expect(item['expected_unit_price'], 40);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unchanged offer still requires refreshed price confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(() async => {
          'server_time': serverTime.toIso8601String(),
          'offers': [offer()],
        }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة للطلب'));
    await wait(tester);
    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تأكيد أسعار العروض'), findsOneWidget);
    expect(find.textContaining('سعر العرض الحالي 30.0'), findsOneWidget);
    expect(orders.requests, isEmpty);
    await tester.tap(find.text('أوافق على الأسعار'));
    await wait(tester);
    expect(orders.requests.single.items!.single.offer!.id, 'O1');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offline offer refresh blocks submission', (tester) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(() async => throw StateError('offline')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة للطلب'));
    await wait(tester);
    await tester.tap(find.text('تأكيد وإرسال'));
    await wait(tester);
    expect(orders.requests, isEmpty);
    final saved = (await tester.runAsync(local.getAllDrafts))!.single;
    expect(saved.clientRequestId, isNull);
    expect(saved.items.single.offer!.id, 'O1');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('below minimum needs confirmation for refreshed regular price',
      (tester) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => local.saveDraft(OrderDraft(
          customerId: 'C1',
          customerName: 'عميل',
          updatedAt: DateTime.now(),
          items: [
            DraftItem(
              productCode: product.code,
              productName: product.name,
              unit: 'علبة',
              quantity: 1,
              price: 30,
              originalProduct: product,
              offer: OrderOffer(offer()),
            ),
          ],
        )));
    final draft = (await tester.runAsync(local.getAllDrafts))!.single;
    await tester.pumpWidget(app(
        () async => {
              'server_time': serverTime.toIso8601String(),
              'offers': [offer()],
            },
        draft: draft));
    await tester.pumpAndSettle();
    OrderItem cartItem() => tester
        .widget<CartSummaryWidget>(find.byType(CartSummaryWidget))
        .cartItems
        .single;
    expect(cartItem().displayPrice, 40);
    expect(cartItem().total, 40);
    await tester.tap(find.text('مراجعة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('السعر العادي التقديري'), findsOneWidget);
    await tester.tap(find.byTooltip('زيادة الكمية'));
    await tester.pump();
    expect(cartItem().offer!.id, 'O1');
    expect(cartItem().displayPrice, 30);
    expect(cartItem().total, 60);
    await tester.tap(find.byTooltip('إنقاص الكمية'));
    await tester.pump();
    expect(cartItem().displayPrice, 40);
    expect(cartItem().total, 40);
    await tester.tap(find.text('إغلاق'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('الكمية أقل من الحد الأدنى'), findsOneWidget);
    expect(orders.requests, isEmpty);
    await tester.tap(find.text('أوافق على الأسعار'));
    await wait(tester);
    expect(orders.requests.single.items!.single.offer, isNull);
    expect(orders.requests.single.items!.single.priceOffer, 40);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('server OFFER_CHANGED unlocks an uncertain retry',
      (tester) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => local.saveDraft(OrderDraft(
          customerId: 'C1',
          customerName: 'عميل',
          updatedAt: DateTime.now(),
          clientRequestId: 'REQ-pending',
          items: [
            DraftItem(
              productCode: product.code,
              productName: product.name,
              unit: 'علبة',
              quantity: 2,
              price: 30,
              originalProduct: product,
              offer: OrderOffer(offer()),
            ),
          ],
        )));
    final draft = (await tester.runAsync(local.getAllDrafts))!.single;
    orders.nextError =
        const ApiException(code: 'OFFER_CHANGED', message: 'Offer changed');
    await tester.pumpWidget(app(
        () async => {
              'server_time': serverTime.toIso8601String(),
              'offers': [offer(revision: 2, price: 35)],
            },
        draft: draft));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد وإرسال'));
    await wait(tester);
    expect(orders.requests.single.clientRequestId, 'REQ-pending');
    expect(orders.requests.single.items!.single.offer!.revision, '1');
    final saved = (await tester.runAsync(local.getAllDrafts))!.single;
    expect(saved.clientRequestId, isNull);
    expect(find.textContaining('تغير العرض قبل الإرسال'), findsOneWidget);
    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تغيرت شروط العرض'), findsOneWidget);
    expect(orders.requests, hasLength(1));
    await tester.tap(find.text('العودة للمراجعة'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('PRICE_CHANGED refreshes and reconfirms fallback price',
      (tester) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var regularPrice = 40.0;
    orders.nextError =
        const ApiException(code: 'PRICE_CHANGED', message: 'Price changed');
    await tester.pumpWidget(app(
      () async => {
        'server_time': serverTime.toIso8601String(),
        'offers': [],
      },
      productLoader: () async => {
        'products': [
          {...product.toJson(), 'price_2': regularPrice}
        ],
      },
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة للطلب'));
    await wait(tester);
    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('أوافق على الأسعار'));
    await wait(tester);
    expect(orders.requests.single.items!.single.toJson()['expected_unit_price'],
        40);
    final saved = (await tester.runAsync(local.getAllDrafts))!.single;
    expect(saved.clientRequestId, isNull);
    expect(saved.items.single.expectedUnitPrice, 40);
    regularPrice = 45;
    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('السعر العادي الحالي 45.0'), findsOneWidget);
    expect(orders.requests, hasLength(1));
    await tester.tap(find.text('أوافق على الأسعار'));
    await wait(tester);
    expect(
        orders.requests.last.items!.single.toJson()['expected_unit_price'], 45);
    expect(orders.requests.last.clientRequestId,
        isNot(orders.requests.first.clientRequestId));
    await tester.pumpWidget(const SizedBox());
  });
}
