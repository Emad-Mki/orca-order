import 'dart:convert';
import '../models/order_offer.dart';
import 'package:drift/drift.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../app_config.dart';

class LocalRepository {
  final AppDatabase _db;
  final ApiService _apiService = ApiService();

  LocalRepository(this._db);

  String get _env => AppConfig.environmentName;
  String get _accountId {
    final user = _apiService.currentUser;
    return (user?['user_id'] ?? user?['customer_id'] ?? 'anonymous').toString();
  }

  String get draftScope => '$_env\u0000$_accountId';

  // Products
  Future<void> saveProducts(List<Product> products) async {
    final environment = _env;
    final accountId = _accountId;

    try {
      await _db.transaction(() async {
        await (_db.delete(_db.localProducts)
              ..where((t) =>
                  t.environment.equals(environment) &
                  t.accountId.equals(accountId)))
            .go();

        await _db.batch((batch) {
          batch.insertAll(
            _db.localProducts,
            products.map((p) => LocalProductsCompanion.insert(
                  environment: environment,
                  accountId: accountId,
                  code: p.code,
                  name: p.name,
                  category: p.category,
                  unit: p.unit,
                  priceMicros: (p.price * 1000000).toInt(),
                  stockMicros: ((p.stockQuantity ?? 0) * 1000000).toInt(),
                  currency: Value(p.currency),
                  imageUrl: Value(p.imageUrl),
                  jsonData: jsonEncode(p.toJson()),
                )),
            mode: InsertMode.insertOrReplace,
          );
        });
      });
    } catch (e) {
      if (e.toString().contains('112')) {
        throw Exception('DISK_FULL');
      }
      rethrow;
    }
  }

  Future<List<Product>> getProducts() async {
    final query = _db.select(_db.localProducts)
      ..where(
          (t) => t.environment.equals(_env) & t.accountId.equals(_accountId));

    final rows = await query.get();
    return rows
        .map((row) => Product.fromJson(jsonDecode(row.jsonData)))
        .toList();
  }

  // Drafts
  Future<int> saveDraft(OrderDraft draft) async {
    try {
      final companion = OrderDraftsCompanion(
        id: draft.id != null ? Value(draft.id!) : const Value.absent(),
        environment: Value(_env),
        accountId: Value(_accountId),
        customerId: Value(draft.customerId),
        customerName: Value(draft.customerName),
        note: Value(draft.note),
        updatedAt: Value(DateTime.now()),
        currency: Value(draft.currency),
        customTitle: Value(draft.customTitle),
        clientRequestId: Value(draft.clientRequestId),
      );

      final itemCompanions = draft.items
          .map((item) => OrderDraftItemsCompanion(
                productCode: Value(item.productCode),
                productName: Value(item.productName),
                unit: Value(item.unit),
                quantityMicros: Value((item.quantity * 1000000).toInt()),
                priceMicros: Value((item.price * 1000000).toInt()),
                note: Value(item.note),
                productDataJson: Value(item.originalProduct != null ||
                        item.offer != null ||
                        item.expectedUnitPrice != null
                    ? jsonEncode({
                        ...?item.originalProduct?.toJson(),
                        if (item.originalProduct == null)
                          '_draft_no_product': true,
                        if (item.offer != null)
                          '_draft_offer': item.offer!.data,
                        if (item.expectedUnitPrice != null)
                          '_draft_expected_unit_price': item.expectedUnitPrice,
                      })
                    : null),
              ))
          .toList();

      return await _db.saveOrderDraft(
        draft: companion,
        items: itemCompanions,
        environment: _env,
        accountId: _accountId,
      );
    } catch (e) {
      if (e.toString().contains('112')) {
        throw Exception('DISK_FULL');
      }
      rethrow;
    }
  }

  Future<List<OrderDraft>> getAllDrafts() async {
    final query = _db.select(_db.orderDrafts)
      ..where(
          (t) => t.environment.equals(_env) & t.accountId.equals(_accountId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
      ]);

    final rows = await query.get();
    List<OrderDraft> drafts = [];

    for (var row in rows) {
      final itemsQuery = _db.select(_db.orderDraftItems)
        ..where((t) => t.draftId.equals(row.id));
      final itemRows = await itemsQuery.get();

      drafts.add(OrderDraft(
        id: row.id,
        customerId: row.customerId,
        customerName: row.customerName,
        note: row.note,
        updatedAt: row.updatedAt,
        currency: row.currency,
        customTitle: row.customTitle,
        clientRequestId: row.clientRequestId,
        items: itemRows.map((i) {
          final snapshot = i.productDataJson == null
              ? null
              : Map<String, dynamic>.from(jsonDecode(i.productDataJson!));
          return DraftItem(
            id: i.id,
            productCode: i.productCode,
            productName: i.productName,
            unit: i.unit,
            quantity: i.quantityMicros / 1000000,
            price: i.priceMicros / 1000000,
            note: i.note,
            originalProduct:
                snapshot != null && snapshot['_draft_no_product'] != true
                    ? Product.fromJson(snapshot)
                    : null,
            offer: snapshot?['_draft_offer'] is Map
                ? OrderOffer(
                    Map<String, dynamic>.from(snapshot!['_draft_offer']))
                : null,
            expectedUnitPrice:
                (snapshot?['_draft_expected_unit_price'] as num?)?.toDouble(),
          );
        }).toList(),
      ));
    }
    return drafts;
  }

  Future<void> deleteDraft(int id) async {
    await _db.deleteOrderDraft(
      draftId: id,
      environment: _env,
      accountId: _accountId,
    );
  }

  Future<void> updateDraftNote(int id, String note) async {
    await _db.updateDraftNote(
      id,
      note,
      environment: _env,
      accountId: _accountId,
    );
  }

  // Cache Cleaning
  Future<void> clearProductCache() async {
    final query = _db.delete(_db.localProducts)
      ..where(
          (t) => t.environment.equals(_env) & t.accountId.equals(_accountId));
    await query.go();
  }

  // Orders Cache
  Future<void> saveOrders(List<Order> orders) async {
    final environment = _env;
    final accountId = _accountId;
    await _db.batch((batch) {
      batch.insertAll(
        _db.localOrders,
        orders.map((o) => LocalOrdersCompanion.insert(
              orderId: o.orderId,
              environment: environment,
              accountId: accountId,
              orderNumber: o.orderNumber,
              customerId: o.customerId,
              customerName: o.customerName,
              status: o.status,
              currency: o.currency,
              createdAt: Value(o.createdAt),
              updatedAt: Value(o.updatedAt),
              totalAmountMicros: Value(o.totalAmount != null
                  ? (o.totalAmount! * 1000000).toInt()
                  : null),
              jsonData: jsonEncode(o.toJson()),
            )),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<List<Order>> getOrders({String? customerId, String? status}) async {
    final query = _db.select(_db.localOrders)
      ..where(
          (t) => t.environment.equals(_env) & t.accountId.equals(_accountId));

    if (customerId != null) {
      query.where((t) => t.customerId.equals(customerId));
    }

    if (status != null) {
      query.where((t) => t.status.equals(status));
    }

    query.orderBy([
      (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
    ]);

    final rows = await query.get();
    return rows.map((row) => Order.fromJson(jsonDecode(row.jsonData))).toList();
  }

  // Sync Metadata
  Future<void> updateLastSync(String key) async {
    await _db.into(_db.syncMetadata).insert(
          SyncMetadataCompanion.insert(
            key: key,
            environment: _env,
            accountId: _accountId,
            lastSync: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<DateTime?> getLastSync(String key) async {
    final query = _db.select(_db.syncMetadata)
      ..where((t) =>
          t.key.equals(key) &
          t.environment.equals(_env) &
          t.accountId.equals(_accountId));
    final row = await query.getSingleOrNull();
    return row?.lastSync;
  }

  // Customers Cache
  Future<void> saveCustomers(List<Customer> customers) async {
    final environment = _env;
    final accountId = _accountId;
    await _db.batch((batch) {
      batch.insertAll(
        _db.localCustomers,
        customers.map((c) => LocalCustomersCompanion.insert(
              id: c.id,
              environment: environment,
              accountId: accountId,
              name: c.name,
              phone: Value(c.phone),
              balanceMicros:
                  Value(c.balance != null ? (c.balance! * 1000000).toInt() : 0),
              jsonData: jsonEncode(c.toJson()),
            )),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<List<Customer>> getCustomers() async {
    final query = _db.select(_db.localCustomers)
      ..where(
          (t) => t.environment.equals(_env) & t.accountId.equals(_accountId));

    final rows = await query.get();
    return rows
        .map((row) => Customer.fromJson(jsonDecode(row.jsonData)))
        .toList();
  }
}
