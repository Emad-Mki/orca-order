import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order_item.dart';
import 'package:orca_order/repositories/order_repository.dart';
import 'package:orca_order/services/api_service.dart';

void main() {
  late Directory root;
  late OrderDetailSession session;

  OrderDetailSession makeSession({
    String environment = 'production',
    String url = 'https://example.test',
    String user = 'user-a',
    String role = 'customer',
    String token = 'secret-token',
    Object? identity,
  }) =>
      OrderDetailSession(
        environment: environment,
        apiUrl: url,
        userId: user,
        role: role,
        token: token,
        sessionIdentity: identity ?? Object(),
      );

  Map<String, dynamic> response({String name = 'Historical name'}) => {
        'ok': true,
        'order': {
          'order_id': 'order-1',
          'customer_name': 'Customer',
          'items': [
            {
              'item_id': 'item-1',
              'name': name,
              'quantity_requested': 2,
              'final_price': 5,
              'total_price': '17.5',
              'extra_snapshot_field': 'retained',
            }
          ],
        },
        'shipment': {'carrier': 'Example'},
      };

  const network = ApiException(
    code: 'NETWORK_ERROR',
    message: 'فشل الاتصال بالخادم، تحقق من شبكة الإنترنت',
    retryable: true,
    transportFailure: true,
  );
  const timeout = ApiException(
    code: 'TIMEOUT',
    message: 'انتهت مهلة الاتصال بالخادم',
    retryable: true,
    transportFailure: true,
  );

  OrderRepository repository(
          Future<Map<String, dynamic>> Function(String) fetch) =>
      OrderRepository(
        detailFetcher: fetch,
        detailSession: () => session,
        detailCacheDirectory: root,
      );

  setUp(() async {
    root =
        await Directory.current.createTemp('test_order_detail_cache_scratch_');
    session = makeSession();
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('historical line total round trips without changing calculations', () {
    final item = OrderItem.fromJson({
      'name': 'Snapshot',
      'quantity_requested': 2,
      'final_price': 5,
      'total_price': '17.5',
    });
    expect(item.savedLineTotal, 17.5);
    expect(item.total, 10);
    expect(item.pricedLineTotal, 10);
    expect(OrderItem.fromJson(item.toJson()).savedLineTotal, 17.5);
    expect(item.copyWith(name: 'Copy').savedLineTotal, 17.5);
    expect(item.copyWith(savedLineTotal: 0).savedLineTotal, 0);
    expect(OrderItem.fromJson({}).savedLineTotal, isNull);
  });

  test('persists raw order and shipment and restores after restart', () async {
    final online = repository((_) async => response());
    final order = await online.getOrderDetails('order-1');
    expect(order!.items!.single.savedLineTotal, 17.5);

    final files =
        await root.list(recursive: true).where((e) => e is File).toList();
    expect(files, hasLength(1));
    final text = await (files.single as File).readAsString();
    expect(text, isNot(contains('secret-token')));
    final snapshot = jsonDecode(text) as Map;
    expect(snapshot['order']['items'][0]['extra_snapshot_field'], 'retained');
    expect(snapshot['order']['shipment_data']['carrier'], 'Example');

    for (final error in [network, timeout]) {
      final offline = repository((_) async => throw error);
      final cached = await offline.getOrderDetails('order-1');
      expect(cached!.customerName, 'Customer');
      expect(cached.items!.single.name, 'Historical name');
      expect(cached.items!.single.savedLineTotal, 17.5);
      expect(cached.shipmentData!['carrier'], 'Example');
    }
  });

  test('missing and corrupt cache surface errors, denials never fall back',
      () async {
    final offline = repository((_) async => throw network);
    await expectLater(
        offline.getOrderDetails('order-1'), throwsA(same(network)));
    await repository((_) async => response()).getOrderDetails('order-1');
    final denial = repository((_) async => {
          'ok': false,
          'error': {'code': 'ROLE_NOT_ALLOWED', 'message': 'denied'},
        });
    await expectLater(denial.getOrderDetails('order-1'), throwsException);
    final server = repository((_) async => throw const ApiException(
          code: 'NETWORK_ERROR',
          message: 'server denied',
          retryable: true,
        ));
    await expectLater(
        server.getOrderDetails('order-1'), throwsA(isA<ApiException>()));
    final disguisedServer = repository((_) async => throw const ApiException(
          code: 'NETWORK_ERROR',
          message: 'فشل الاتصال بالخادم، تحقق من شبكة الإنترنت',
          retryable: true,
        ));
    await expectLater(disguisedServer.getOrderDetails('order-1'),
        throwsA(isA<ApiException>()));
    final file = (await root
        .list(recursive: true)
        .where((e) => e is File)
        .first) as File;
    await file.writeAsString('{bad');
    await expectLater(
        offline.getOrderDetails('order-1'), throwsFormatException);
  });

  test('scope isolates account, role, environment and API URL', () async {
    await repository((_) async => response()).getOrderDetails('order-1');
    final original = session;
    for (final other in [
      makeSession(user: 'user-b'),
      makeSession(role: 'warehouse'),
      makeSession(environment: 'testing'),
      makeSession(url: 'https://other.test'),
    ]) {
      session = other;
      await expectLater(
        repository((_) async => throw network).getOrderDetails('order-1'),
        throwsA(same(network)),
      );
    }
    session = original;
    expect(
        (await repository((_) async => throw network)
                .getOrderDetails('order-1'))!
            .items!
            .single
            .name,
        'Historical name');
  });

  test('refresh replaces the snapshot and credentials are never saved',
      () async {
    await repository((_) async => response()).getOrderDetails('order-1');
    await repository((_) async => response(name: 'Updated'))
        .getOrderDetails('order-1');
    final credentialResponse = response(name: 'Do not persist');
    (credentialResponse['order'] as Map)['session_token'] = 'secret-token';
    await repository((_) async => credentialResponse)
        .getOrderDetails('order-1');
    final cached =
        await repository((_) async => throw network).getOrderDetails('order-1');
    expect(cached!.items!.single.name, 'Updated');
  });

  test('missing identity does not create or read a cache', () async {
    await repository((_) async => response()).getOrderDetails('order-1');
    session = makeSession(user: '');
    expect(await repository((_) async => response()).getOrderDetails('order-1'),
        isNotNull);
    await expectLater(
      repository((_) async => throw network).getOrderDetails('order-1'),
      throwsA(same(network)),
    );
    expect(await root.list(recursive: true).where((e) => e is File).length, 1);
  });

  test('session change during request rejects stale response and write',
      () async {
    final pending = Completer<Map<String, dynamic>>();
    final original = session;
    final request =
        repository((_) => pending.future).getOrderDetails('order-1');
    session = makeSession(user: 'user-b');
    pending.complete(response());
    await expectLater(request, throwsStateError);
    session = original;
    await expectLater(
      repository((_) async => throw network).getOrderDetails('order-1'),
      throwsA(same(network)),
    );
    expect(await root.list(recursive: true).toList(), isEmpty);
  });

  test('same token relogin is a different session', () async {
    final pending = Completer<Map<String, dynamic>>();
    final request =
        repository((_) => pending.future).getOrderDetails('order-1');
    session = makeSession();
    pending.complete(response());
    await expectLater(request, throwsStateError);
  });

  test('concurrent old and new sessions cannot overwrite each other', () async {
    final oldSession = session;
    final pending = Completer<Map<String, dynamic>>();
    final oldRequest =
        repository((_) => pending.future).getOrderDetails('order-1');
    session = makeSession(user: 'user-b', token: 'new-token');
    final newSession = session;
    await repository((_) async => response(name: 'New account'))
        .getOrderDetails('order-1');
    pending.complete(response(name: 'Stale account'));
    await expectLater(oldRequest, throwsStateError);
    expect(
        (await repository((_) async => throw network)
                .getOrderDetails('order-1'))!
            .items!
            .single
            .name,
        'New account');
    session = oldSession;
    await expectLater(
      repository((_) async => throw network).getOrderDetails('order-1'),
      throwsA(same(network)),
    );
    session = newSession;
  });
}
