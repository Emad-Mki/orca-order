import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/screens/widgets/order_actions_widget.dart';
import 'package:orca_order/utils/permissions.dart';

void main() {
  testWidgets('warehouse sees both preparation actions after approval',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: OrderActionsWidget(
            status: 'approved',
            userRole: AppRole.warehouse,
            onPrepare: () {},
            onEdit: () {},
          ),
        ),
      ),
    );

    expect(find.text('متابعة التعبئة'), findsOneWidget);
    expect(find.text('تعديل التجهيز'), findsOneWidget);
  });
}
