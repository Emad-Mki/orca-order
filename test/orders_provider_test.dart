import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order.dart';
import 'package:orca_order/providers/orders_provider.dart';
import 'package:orca_order/repositories/order_repository.dart';

void main() {
  test('concurrent list fetches share one request', () async {
    final completer = Completer<List<Order>>();
    final repository = _FakeOrderRepository((_) => completer.future);
    final provider = OrdersProvider(repository);

    final first = provider.fetchOrders();
    final second = provider.fetchOrders(forceRefresh: true);
    expect(repository.fetchCount, 1);
    expect(provider.isLoading, isTrue);

    completer.complete([_order('1', 'pending', DateTime(2026, 1, 1))]);
    await Future.wait([first, second]);
    expect(provider.isLoading, isFalse);
    expect(provider.orders, hasLength(1));
  });

  test('manual refresh cooldown rejects without restarting its clock',
      () async {
    final repository = _FakeOrderRepository((_) async => []);
    final provider = OrdersProvider(repository);

    await provider.fetchOrders(forceRefresh: true);
    expect(provider.canRefresh, isFalse);
    final acceptedRefreshTime = repository.fetchCount;

    await provider.fetchOrders(forceRefresh: true);
    await provider.fetchOrders(forceRefresh: true);

    expect(repository.fetchCount, acceptedRefreshTime);
    expect(provider.lastRefreshThrottled, isTrue);
  });

  test('failed refresh retains last good data and clears loading state',
      () async {
    final expected = _order('1', 'pending', DateTime(2026, 1, 1));
    final repository = _FakeOrderRepository((call) async {
      if (call == 1) return [expected];
      throw StateError('offline');
    });
    final provider = OrdersProvider(repository);
    await provider.fetchOrders();
    await provider.fetchOrders(
      forceRefresh: true,
      bypassMinimumInterval: true,
    );

    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, contains('offline'));
    expect(provider.orders.single.orderId, expected.orderId);
  });

  test('stale list response cannot overwrite a confirmed cancellation',
      () async {
    final staleResponse = Completer<List<Order>>();
    final repository = _FakeOrderRepository((call) async {
      if (call == 1) return staleResponse.future;
      return [_order('1', 'cancelled', DateTime(2026, 1, 1))];
    });
    final provider = OrdersProvider(repository);
    final staleFetch = provider.fetchOrders();
    final sync = provider.syncAfterMutation(
      orderId: '1',
      status: 'cancelled',
    );
    staleResponse.complete([_order('1', 'pending', DateTime(2026, 1, 1))]);

    await Future.wait([staleFetch, sync]);

    expect(repository.fetchCount, 2);
    expect(provider.orders.single.status, 'cancelled');
  });

  test('search, status, date range, and sort apply to the same full list',
      () async {
    final repository = _FakeOrderRepository((_) async => [
          _order('1', 'pending', DateTime(2026, 2, 1),
              number: 'ORD-260201-00001'),
          _order('2', 'cancelled', DateTime(2026, 2, 3),
              number: 'ORD-260203-00002'),
          _order('3', 'pending', DateTime(2026, 1, 20), number: 'OLD-00003'),
        ]);
    final provider = OrdersProvider(repository);
    await provider.fetchOrders();
    provider.setSearchQuery('0000');
    provider.setFilter('processing');
    provider.setDateRange(
        from: DateTime(2026, 2, 1), to: DateTime(2026, 2, 28));
    provider.setSortOption(OrderSortOption.oldest);

    expect(provider.orders.map((order) => order.orderId), ['1']);
  });
}

class _FakeOrderRepository extends OrderRepository {
  final Future<List<Order>> Function(int call) onFetch;
  int fetchCount = 0;

  _FakeOrderRepository(this.onFetch);

  @override
  Future<List<Order>> getOrders({
    String? customerId,
    String? status,
    bool forceRefresh = false,
  }) {
    fetchCount++;
    return onFetch(fetchCount);
  }
}

Order _order(
  String id,
  String status,
  DateTime createdAt, {
  String? number,
}) =>
    Order(
      orderId: id,
      orderNumber: number ?? id,
      customerId: 'customer-1',
      customerName: 'Customer',
      status: status,
      currency: 'USD',
      createdAt: createdAt,
    );
