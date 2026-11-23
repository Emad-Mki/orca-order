import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/screens/customers_screen.dart';

Map<String, dynamic> customer(int id, {String? name}) => {
      'customer_id': 'C$id',
      'full_name': name ?? 'Customer $id',
      'status': 'active',
      'balance': 0,
    };

void main() {
  testWidgets('loads another page and applies server search', (tester) async {
    final calls = <String>[];
    Future<Map<String, dynamic>> load({
      required int limit,
      required int offset,
      required String query,
      required String status,
    }) async {
      calls.add('$offset:$query:$status');
      if (query.isNotEmpty) {
        return {
          'customers': [customer(99, name: 'Match')],
          'next_offset': null,
        };
      }
      return {
        'customers': List.generate(
            offset == 0 ? 50 : 2, (index) => customer(offset + index)),
        'next_offset': offset == 0 ? 50 : null,
      };
    }

    await tester.pumpWidget(MaterialApp(
      home:
          CustomersScreen(session: const {'role': 'manager'}, pageLoader: load),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Customer 0'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -9000));
    await tester.pumpAndSettle();
    expect(calls, contains('50::all'));
    await tester.enterText(find.byType(TextField).first, 'Match');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(calls, contains('0:Match:all'));
    expect(find.widgetWithText(ListTile, 'Match'), findsOneWidget);
    expect(find.text('Customer 0'), findsNothing);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('متوقف').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(calls, contains('0:Match:inactive'));
  });

  testWidgets('ignores a stale response after changing search', (tester) async {
    final first = Completer<Map<String, dynamic>>();
    final calls = <String>[];
    Future<Map<String, dynamic>> load({
      required int limit,
      required int offset,
      required String query,
      required String status,
    }) {
      calls.add(query);
      if (query.isEmpty) return first.future;
      return Future.value({
        'customers': [customer(2, name: 'New')],
        'next_offset': null,
      });
    }

    await tester.pumpWidget(MaterialApp(
      home:
          CustomersScreen(session: const {'role': 'manager'}, pageLoader: load),
    ));
    await tester.enterText(find.byType(TextField).first, 'New');
    await tester.pump(const Duration(milliseconds: 400));
    first.complete({
      'customers': [customer(1, name: 'Old')],
      'next_offset': null,
    });
    await tester.pumpAndSettle();
    expect(calls, ['', 'New']);
    expect(find.widgetWithText(ListTile, 'New'), findsOneWidget);
    expect(find.text('Old'), findsNothing);
  });

  testWidgets('customer type is limited to privileged roles', (tester) async {
    Future<Map<String, dynamic>> load({
      required int limit,
      required int offset,
      required String query,
      required String status,
    }) async =>
        {
          'customers': [
            {
              ...customer(1),
              'login_customer_types': ['جملة']
            }
          ],
          'next_offset': null,
        };
    await tester.pumpWidget(MaterialApp(
        home: CustomersScreen(
            session: const {'role': 'customer'}, pageLoader: load)));
    await tester.pumpAndSettle();
    expect(find.textContaining('نوع حساب الدخول'), findsNothing);
    await tester.pumpWidget(MaterialApp(
        home: CustomersScreen(
            key: const ValueKey('manager'),
            session: const {'role': 'manager'},
            pageLoader: load)));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('نوع حساب الدخول المرتبط: جملة'), findsOneWidget);
  });
}
