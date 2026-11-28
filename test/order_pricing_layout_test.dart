import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/providers/order_detail_provider.dart';
import 'package:orca_order/repositories/local_repository.dart';
import 'package:orca_order/repositories/order_repository.dart';
import 'package:orca_order/screens/order_pricing_screen.dart';
import 'package:orca_order/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PricingRepository extends OrderRepository {
  _PricingRepository(this.order);

  final Order order;

  @override
  Future<Order?> getOrderDetails(String orderId) async => order;
}

void main() {
  for (final size in [const Size(320, 640), const Size(800, 900)]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'pricing screen handles large text and keyboard at $size in $brightness',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final database = AppDatabase(NativeDatabase.memory());
        await LocalRepository(database).saveProducts([
          Product(
            code: 'P1',
            name: 'قطعة أولى',
            category: 'اختبار',
            origin: 'اختبار',
            unit: 'قطعة',
            price: 20,
          ),
          Product(
            code: 'P2',
            name: 'قطعة ثانية',
            category: 'اختبار',
            origin: 'اختبار',
            unit: 'علبة',
            price: 10,
          ),
        ]);
        final order = Order.fromJson({
          'order_id': 'ORDER-1',
          'order_number': 'ORD-2601-00001',
          'customer_name': 'زبون تجريبي',
          'status': 'pending',
          'currency': 'USD',
          'discount_input': '10%',
          'accounting_invoice_no': 12345.0,
          'items': [
            {
              'item_id': 'ITEM-1',
              'code': 'P1',
              'name': 'قطعة أولى',
              'unit': 'قطعة',
              'unit_1': 'قطعة',
              'quantity_requested': 2,
              'quantity_approved': 2,
              'price_offer': 20,
              'final_price': 20,
              'suggested_price': 18,
              'suggested_price_factor': 1,
              'suggested_price_currency': 'USD',
              'wholesale_price': 15,
              'quantity_price': 12,
              'quantity_threshold': 2,
              'quantity_unit': 'قطعة',
              'status': 'available',
            },
            {
              'item_id': 'ITEM-2',
              'code': 'P2',
              'name': 'قطعة ثانية',
              'unit': 'علبة',
              'unit_1': 'علبة',
              'quantity_requested': 3,
              'quantity_approved': 3,
              'price_offer': 10,
              'final_price': 10,
              'status': 'available',
            },
          ],
        });
        final provider = OrderDetailProvider(_PricingRepository(order));
        addTearDown(provider.dispose);
        addTearDown(database.close);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AppDatabase>.value(value: database),
              ChangeNotifierProvider<OrderDetailProvider>.value(
                  value: provider),
            ],
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MediaQuery(
                            data: const MediaQueryData(
                              textScaler: TextScaler.linear(1.7),
                            ),
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: OrderPricingScreen(
                                order: Order(
                                  orderId: 'ORDER-1',
                                  orderNumber: 'ORD-2601-00001',
                                  customerId: 'CUSTOMER-1',
                                  customerName: 'زبون تجريبي',
                                  status: 'pending',
                                  currency: 'USD',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('فتح التسعير'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('فتح التسعير'));
        await tester.pumpAndSettle();

        expect(provider.currentOrder, isNotNull);
        expect(provider.items, hasLength(2));
        expect(find.text('قطعة أولى'), findsOneWidget);
        expect(find.byType(ActionChip), findsNWidgets(3));
        final previousPrice = find.widgetWithText(
          ActionChip,
          'السعر السابق للزبون: 18 USD / قطعة',
        );
        expect(previousPrice, findsOneWidget);
        await tester.ensureVisible(previousPrice);
        await tester.pumpAndSettle();
        await tester.tap(previousPrice);
        await tester.pump();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextFormField && widget.controller?.text == '18',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        final itemField = find.byType(TextFormField).first;
        await tester.showKeyboard(itemField);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
