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

    expect(item.stockAvailable, 12);
  });

  test('product derives alternate unit prices from the base unit price', () {
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
    expect(boxItem.priceOffer, 36);
    expect(boxItem.total, 72);
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
    expect(product.priceForUnit('case'), 0);
    expect(product.availableUnits, ['piece', 'case']);

    final cachedMissingPrice = Product.fromJson({
      ...product.toJson(),
      'price_configured': false,
    });
    expect(cachedMissingPrice.priceForUnit('piece'), isNull);
  });

  test(
      'fractional factors derive prices and compare tier quantities in base units',
      () {
    final product = Product.fromJson({
      'code': 'FRACTIONAL',
      'unit_1': 'piece',
      'price': 2.35,
      'unit_2': 'half-case',
      'factor_2': 0.5,
      'unit_3': 'case',
      'factor_3': 2.5,
      'quantity_price': 1.8,
      'quantity_threshold': 12,
      'quantity_unit': 'case',
    });

    expect(product.priceForUnit('half-case'), 1.18);
    expect(product.priceForUnit('case'), 5.88);
    expect(
      product.qualifiesForQuantityPrice(quantity: 29, selectedUnit: 'piece'),
      isFalse,
    );
    expect(
      product.qualifiesForQuantityPrice(quantity: 30, selectedUnit: 'piece'),
      isTrue,
    );
    expect(product.quantityPriceForUnit('case'), 4.5);
  });

  test('restricted cached pricing can be redacted without losing retail prices',
      () {
    final product = Product.fromJson({
      'code': 'PRIVATE',
      'unit_1': 'piece',
      'price': 10,
      'unit_2': 'box',
      'factor_2': 2,
      'wholesale_price': 7,
      'quantity_price': 6,
      'quantity_threshold': 4,
      'quantity_unit': 'box',
    });

    final visibleProduct = product.withoutRestrictedPricing();

    expect(visibleProduct.price, 10);
    expect(visibleProduct.priceForUnit('box'), 20);
    expect(visibleProduct.wholesalePrice, isNull);
    expect(visibleProduct.quantityPrice, isNull);
    expect(visibleProduct.quantityThreshold, isNull);
    expect(visibleProduct.quantityUnit, isNull);
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
