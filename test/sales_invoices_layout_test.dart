import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/screens/sales_invoices_screen.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(800, 900)]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'sales invoice screen has no overflow at $size in $brightness',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
              child: const Directionality(
                textDirection: TextDirection.rtl,
                child: SalesInvoicesScreen(session: {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(tester.takeException(), isNull);
        final search = find.byType(TextField);
        await tester.showKeyboard(search);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
