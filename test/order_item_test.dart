import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order_item.dart';
import 'package:orca_order/models/product.dart';

void main() {
  test('priced invoice uses approved quantity and final price', () {
    final item = OrderItem(
      itemId: 'item-1',
      code: 'A1',
      name: 'Item',
      unit: 'piece',
      quantityRequested: 5,
      quantityApproved: 3,
      quantityPrepared: 0,
      priceOffer: 10,
      defaultPrice: 10,
      finalPrice: 12,
      currency: 'USD',
      status: 'available',
      stockAvailable: 0,
      product: Product(
        code: 'A1',
        name: 'Item',
        category: 'Category',
        origin: '',
        unit: 'piece',
        price: 10,
      ),
      quantity: 5,
    );

    expect(item.displayPrice, 12);
    expect(item.pricedQuantity, 3);
    expect(item.pricedLineTotal, 36);
    expect(item.total, 36);
  });

  test('unavailable priced item has no invoice total', () {
    final item = OrderItem(
      itemId: 'item-2',
      code: 'A2',
      name: 'Unavailable',
      unit: 'piece',
      quantityRequested: 4,
      quantityApproved: 4,
      quantityPrepared: 0,
      priceOffer: 8,
      defaultPrice: 8,
      finalPrice: 9,
      currency: 'USD',
      status: 'unavailable',
      stockAvailable: 0,
    );

    expect(item.pricedLineTotal, 0);
    expect(item.total, 0);
  });

  test('Code.gs pricing fields parse into the customer invoice values', () {
    final item = OrderItem.fromJson({
      'item_id': 'item-3',
      'code': 'A3',
      'name': 'Priced item',
      'unit': 'box',
      'quantity_requested': 6,
      'quantity_approved': 2,
      'display_price_snapshot': 14,
      'final_price': 11,
      'status': 'available',
    });

    expect(item.quantityRequested, 6);
    expect(item.pricedQuantity, 2);
    expect(item.displayPrice, 11);
    expect(item.pricedLineTotal, 22);
  });

  test('stock availability accepts decimal JSON numbers', () {
    final item = OrderItem.fromJson({
      'item_id': 'item-5',
      'stock_available': 12.5,
    });

    test('product exposes only configured units and keeps independent prices',
        () {
      final product = Product.fromJson({
        'code': 'MULTI',
        'name': 'Multi unit',
        'unit_1': 'piece',
        'price': 3,
        'unit_2': ' box ',
        'factor_2': 12,
        'price_2': 25,
        'unit_3': ' ',
        'factor_3': '',
        'price_3': '',
      });

      expect(product.availableUnits, ['piece', 'box']);
      final boxItem = OrderItem.fromProduct(
        product,
        quantity: 2,
        selectedUnit: 'box',
      );
      expect(boxItem.unitFactor, 12);
      expect(boxItem.priceOffer, 25);
      expect(boxItem.total, 50);
    });

    test('missing unit price is distinct from a configured zero price', () {
      final product = Product.fromJson({
        'code': 'PRICE',
        'unit_1': 'piece',
        'price': 0,
        'unit_2': 'case',
        'factor_2': 6,
        'price_2': '',
      });
      expect(product.priceForUnit('piece'), 0);
      expect(product.priceForUnit('case'), isNull);
      expect(product.availableUnits, ['piece', 'case']);

      final cachedMissingPrice = Product.fromJson({
        ...product.toJson(),
        'price_configured': false,
      });
      expect(cachedMissingPrice.priceForUnit('piece'), isNull);
    });

    test('conflicting duplicate unit definitions are surfaced', () {
      final product = Product.fromJson({
        'code': 'DUP',
        'unit_1': 'piece',
        'price': 3,
        'unit_2': 'piece',
        'factor_2': 12,
        'price_2': 25,
      });
      expect(product.availableUnits, ['piece']);
      expect(product.hasConflictingUnits, isTrue);
    });

    expect(item.stockAvailable, 12);
  });

  test('a zero final price does not fall back to the customer price', () {
    final item = OrderItem.fromJson({
      'item_id': 'item-4',
      'code': 'A4',
      'name': 'Free item',
      'unit': 'piece',
      'quantity_requested': 1,
      'quantity_approved': 1,
      'display_price_snapshot': 14,
      'final_price': 0,
      'status': 'available',
    });

    expect(item.pricedUnitPrice, 0);
    expect(item.pricedLineTotal, 0);
    expect(item.total, 0);
  });
}
