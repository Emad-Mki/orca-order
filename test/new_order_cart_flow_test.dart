import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order.dart';
import 'package:orca_order/models/order_draft.dart';
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
import 'package:orca_order/widgets/product_card_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RetryOrdersProvider extends OrdersProvider {
  _RetryOrdersProvider(this.local, {this.firstError})
      : super(OrderRepository());

  final LocalRepository local;
  final Object? firstError;
  final requests = <Order>[];
  final savedRequestIds = <String?>[];

  @override
  Future<String> createOrder(Order order, {String? customerId}) async {
    requests.add(order);
    savedRequestIds.add((await local.getAllDrafts()).single.clientRequestId);
    if (requests.length == 1) {
      throw firstError ?? StateError('connection lost');
    }
    return 'ORDER-1';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late LocalRepository repository;
  late ProductsProvider products;
  late DraftsProvider drafts;

  final product = Product(
    code: 'A1',
    name: 'منتج',
    category: '',
    origin: '',
    unit: 'قطعة',
    unit2: 'علبة',
    factor2: 10,
    price: 5,
    price2: 40,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    repository = LocalRepository(db);
    await repository.saveProducts([product]);
    products = ProductsProvider(ProductRepository(db));
    await products.fetchProducts();
    drafts = DraftsProvider(repository);
  });

  tearDown(() async {
    products.dispose();
    drafts.dispose();
    await db.close();
  });

  Widget app({Product? initialProduct, OrderDraft? draft}) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: products),
          ChangeNotifierProvider.value(value: drafts),
        ],
        child: MaterialApp(
          home: NewOrderScreen(
            session: const {'role': 'customer', 'customer_id': 'C1'},
            initialProduct: initialProduct,
            draft: draft,
          ),
        ),
      );

  testWidgets('initial product addition merges matching line and persists',
      (tester) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(initialProduct: product));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة للطلب'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('السلة: 1 أصناف'), findsOneWidget);

    await tester.tap(find.byType(ProductCardWidget).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة للطلب'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('السلة: 1 أصناف'), findsOneWidget);
    await tester.tap(find.text('مراجعة'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '2.0');
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ProductCardWidget).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('علبة').last);
    await tester.pumpAndSettle();
    final addButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'إضافة للطلب'),
    );
    addButton.onPressed!();
    addButton.onPressed!();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('السلة: 2 أصناف'), findsOneWidget);
    final stored = await tester.runAsync(repository.getAllDrafts);
    expect(stored, isNotNull);
    final rows = stored!;
    expect(rows, hasLength(1));
    expect(rows.single.items, hasLength(2));
    expect(rows.single.items.first.quantity, 2);
    expect(rows.single.items.first.price, 5);
    expect(rows.single.items.last.unit, 'علبة');
    expect(rows.single.items.last.quantity, 1);
    expect(rows.single.items.last.price, 50);
    await tester.longPress(find.byType(ProductCardWidget).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة إلى طلب جديد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة للطلب'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final afterDetails =
        (await tester.runAsync(repository.getAllDrafts))!.single;
    expect(afterDetails.items, hasLength(2));
    expect(afterDetails.items.first.quantity, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('draft with missing product remains untouched', (tester) async {
    final id = await tester.runAsync(() => repository.saveDraft(OrderDraft(
          customerId: 'C1',
          customerName: 'عميل',
          updatedAt: DateTime.now(),
          items: [
            DraftItem(
              productCode: 'MISSING',
              productName: 'مادة قديمة',
              unit: 'قطعة',
              quantity: 3,
              price: 7,
            ),
          ],
        )));
    final draft = (await tester.runAsync(repository.getAllDrafts))!.single;
    await tester.pumpWidget(app(draft: draft));
    await tester.pumpAndSettle();
    expect(find.textContaining('المسودة الأصلية محفوظة'), findsOneWidget);
    final saved = (await tester.runAsync(repository.getAllDrafts))!.single;
    expect(saved.id, id);
    expect(saved.items.single.quantity, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pending submission remains read-only after reopening',
      (tester) async {
    final id = await tester.runAsync(() => repository.saveDraft(OrderDraft(
          customerId: 'C1',
          customerName: 'عميل',
          updatedAt: DateTime.now(),
          clientRequestId: 'REQ-persisted-123',
          note: 'original',
          items: [
            DraftItem(
              productCode: product.code,
              productName: product.name,
              unit: product.unit,
              quantity: 2,
              price: 5,
              originalProduct: product,
            ),
          ],
        )));
    final draft = (await tester.runAsync(repository.getAllDrafts))!.single;
    await tester.pumpWidget(app(draft: draft));
    await tester.pumpAndSettle();
    expect(find.textContaining('نتيجة الإرسال غير مؤكدة'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(
                find.widgetWithText(TextField, 'ملاحظات عامة للطلب (اختياري)'))
            .readOnly,
        isTrue);
    await tester.tap(find.text('مراجعة'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'زيادة الكمية'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'حذف الصنف'))
            .onPressed,
        isNull);
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    final stored = (await tester.runAsync(repository.getAllDrafts))!.single;
    expect(stored.id, id);
    expect(stored.clientRequestId, 'REQ-persisted-123');
    expect(stored.note, 'original');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'failed submission retries the persisted request without duplicates',
      (tester) async {
    final orderProvider = _RetryOrdersProvider(repository);
    addTearDown(orderProvider.dispose);
    await tester.runAsync(() => repository.saveDraft(OrderDraft(
          customerId: 'C1',
          customerName: 'عميل',
          updatedAt: DateTime.now(),
          note: 'keep',
          items: [
            DraftItem(
              productCode: product.code,
              productName: product.name,
              unit: product.unit,
              quantity: 2,
              price: 5,
              originalProduct: product,
            ),
          ],
        )));
    final draft = (await tester.runAsync(repository.getAllDrafts))!.single;
    await tester.pumpWidget(ChangeNotifierProvider<OrdersProvider>.value(
      value: orderProvider,
      child: app(draft: draft),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
    expect(orderProvider.requests, hasLength(1));
    final requestId = orderProvider.requests.single.clientRequestId;
    expect(requestId, isNotEmpty);
    expect(orderProvider.savedRequestIds.single, requestId);
    expect(
        (await tester.runAsync(repository.getAllDrafts))!.single.note, 'keep');
    expect(find.textContaining('نتيجة الإرسال غير مؤكدة'), findsOneWidget);

    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
    expect(orderProvider.requests, hasLength(2));
    expect(orderProvider.requests.last.clientRequestId, requestId);
    expect(orderProvider.savedRequestIds.last, requestId);
    expect(await tester.runAsync(repository.getAllDrafts), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('confirmed first-attempt validation error unlocks the draft',
      (tester) async {
    final orderProvider = _RetryOrdersProvider(repository,
        firstError: const ApiException(
            code: 'PRODUCT_NOT_FOUND', message: 'المنتج غير موجود'));
    addTearDown(orderProvider.dispose);
    await tester.runAsync(() => repository.saveDraft(OrderDraft(
          customerId: 'C1',
          customerName: 'عميل',
          updatedAt: DateTime.now(),
          items: [
            DraftItem(
              productCode: product.code,
              productName: product.name,
              unit: product.unit,
              quantity: 2,
              price: 5,
              originalProduct: product,
            ),
          ],
        )));
    final draft = (await tester.runAsync(repository.getAllDrafts))!.single;
    await tester.pumpWidget(ChangeNotifierProvider<OrdersProvider>.value(
      value: orderProvider,
      child: app(draft: draft),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
    expect(orderProvider.savedRequestIds.single, isNotEmpty);
    expect(
        (await tester.runAsync(repository.getAllDrafts))!
            .single
            .clientRequestId,
        isNull);
    expect(find.textContaining('نتيجة الإرسال غير مؤكدة'), findsNothing);
    await tester.tap(find.text('مراجعة'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'زيادة الكمية'))
            .onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('validation on an uncertain retry keeps the original key locked',
      (tester) async {
    final orderProvider = _RetryOrdersProvider(repository,
        firstError: const ApiException(
            code: 'PRODUCT_NOT_FOUND', message: 'المنتج غير موجود'));
    addTearDown(orderProvider.dispose);
    await tester.runAsync(() => repository.saveDraft(OrderDraft(
          customerId: 'C1',
          customerName: 'عميل',
          clientRequestId: 'REQ-pending',
          updatedAt: DateTime.now(),
          items: [
            DraftItem(
              productCode: product.code,
              productName: product.name,
              unit: product.unit,
              quantity: 2,
              price: 5,
              originalProduct: product,
            ),
          ],
        )));
    final draft = (await tester.runAsync(repository.getAllDrafts))!.single;
    await tester.pumpWidget(ChangeNotifierProvider<OrdersProvider>.value(
      value: orderProvider,
      child: app(draft: draft),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
    expect(
        (await tester.runAsync(repository.getAllDrafts))!
            .single
            .clientRequestId,
        'REQ-pending');
    expect(find.textContaining('نتيجة الإرسال غير مؤكدة'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
