import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/order_status_mapper.dart';
import 'package:orca_order/screens/widgets/order_actions_widget.dart';
import 'package:orca_order/utils/permissions.dart';

void main() {
  test('customer-confirmed status is distinct from financial approval', () {
    expect(
      OrderStatusMapper.getArabicStatus('customer_confirmed'),
      'مؤكدة من الزبون',
    );
  });

  Widget buildActions({
    required String status,
    required AppRole role,
    VoidCallback? onApprove,
    VoidCallback? onPrepare,
    VoidCallback? onEdit,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: OrderActionsWidget(
          status: status,
          userRole: role,
          onApprove: onApprove,
          onPrepare: onPrepare,
          onEdit: onEdit,
        ),
      ),
    );
  }

  testWidgets('customer confirms a priced order without financial approval',
      (tester) async {
    var confirmed = false;
    await tester.pumpWidget(buildActions(
      status: 'priced',
      role: AppRole.customer,
      onApprove: () => confirmed = true,
    ));

    await tester.tap(find.text('موافق على السعر'));
    expect(confirmed, isTrue);
    expect(find.text('اعتماد الطلب'), findsNothing);
  });

  testWidgets('customer cannot confirm a changed order before repricing',
      (tester) async {
    await tester.pumpWidget(buildActions(
      status: 'customer_changed',
      role: AppRole.customer,
    ));

    expect(find.text('موافق على السعر'), findsNothing);
  });

  testWidgets(
      'accountant can financially approve only customer-confirmed orders',
      (tester) async {
    await tester.pumpWidget(buildActions(
      status: 'priced',
      role: AppRole.accountant,
    ));
    expect(find.text('اعتماد الطلب'), findsNothing);

    await tester.pumpWidget(buildActions(
      status: 'customer_confirmed',
      role: AppRole.accountant,
    ));
    expect(find.text('اعتماد الطلب'), findsOneWidget);
  });

  testWidgets('warehouse can prepare only financially approved orders',
      (tester) async {
    await tester.pumpWidget(buildActions(
      status: 'customer_confirmed',
      role: AppRole.warehouse,
    ));
    expect(find.text('تجهيز الطلب'), findsNothing);

    await tester.pumpWidget(buildActions(
      status: 'approved',
      role: AppRole.warehouse,
    ));
    expect(find.text('بدء التجهيز'), findsOneWidget);

    await tester.pumpWidget(buildActions(
      status: 'preparing',
      role: AppRole.warehouse,
    ));
    expect(find.text('متابعة التعبئة'), findsOneWidget);
  });

  testWidgets('edit action appears only for eligible role and status',
      (tester) async {
    await tester.pumpWidget(buildActions(
      status: 'priced',
      role: AppRole.customer,
    ));
    expect(find.text('تعديل الطلب'), findsOneWidget);

    await tester.pumpWidget(buildActions(
      status: 'approved',
      role: AppRole.customer,
    ));
    expect(find.text('تعديل الطلب'), findsNothing);

    await tester.pumpWidget(buildActions(
      status: 'approved',
      role: AppRole.accountant,
    ));
    expect(find.text('تعديل الطلب'), findsOneWidget);

    await tester.pumpWidget(buildActions(
      status: 'preparing',
      role: AppRole.warehouse,
    ));
    expect(find.text('تعديل التجهيز'), findsOneWidget);
  });
}
