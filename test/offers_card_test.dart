import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/widgets/offers_section.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('offer card remains readable with large text in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SizedBox(
                height: 600,
                width: 280,
                child: OfferCard(
                  product: Product(
                      code: 'A100',
                      name: 'منتج',
                      category: '',
                      origin: '',
                      unit: 'قطعة',
                      price: 20),
                  offer: const {
                    'old_price': 20,
                    'offer_price': 15,
                    'currency': 'USD',
                    'min_quantity': 10,
                    'unit': 'قطعة',
                    'ends_at': '2030-01-01T10:00:00Z',
                    'note': 'حتى نفاد الكمية',
                  },
                  onOpen: () => opened = true,
                ),
              ),
            ),
          ),
        ),
      ));
      expect(find.text('الرمز: A100'), findsOneWidget);
      expect(find.text('عند طلب 10 قطعة أو أكثر'), findsOneWidget);
      expect(find.text('خصم 25.0%'), findsOneWidget);
      await tester.ensureVisible(find.text('عرض المنتج'));
      await tester.tap(find.text('عرض المنتج'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
