import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order_item.dart';
import 'package:orca_order/screens/order_pricing_screen.dart';

void main() {
  test('historical offer price requires confirmation only when overridden', () {
    final item = OrderItem.fromJson({
      'code': 'P1',
      'name': 'منتج',
      'unit': 'قطعة',
      'quantity_requested': 2,
      'currency': 'USD',
      'offer_id': 'O1',
      'offer_revision': 2,
      'offer_min_quantity': 2,
      'unit_price_snapshot': 75,
      'display_price_snapshot': 75,
    });
    final pricing = PricingItem.fromModel(item);
    addTearDown(pricing.dispose);
    expect(item.offer?.price, 75);
    expect(PricingItem.needsOfferPriceOverride([pricing], [item]), isFalse);
    pricing.unitPrice = 70;
    expect(PricingItem.needsOfferPriceOverride([pricing], [item]), isTrue);
    pricing.available = false;
    expect(PricingItem.needsOfferPriceOverride([pricing], [item]), isFalse);
  });
}
