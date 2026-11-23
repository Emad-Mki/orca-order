import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order_item.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/widgets/cart_summary_widget.dart';
import 'package:orca_order/services/guide_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final product = Product(
    code: 'P1',
    name: 'منتج',
    category: '',
    origin: '',
    unit: 'piece',
    price: 5,
    unit2: 'box',
    factor2: 10,
    price2: 40,
  );

  testWidgets('review quantities, unit and removal update the live cart',
      (tester) async {
    final cart = [
      OrderItem.fromProduct(product,
          quantity: 2, selectedUnit: 'piece', overridePrice: 3, note: 'note'),
      OrderItem.fromProduct(product, quantity: 1, selectedUnit: 'box'),
    ];
    var submissions = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () => CartSummaryWidget.showReviewDialog(
              context: context,
              cartItems: cart,
              onSubmit: () async => submissions++,
              onRemoveItem: cart.remove,
              onUpdateItem: (item, quantity, unit) {
                final index = cart.indexOf(item);
                if (unit == item.selectedUnit) {
                  item.quantity = quantity;
                } else {
                  cart[index] = OrderItem.fromProduct(product,
                      quantity: quantity, selectedUnit: unit, note: item.note);
                }
              },
            ),
            child: const Text('open'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('زيادة الكمية').first);
    await tester.tap(find.byTooltip('زيادة الكمية').first);
    await tester.pump();
    expect(cart.first.quantity, 4);
    expect(cart.first.priceOffer, 3);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '4.0');
    await tester.tap(find.byTooltip('إنقاص الكمية').first);
    await tester.pump();
    expect(cart.first.quantity, 3);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'تأكيد وإرسال'))
            .onPressed,
        isNull);
    expect(submissions, 0);
    await tester.enterText(find.byType(TextField).first, '2.5');
    await tester.pump();
    expect(cart.first.quantity, 2.5);
    expect(cart.first.total, 7.5);

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('box').last);
    await tester.pumpAndSettle();
    expect(cart.first.selectedUnit, 'box');
    expect(cart.first.priceOffer, 40);
    expect(cart.first.note, 'note');

    await tester.tap(find.byTooltip('حذف الصنف').first);
    await tester.pump();
    expect(cart, hasLength(1));
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '1.0');
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('review guide does not change or submit the cart',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    GuideCoordinator.ready = true;
    addTearDown(() => GuideCoordinator.ready = false);
    final cart = [OrderItem.fromProduct(product, quantity: 2)];
    var submissions = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () => CartSummaryWidget.showReviewDialog(
                    context: context,
                    cartItems: cart,
                    guideAccountId: 'review-user',
                    onSubmit: () async => submissions++,
                    onRemoveItem: cart.remove,
                    onUpdateItem: (_, __, ___) {},
                  ),
                  child: const Text('open'),
                )),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('تخطي'), findsOneWidget);
    expect(submissions, 0);
    expect(cart.first.quantity, 2);
    await tester.tap(find.text('تخطي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        (await SharedPreferences.getInstance())
            .getString('guide.review.v1.review-user'),
        'skipped');
    expect(submissions, 0);
    expect(cart.first.quantity, 2);
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
  });
}
