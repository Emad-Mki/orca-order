import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/widgets/sales_customer_form.dart';

void main() {
  testWidgets('commercial customer form validates name and returns input',
      (tester) async {
    Map<String, String>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () async =>
                      result = await showSalesCustomerForm(context),
                  child: const Text('open'),
                )),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة زبون تجاري دون حساب دخول'), findsOneWidget);
    await tester.tap(find.text('متابعة'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'عميل');
    await tester.enterText(find.byType(TextField).last, '123');
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(result, {'name': 'عميل', 'phone': '123'});
    expect(tester.takeException(), isNull);
  });
}
